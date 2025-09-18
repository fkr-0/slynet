############################
# mini-test.janet  — tiny test runner with registry, per-assert stats,
# colored output, stdout capture, filters, and patch helpers.
############################

# ========= ANSI + glyphs =========
(def ANSI
  {:reset "\x1b[0m" :bold "\x1b[1m" :dim "\x1b[2m"
   :red "\x1b[31m" :green "\x1b[32m" :yellow "\x1b[33m"})
(def CHECK "✔")
(def CROSS "✘")

(defn color [c s]
  (string (get ANSI c "") s (get ANSI :reset "")))

(defn contains? [coll item]
  (cond
    (array? coll) (some (fn [x] (= x item)) coll)
    (tuple? coll) (some (fn [x] (= x item)) coll)
    (buffer? coll) (some (fn [x] (= x item)) coll)
    (table? coll) (not (= nil (coll item)))
    (struct? coll) (not (= nil (coll item)))
    (string? coll) (not (= -1 (string/find coll item)))
    true false))

# ========= Global registry =========
(var *tests* @{}) # name -> {:name :fn :doc :tags}
(var *last-run* @[]) # vector of result maps from most recent run

# ========= Internal dyns / helpers =========
# Per-test dynamic context during execution
(var *now* (os/time))
(defn now-seconds [] (-> (os/time) (- *now*)))

# A dynamic slot holding current test ctx map during run
# ctx keys we use: :name :doc :tags :asserts(vec) :pass :fail :stdout :started
# We also let runner install an :on-assert hook for streaming output.
# (No default value – we'll bind it when running.)
# (dyn :current-test)  ; intentionally not pre-bound

(defn register-test [spec]
  (def name (string (or (get spec :name)
                        (error "deftest: :name required"))))
  (def fn-body (or (get spec :fn) (error "deftest: :fn required")))
  (def raw-tags (get spec :tags))
  (def norm
    {:name name
     :fn fn-body
     :doc (get spec :doc "")
     :tags (if raw-tags
             (if (array? raw-tags) raw-tags (tuple raw-tags))
             @[])})
  (put *tests* name norm)
  name)

# Pretty headers
(defn banner-running [name]
  (string "======running test " name "======="))
(defn banner-done [ctx]
  (string "======[" (ctx :pass) "/" (+ (ctx :pass) (ctx :fail))
          "] test " (ctx :name) "========="))

# Record an assertion (stream + store)
(defn test-assert! [ok msg &opt data]
  (def ctx (dyn :current-test))
  (when (nil? ctx) (error "assert used outside of a running test"))
  (def rec {:ok ok :msg (string msg) :data data})
  (def asserts (get ctx :asserts))
  (array/push asserts rec)
  (if ok
    (put ctx :pass (+ (get ctx :pass) 1))
    (put ctx :fail (+ (get ctx :fail) 1)))
  (when-let [printer (dyn :on-assert)]
    (printer rec ctx))
  ok)

# ========= Assertions (non-throwing ‘check’ style) =========
# note: mind ~ , ,; in macros

(defmacro assert= [a b &opt msg]
  (let [ga (gensym) gb (gensym)]
    ~(let [,ga ,a ,gb ,b]
       (if (= ,ga ,gb)
         (test-assert! true (or ,msg (string "(= " (pp ,a) " " (pp ,b) ")"))
                       {:type := :got ,ga :want ,gb})
         (test-assert! false (or ,msg (string (pp ,a) " != " (pp ,b)))
                       {:type := :got ,ga :want ,gb})))))

(defmacro assert-approx= [a b eps &opt msg]
  (let [ga (gensym) gb (gensym) ge (gensym)]
    ~(let [,ga ,a ,gb ,b ,ge ,eps]
       (def ok (<= (math/abs (- ,ga ,gb)) ,ge))
       (test-assert! ok
                     (or ,msg (string "approx " (pp ,a) " ~= " (pp ,b) " ± " (pp ,eps)))
                     {:type :approx :got ,ga :want ,gb :eps ,ge}))))

