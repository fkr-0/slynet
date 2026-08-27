# SLYNK Cross-Referencing Utilities for Janet
# Translated from xref.lisp
# Provides static analysis facilities for Janet code

(import ./backend)
(import ./source_index :as source-index)

# Database storage
(var *db* nil)
(var *db-updated* nil)
(var *db-pathname* nil)

# Data structure for xref types
(def xref-types
  @{:calls "calls" # Function calls function
    :called-by "is called by" # Function is called by function
    :sets "sets" # Function sets variable
    :set-by "is set by" # Variable is set by function
    :binds "binds" # Function binds variable
    :bound-by "is bound by" # Variable is bound by function
    :references "references" # Function references variable
    :referenced-by "is referenced by" # Variable is referenced by function
    :macro-expands "macro-expands" # Function macro-expands macro
    :macro-expanded-by "is macro-expanded by" # Macro is expanded by function
    :specializes "specializes" # Method specializes generic function
    :specialized-by "is specialized by" # Generic function is specialized by method
})

(defn- file-modified-time [file]
  "Return FILE's Janet modification timestamp, or nil when it cannot be statted."
  (when-let [stat (try (os/stat file) ([_ _] nil))]
    (stat :modified)))

(defn file-modified? [file]
  "Return true if FILE has been modified since last update."
  (def file-entry (get *db* file))
  (if file-entry
    (let [old-time (file-entry :timestamp)
          new-time (file-modified-time file)]
      (or (nil? old-time)
          (nil? new-time)
          (> new-time old-time)))
    # No record, so yes, it's "modified"
    true))

(defn- form-location [file form]
  "Return an exact parser source location for FORM when Janet provides one."
  (def source-map
    (when (tuple? form)
      (try (tuple/sourcemap form) ([_ _] nil))))
  @{:file file
    :line (if (and (tuple? source-map) (> (length source-map) 0))
            (source-map 0)
            1)
    :column (if (and (tuple? source-map) (> (length source-map) 1))
              (source-map 1)
              1)
    :location-precision (if source-map :parser-sourcemap :file-only)})

(defn record-definition [type name file form]
  "Record a definition in the database."
  (def location (form-location file form))

  # Ensure we have a place to store this type of definition
  (unless (get *db* type)
    (put *db* type @{}))

  # Record the definition
  (let [type-db (get *db* type)]
    (unless (get type-db name)
      (put type-db name @[]))
    (array/push (get type-db name) location)))
(defn record-reference [type name file form &opt context-name]
  "Record a reference in the database."
  (def location (form-location file form))
  (when context-name
    (put location :context-name context-name))

  # Create reference entry
  (def ref-type (case type
                  :calls :calls
                  :sets :sets
                  :references :references
                  :default :references))

  # Ensure we have a place to store references
  (unless (get *db* ref-type)
    (put *db* ref-type @{}))

  # Record the reference
  (let [type-db (get *db* ref-type)]
    (unless (get type-db name)
      (put type-db name @[]))
    (array/push (get type-db name) location)))
