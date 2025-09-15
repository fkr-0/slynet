# SLYNK Cross-Referencing Utilities for Janet
# Translated from xref.lisp
# Provides static analysis facilities for Janet code

(import ./backend)

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
(defn file-modified? [file]
  "Return true if FILE has been modified since last update."
  (def file-entry (get *db* file))
  (if file-entry
    # Compare timestamps
    (let [old-time (file-entry :timestamp)
          new-time (os/stat file :mtime)]
      (> new-time old-time))
    # No record, so yes, it's "modified"
    true))
(defn record-definition [type name file form]
  "Record a definition in the database."
  (def location {:file file
                 :line (or (form :line) 1)
                 :column (or (form :column) 1)})

  # Ensure we have a place to store this type of definition
  (unless (get *db* type)
    (put *db* type @{}))

  # Record the definition
  (let [type-db (get *db* type)]
    (unless (get type-db name)
      (put type-db name @[]))
    (array/push (get type-db name) location)))
(defn record-reference [type name file form]
  "Record a reference in the database."
  (def location {:file file
                 :line (or (form :line) 1)
                 :column (or (form :column) 1)})

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
(defn analyze-form [form file &opt parent-form]
  "Analyze a parsed form and update the cross-reference database."
  # Basic stub implementation
  (match (type form)
    :array (each subform form
             (analyze-form subform file form))
    :tuple (match form
             # Handle function definitions
             ['def name & _] (record-definition :var name file form)
             ['defn name args & _] (record-definition :fn name file form)
             ['defmacro name args & _] (record-definition :macro name file form)
             # Handle function calls
             [fn-name & args] (when (and parent-form (symbol? fn-name))
                                (record-reference :calls fn-name file form))
             # Handle other forms recursively
             (each subform form
               (analyze-form subform file form)))
    # Other types can be ignored for basic xref analysis
    nil))
(defn process-file [file]
  "Process a file and update the cross-reference database."
  (try
    # Read file content
    (do
      (def content (slurp file))
      # Parse file
      (def parsed (parse content))
      # Analyze parsed form
      (analyze-form parsed file)
      true)
    ([err fib]
      (eprintf "Error processing file %s: %s\n" file err)
      false)))
(defn clear-xref-database []
  "Clear the cross-reference database."
  (set *db* nil)
  (set *db-updated* nil))

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
      # Parse file and update database
      (when (process-file file)
        (set updated true)
        (set file-updated true)))

    # If processed, update timestamp
    (when file-updated
      (put *db* file {:timestamp (os/stat file :mtime)})))

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
  (let [calls-db (get *db* :calls)
        locations (get calls-db symbol)]
    (or locations @[])))

(defn who-references [symbol]
  "Find all references to SYMBOL."
  (let [refs-db (get *db* :references)
        locations (get refs-db symbol)]
    (or locations @[])))

(defn who-binds [symbol]
  "Find all bindings of SYMBOL."
  (let [var-db (get *db* :var)
        fn-db (get *db* :fn)
        macro-db (get *db* :macro)
        var-locs (get var-db symbol @[])
        fn-locs (get fn-db symbol @[])
        macro-locs (get macro-db symbol @[])]
    (array/concat var-locs fn-locs macro-locs)))

(defn who-sets [symbol]
  "Find all setters of SYMBOL."
  (let [sets-db (get *db* :sets)
        locations (get sets-db symbol)]
    (or locations @[])))

(defn list-callers [files]
  "Update the database for FILES and return it."
  (update-xrefs files)
  *db*)

# Export public API
(def export-api
  @{:list-callers list-callers
    :who-calls who-calls
    :who-references who-references
    :who-binds who-binds
    :who-sets who-sets
    :update-xrefs update-xrefs
    :initialize-database initialize-database})
