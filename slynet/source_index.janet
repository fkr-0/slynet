# Span-aware Janet source index for SLYNET.
# This is a SLYNET-level source scanner, not a Janet runtime source-map API.

(var *project-cache* @{})

(defn- join-path [base name]
  (if (or (= base "") (= base "/"))
    (string base name)
    (string base "/" name)))

(defn clear-cache! []
  (set *project-cache* @{})
  true)

(defn- janet-file? [path]
  (string/has-suffix? ".janet" path))

(defn- ignored-dir? [entry]
  (or (= entry ".git")
      (= entry ".worktrees")
      (= entry "o")
      (= entry "bundle")
      (= entry "build")
      (= entry "dist")))

(defn collect-files [root]
  (def out @[])
  (defn walk [dir]
    (each entry (try (os/dir dir) ([_ _] @[]))
      (let [path (join-path dir entry)
            stat (try (os/stat path) ([_ _] nil))]
        (when stat
          (cond
            (= (stat :mode) :directory)
            (unless (ignored-dir? entry) (walk path))

            (and (= (stat :mode) :file) (janet-file? path))
            (array/push out path))))))
  (walk root)
  out)

(defn- first-non-space [line]
  (var i 0)
  (while (and (< i (length line))
              (or (= (line i) 9) (= (line i) 32)))
    (++ i))
  i)

(defn- delimiter? [ch]
  (or (nil? ch)
      (= ch 9)
      (= ch 10)
      (= ch 13)
      (= ch 32)
      (= ch 40)
      (= ch 41)
      (= ch 91)
      (= ch 93)
      (= ch 123)
      (= ch 125)
      (= ch 34)))

(defn- read-token [line start]
  (var end start)
  (while (and (< end (length line))
              (not (delimiter? (line end))))
    (++ end))
  (string/slice line start end))

(defn- count-parens [line]
  (var i 0)
  (var balance 0)
  (var in-string false)
  (var escaped false)
  (while (< i (length line))
    (let [ch (line i)]
      (cond
        escaped (set escaped false)
        (and in-string (= ch 92)) (set escaped true)
        (= ch 34) (set in-string (not in-string))
        (and (not in-string) (= ch 35)) (set i (length line))
        (and (not in-string) (= ch 59)) (set i (length line))
        (and (not in-string) (= ch 40)) (++ balance)
        (and (not in-string) (= ch 41)) (-- balance)))
    (++ i))
  balance)

(defn- end-position [lines start-idx]
  (var balance 0)
  (var end-line (+ start-idx 1))
  (var end-column (length (lines start-idx)))
  (var i start-idx)
  (while (< i (length lines))
    (set balance (+ balance (count-parens (lines i))))
    (set end-line (+ i 1))
    (set end-column (length (lines i)))
    (when (<= balance 0)
      (set i (length lines)))
    (++ i))
  [end-line end-column])

(defn- form-specs []
  @[@{:prefix "(defn " :kind :function}
    @{:prefix "(defmacro " :kind :macro}
    @{:prefix "(definterface " :kind :interface}
    @{:prefix "(def " :kind :value}
    @{:prefix "(var " :kind :var}
    @{:prefix "(import " :kind :import}
    @{:prefix "(use " :kind :use}])

(defn- module-name-from-line [line]
  (def start (first-non-space line))
  (def prefix "(module ")
  (when (string/has-prefix? prefix (string/slice line start))
    (read-token line (+ start (length prefix)))))

(defn- record-from-line [path lines idx module-name]
  (def line (lines idx))
  (def start (first-non-space line))
  (if (or (>= start (length line))
          (= (line start) 35)
          (= (line start) 59)
          (= (line start) 34))
    nil
    (do
      (var out nil)
      (each spec (form-specs)
        (def prefix (spec :prefix))
        (def tail (string/slice line start))
        (when (and (nil? out) (string/has-prefix? prefix tail))
          (let [token-start (+ start (length prefix))
                name (read-token line token-start)
                after (+ token-start (length name))]
            (when (and (> (length name) 0)
                       (delimiter? (if (< after (length line)) (line after) nil)))
              (let [end (end-position lines idx)]
                (set out @{:name name
                           :file path
                           :line (+ idx 1)
                           :column (+ token-start 1)
                           :end-line (end 0)
                           :end-column (end 1)
                           :form-kind (spec :kind)
                           :kind (spec :kind)
                           :module (or module-name "core")
                           :snippet (string/trim line)
                           :source-index :slynet-source-index-v2}))))))
      out)))

(defn index-file [path]
  (def records @[])
  (let [content (try
                  (let [fh (file/open path :r)
                        text (file/read fh :all)]
                    (file/close fh)
                    (string text))
                  ([_ _] nil))]
    (when (string? content)
      (def lines (string/split "\n" content))
      (var module-name nil)
      (for i 0 (length lines)
        (when-let [m (module-name-from-line (lines i))]
          (set module-name m))
        (when-let [record (record-from-line path lines i module-name)]
          (array/push records record)))))
  records)

(defn- project-signature [root files]
  (def sig @[])
  (each path files
    (let [stat (try (os/stat path) ([_ _] nil))]
      (when stat
        (array/push sig [path (stat :mtime) (stat :size)]))))
  sig)

(defn- signature-equal? [a b]
  (= (string a) (string b)))

(defn index-project [root]
  (def files (collect-files root))
  (def sig (project-signature root files))
  (def cached (*project-cache* root))
  (if (and cached (signature-equal? sig (cached :signature)))
    (cached :records)
    (do
      (def records @[])
      (each path files
        (each record (index-file path)
          (array/push records record)))
      (put *project-cache* root @{:signature sig :records records})
      records)))

(defn find-definitions [root name]
  (def out @[])
  (each record (index-project root)
    (when (= name (record :name))
      (array/push out record)))
  out)

(defn record->xref-hit [record]
  @[:name (record :name)
    :file (record :file)
    :line (record :line)
    :column (record :column)
    :kind (record :kind)
    :xref-kind :definition
    :source-index :slynet-source-index-v2
    :match (record :name)
    :snippet (record :snippet)
    :end-line (record :end-line)
    :end-column (record :end-column)
    :form-kind (record :form-kind)
    :module (record :module)])

(defn find-definition-hits [root name]
  (def out @[])
  (each record (find-definitions root name)
    (array/push out (record->xref-hit record)))
  out)