(defmacro assert-true [expr &opt msg]
  (let [gx (gensym)]
    ~(let [,gx ,expr]
       (test-assert! ,gx (or ,msg (string (pp ',expr) " is truthy"))
                     {:type :true :got ,gx}))))

(defmacro assert-false [expr &opt msg]
  (let [gx (gensym)]
    ~(let [,gx ,expr]
       (test-assert! (not ,gx) (or ,msg (string (pp ',expr) " is falsy"))
                     {:type :false :got ,gx}))))

(defmacro assert-in [x coll &opt msg]
  (let [gx (gensym) gc (gensym)]
    ~(let [,gx ,x ,gc ,coll]
       (test-assert! (contains? ,gc ,gx)
                     (or ,msg (string (pp ,x) " ∈ " (pp ,coll)))
                     {:type :in :elem ,gx :coll ,gc}))))

(defmacro assert-pred [pred x &opt msg]
  (let [gp (gensym) gx (gensym)]
    ~(let [,gp ,pred ,gx ,x]
       (def ok (,gp ,gx))
       (test-assert! ok (or ,msg (string "predicate " (pp ',pred) " " (pp ,gx)))
                     {:type :pred :pred ',pred :arg ,gx}))))

(defmacro assert-throws [& body]
  ~(do
     (var threw false)
     (var msg "expected exception")
     (try (do ,;body) ([e _] (set threw true)))
     (test-assert! threw msg {:type :throws})))

# A "require-" variant that aborts test on failure (throws)
(defmacro require-true [expr &opt msg]
  ~(when (not ,expr)
     (error (or ,msg (string "required truthy: " (pp ',expr))))))

# ========= Test definition macro =========
# Forms:
#   (deftest name "doc" {:tags [:unit :fast]} body...)
#   (deftest name {:tags [:slow]} body...)
#   (deftest name body...)
(defmacro deftest [name & body]
  (let [nm (string name)
        pieces body
        has-doc? (and (not (empty? pieces)) (string? (first pieces)))
        doc (if has-doc? (first pieces) "")
        rest1 (if has-doc? (slice pieces 1) pieces)
        has-meta? (and (not (empty? rest1)) (table? (first rest1)))
        meta (if has-meta? (first rest1) @{})
        body-forms (if has-meta? (slice rest1 1) rest1)]
    ~(register-test
       {:name ,nm
        :doc ,doc
        :tags ,(or (get meta :tags) @[])
        :fn (fn []
              ,;body-forms)})))

# ========= Selection helpers =========
(defn name-matches? [nm opts]
  (cond
    (get opts :only) (some (fn [x] (= (string x) nm)) (get opts :only))
    (get opts :match) (not (= -1 (string/find nm (get opts :match))))
    true :true))

(defn tags-match? [test-tags opts]
  (if-let [want (get opts :tags)]
    (some (fn [t] (in t test-tags)) want)
    true))

# ========= Printing helpers =========
(defn print-assert-line [rec]
  (if (rec :ok)
    (print "  " (color :green CHECK) " " (rec :msg) "\n")
    (do
      (print "  " (color :red CROSS) " " (rec :msg) "\n")
      (when-let [d (rec :data)]
        # small diff block if present
        (when (and d (or (table? d) (struct? d)) (contains? d :want))
          (print (color :dim "    want: ") (pp (d :want)) "\n"))
        (when (and d (or (table? d) (struct? d)) (contains? d :got))
          (print (color :dim "    got : ") (pp (d :got)) "\n"))))))

# ========= Stdout capture =========
(defn capture-out [thunk]
  (def buf (buffer/new 0))
  (with-dyns {:out buf}
    (thunk))
  (string buf))

# ========= Run a single test =========
(defn run-one [spec opts]
  (def ctx @{:name (get spec :name)
             :doc (get spec :doc "")
             :tags (or (get spec :tags) @[])
             :asserts @[] :pass 0 :fail 0 :stdout "" :started (now-seconds)})
  (when (get opts :headers true) (print (banner-running (ctx :name)) "\n"))
  (def on-assert
    (fn [rec _]
      (case (get opts :stream :auto)
        :auto (when (or (not (rec :ok)) (get opts :verbose)) (print-assert-line rec))
        :all (print-assert-line rec)
        :fails (when (not (rec :ok)) (print-assert-line rec))
        :none nil)))
  (def body (get spec :fn))
  (var err nil)
  (def stdout
    (capture-out
      (fn []
        (with-dyns [:current-test ctx :on-assert on-assert]
          (try
            (body)
            ([e _] (set err e)))))))
  (put ctx :stdout stdout)
  (when err
    (with-dyns [:current-test ctx :on-assert on-assert]
      (test-assert! false (string "uncaught error: " err) {:type :error})))
  (when (get opts :headers true) (print (banner-done ctx) "\n"))
  ctx)

# ========= Public runner =========
# Options:
#  :only   ["name1" "name2"]     exact names
#  :match  "substring"           substring match
#  :tags   [:unit :slow]         match any tag
#  :stream :auto|:all|:fails|:none
#  :stdout :on-failure|:always|:never
#  :headers true|false           show running/done banners
#  :verbose true|false           stream passing asserts under :auto
(defn run-tests [&opt opts]
  (default opts @{})
  (set *last-run* @[])
  (def chosen
    (->> (values *tests*)
         (filter (fn [t] (and (name-matches? (t :name) opts)
                              (tags-match? (t :tags) opts))))))
    (when (empty? chosen)
      (print (color :yellow "No tests selected.\n")))

    (var total-pass 0)
    (var total-fail 0)
    (var total-asserts 0)

    (each spec chosen
      (def ctx (run-one spec opts))
      (array/push *last-run* ctx)
      (set total-pass (+ total-pass (ctx :pass)))
      (set total-fail (+ total-fail (ctx :fail)))
      (set total-asserts (+ total-asserts (+ (ctx :pass) (ctx :fail))))

      (case (get opts :stdout :on-failure)
        :always
        (when (not (= "" (ctx :stdout)))
          (print (color :dim "----- stdout -----\n")
                 (ctx :stdout)
                 (color :dim "\n------------------\n")))
        :on-failure
        (when (and (> (ctx :fail) 0) (not (= "" (ctx :stdout))))
          (print (color :dim "----- stdout (failed) -----\n")
                 (ctx :stdout)
                 (color :dim "\n---------------------------\n")))
        :never nil))

    # Summary
    (def total-tests (length chosen))
    (print "\n")
    (print (color (if (= total-fail 0) :green :red)
                  (string "Summary: " total-tests " tests, "
                          total-pass "/" total-asserts " asserts passed, "
                          total-fail " failed"))
           "\n")

    # Group failing tests with brief lines
    (when (> total-fail 0)
      (print (color :red "Failing tests:\n"))
      (each ctx *last-run*
        (when (> (ctx :fail) 0)
          (print "  " (color :red CROSS) " " (ctx :name)
                 " [" (ctx :pass) "/" (+ (ctx :pass) (ctx :fail)) "]\n"))))

    (when (> total-fail 0)
      (error (string total-fail " test(s) failed"))))

############################
# Monkey-patching helpers + spies
############################

# Patch entries in module/env tables and restore automatically.
# Usage:
# (with-patches [[mymod 'fn (fn [& xs] :stub)]
#                [(require :foo) 'bar 42]]
#   ...body...)
(defn patch! [triple olds]
  (def env-or-name (triple 0))
  (def env (if (table? env-or-name) env-or-name (require env-or-name)))
  (def key (triple 1))
  (def newv (triple 2))
  (def prev (get env key))
  (array/push olds [env key prev])
  (put env key newv))

(defn unpatch-all! [olds]
  (each rec olds (put (rec 0) (rec 1) (rec 2))))

(defmacro with-patches [triples & body]
  (let [olds (gensym)]
    ~(let [,olds @[]]
       (try
         (do
           ,;(map (fn [t] ~(patch! ,t ,olds)) triples)
           ,;body)
         ([e _] (do (unpatch-all! ,olds) (error e)))
         (finally (unpatch-all! ,olds))))))

# Simple spy wrapper
(defn make-spy [f]
  (def calls @[])
  (def w
    (fn [& xs]
      (def r (apply f xs))
      (array/push calls {:args xs :ret r})
      r))
  {:fn w :calls calls})
(defn spy-calls [spy] (spy :calls))
(defn spy-reset! [spy] (set (spy :calls) @[]))

# (run-tests {:only ["patching"] :headers false :verbose false})

############################
# CLI helpers
############################

(defn- ensure-string [v]
  (cond
    (string? v) v
    (keyword? v) (string v)
    (symbol? v) (string v)
    true (string v)))

(defn- parse-bool [s]
  (def str (ensure-string s))
  (cond
    (or (= str "true") (= str "1")) true
    (or (= str "false") (= str "0")) false
    true (error (string "Expected boolean string, got " str))))

(defn- parse-list [s]
  (def str (ensure-string s))
  (def raw (if (string/find "," str)
             (string/split str ",")
             @[str]))
  (map string/trim raw))

(defn- parse-tags [s]
  (map (fn [tok]
         (def cleaned (if (and (> (length tok) 0) (= (tok 0) 58))
                        (string/slice tok 1)
                        tok))
         (keyword cleaned))
       (parse-list s)))

(defn- parse-keyword [s]
  (def str (ensure-string s))
  (keyword (if (and (> (length str) 0) (= (str 0) 58))
             (string/slice str 1)
             str)))

(defn parse-cli-args [args]
  (def opts @{})
  (var i 0)
  (while (< i (length args))
    (def raw (args i))
    (def raw-str (if (keyword? raw) (string raw) raw))
    (if (and (string? raw-str) (> (length raw-str) 0) (= (raw-str 0) 58))
      (do
        (def key (keyword (string/slice raw-str 1)))
        (set i (+ i 1))
        (if (>= i (length args))
          (put opts key true)
          (let [val (args i)]
            (case key
              :only (put opts key (parse-list val))
              :tags (put opts key (parse-tags val))
              :headers (put opts key (parse-bool val))
              :verbose (put opts key (parse-bool val))
              :stream (put opts key (parse-keyword val))
              :stdout (put opts key (parse-keyword val))
              (put opts key val)))))
      (error (string "Unrecognized argument: " raw)))
    (set i (+ i 1)))
  opts)

(defn main [& args]
  (def rest-args
    (if (and (> (length args) 0)
             (string? (args 0))
             (not (and (> (length (args 0)) 0)
                       (= (string/slice (args 0) 0 1) ":"))))
      (slice args 1)
      args))
  (def opts (parse-cli-args rest-args))
  (run-tests opts))