(defn analyze-form [form file &opt parent-form context-name]
  "Analyze a parsed form and update the cross-reference database."
  (match (type form)
    :array (each subform form
             (analyze-form subform file form context-name))
    :tuple
    (match form
      ['quote & _] nil
      ['quasiquote & _] nil

      ['def name & body]
      (do
        (when (symbol? name) (record-definition :var name file form))
        (each subform body (analyze-form subform file form name)))

      ['var name & body]
      (do
        (when (symbol? name) (record-definition :var name file form))
        (each subform body (analyze-form subform file form name)))

      ['defn name args & body]
      (do
        (when (symbol? name) (record-definition :fn name file form))
        (each subform body (analyze-form subform file form name)))

      ['defmacro name args & body]
      (do
        (when (symbol? name) (record-definition :macro name file form))
        (each subform body (analyze-form subform file form name)))

      ['set name & body]
      (do
        (when (symbol? name) (record-reference :sets name file form context-name))
        (each subform body (analyze-form subform file form context-name)))

      [fn-name & args]
      (do
        (when (and parent-form (symbol? fn-name))
          (record-reference :calls fn-name file form context-name))
        (each subform args (analyze-form subform file form context-name)))

      _ nil)
    # Other types can be ignored for basic xref analysis
    nil))

(defn- parse-source-forms [content]
  "Parse all top-level Janet forms in CONTENT, rejecting invalid/incomplete input."
  (def p (parser/new))
  (parser/consume p content)
  (case (parser/status p)
    :error (error (or (parser/error p) "Janet parser error"))
    :pending (error "incomplete Janet source form")
    nil)
  (def forms @[])
  (var wrapped (parser/produce p true))
  (while wrapped
    (array/push forms (wrapped 0))
    (set wrapped (parser/produce p true)))
  forms)

(defn process-file [file]
  "Process a file and update the cross-reference database."
  (try
    (do
      (def content (slurp file))
      (each form (parse-source-forms content)
        (analyze-form form file))
      true)
    ([err fib]
      (eprintf "Error processing file %s: %s\n" file err)
      false)))
(defn clear-xref-database []
  "Clear the cross-reference database."
  (set *db* nil)
  (set *db-updated* nil))

(def xref-fact-kinds @[:calls :references :sets :var :fn :macro])

(defn- remove-file-facts! [file]
  "Remove all static xref facts and timestamp state contributed by FILE."
  (when (table? *db*)
    (each kind xref-fact-kinds
      (when-let [kind-db (get *db* kind)]
        (when (table? kind-db)
          (def names @[])
          (eachp [name _] kind-db (array/push names name))
          (each name names
            (def locations (get kind-db name @[]))
            (def kept @[])
            (each location locations
              (when (not (= file (location :file)))
                (array/push kept location)))
            (if (= 0 (length kept))
              (put kind-db name nil)
              (put kind-db name kept))))))
    (put *db* file nil))
  true)

(defn save-database []
  "Save the cross-reference database to a file."
  (when *db-pathname*
    (with [f (file/open *db-pathname* :w)]
      (file/write f (string *db*)))))

(defn update-xrefs [files]
  "Update the cross-reference database for FILES."
  (unless *db* (set *db* @{}))
  (var updated false)

  # Process each file
  (each file files
    (var file-updated false)
    # Check if file needs updating (if it's been modified since last update)
    (when (file-modified? file)
      # Replace facts atomically at the file granularity instead of appending
      # duplicate/stale call sites across source edits.
      (remove-file-facts! file)
      # Parse file and update database
      (when (process-file file)
        (set updated true)
        (set file-updated true)))

    # If processed, update timestamp
    (when file-updated
      (put *db* file {:timestamp (file-modified-time file)})))

  # Update database status
  (set *db-updated* updated)
  (when updated
    (save-database)))






(defn load-database []
  "Load the cross-reference database from a file."
  (when (and *db-pathname*
             (os/stat *db-pathname*))
    (try
      (set *db* (parse (slurp *db-pathname*)))
      ([err fib]
             (eprintf "Error loading xref database: %s\n" err)
             (set *db* @{})))))

(defn initialize-database [pathname]
  "Initialize the cross-reference database with PATHNAME."
  (set *db-pathname* pathname)
  (load-database)
  (unless *db*
    (set *db* @{})))

# API functions for Emacs integration

(defn who-calls [symbol]
  "Find all callers of SYMBOL."
  (let [calls-db (get (or *db* @{}) :calls @{})
        locations (get calls-db symbol @[])]
    locations))

(defn who-references [symbol]
  "Find all references to SYMBOL."
  (let [refs-db (get (or *db* @{}) :references @{})
        locations (get refs-db symbol @[])]
    locations))

(defn who-binds [symbol]
  "Find all bindings of SYMBOL."
  (let [db (or *db* @{})
        var-db (get db :var @{})
        fn-db (get db :fn @{})
        macro-db (get db :macro @{})
        var-locs (get var-db symbol @[])
        fn-locs (get fn-db symbol @[])
        macro-locs (get macro-db symbol @[])]
    (array/concat var-locs fn-locs macro-locs)))

(defn who-sets [symbol]
  "Find all setters of SYMBOL."
  (let [sets-db (get (or *db* @{}) :sets @{})
        locations (get sets-db symbol @[])]
    locations))

(defn index-files [files]
  "Update the static xref database for FILES and return the database."
  (update-xrefs files)
  *db*)

(defn refresh-project [root]
  "Refresh static xref facts for Janet files below ROOT."
  (def files (source-index/collect-files root))
  (unless *db* (set *db* @{}))
  (def present @{})
  (each file files (put present file true))
  (def stale @[])
  (def root-prefix (string root "/"))
  (eachp [key _] *db*
    (when (and (string? key)
               (string/has-prefix? root-prefix key)
               (nil? (get present key)))
      (array/push stale key)))
  (each file stale (remove-file-facts! file))
  (index-files files))

(defn list-callers [function-name]
  "Return static call sites for FUNCTION-NAME, matching who-calls semantics."
  (who-calls function-name))

# Export public API
(def export-api
  @{:list-callers list-callers
    :index-files index-files
    :refresh-project refresh-project
    :who-calls who-calls
    :who-references who-references
    :who-binds who-binds
    :who-sets who-sets
    :update-xrefs update-xrefs
    :initialize-database initialize-database})
