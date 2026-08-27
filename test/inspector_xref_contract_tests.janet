(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(register-test
  {:name "inspector responses expose stable object identity metadata"
   :tags [:phase4 :inspector]
   :covers ["inspect-for-emacs" "inspector-nth-part" "inspector-pop"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def root (plist->table ((srv :emacs-rex!) '(inspect-for-emacs @[10 20 30]) :core nil 2001)))
             (def child (plist->table ((srv :emacs-rex!) '(inspector-nth-part 1) :core nil 2002)))
             (def popped (plist->table ((srv :emacs-rex!) '(inspector-pop) :core nil 2003)))
             (assert-true (string? (root :object-id)))
             (assert= (root :object-id) (child :parent-object-id))
             (assert= "1" (child :part-key))
             (assert= "20" (child :title))
             (assert= (root :object-id) (popped :object-id)))))})

(register-test
  {:name "xref responses expose source-index contract metadata"
   :tags [:phase4 :xref]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def hits ((srv :emacs-rex!) '(find-definitions-for-emacs "connection-info") :core nil 2004))
             (assert-true (array? hits))
             (assert-true (> (length hits) 0))
             (def hit (plist->table (hits 0)))
             (assert= :slynet-source-index-v2 (hit :source-index))
             (assert= :definition (hit :xref-kind))
             (assert-true (string? (hit :file)))
             (assert-true (number? (hit :line)))
             (assert-true (number? (hit :column)))
             (assert-true (string? (hit :snippet))))))})

(def fixture-dir (string (os/cwd) "/test/fixtures/xref"))
(def sample-a-path (string fixture-dir "/sample_a.janet"))
(def sample-b-path (string fixture-dir "/sample_b.janet"))

(defn- path-contains? [path needle]
  (not (nil? (string/find needle path))))

(defn- first-hit-in-file [hits file-fragment]
  (var found nil)
  (each hit hits
    (def t (plist->table hit))
    (when (and (nil? found) (path-contains? (t :file) file-fragment))
      (set found t)))
  found)

(defn- xref-test-delimiter? [ch]
  (or (nil? ch)
      (= ch 9)
      (= ch 10)
      (= ch 13)
      (= ch 32)
      (= ch 40)
      (= ch 41)
      (= ch 91)
      (= ch 93)
      (= ch 34)
      (= ch 59)))

(defn- source-definition-line-column [path line-needle symbol-needle]
  (def lines (string/split "\n" (slurp path)))
  (var out nil)
  (for i 0 (length lines)
    (def line (string/trim (lines i)))
    (def symbol-idx (string/find symbol-needle line))
    (def after (length line-needle))
    (when (and (nil? out)
               (string/has-prefix? line-needle line)
               (xref-test-delimiter? (if (< after (length line)) (line after) nil))
               (not (nil? symbol-idx)))
      (set out @{:line (+ i 1) :column (+ symbol-idx 1) :snippet line})))
  (or out (error (string "definition line not found in fixture: " line-needle))))

(register-test
  {:name "xref fixture definitions return exact source facts"
   :tags [:phase4 :xref :fixture]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def hits ((srv :emacs-rex!) '(find-definitions-for-emacs "fixture-target") :core nil 2010))
             (def hit (first-hit-in-file hits "test/fixtures/xref/sample_a.janet"))
             (def expected (source-definition-line-column sample-a-path "(defn fixture-target" "fixture-target"))
             (assert-not-nil hit)
             (assert= "fixture-target" (hit :name))
             (assert= :function (hit :kind))
             (assert= :definition (hit :xref-kind))
             (assert= :slynet-source-index-v2 (hit :source-index))
             (assert= (expected :line) (hit :line))
             (assert= (expected :column) (hit :column))
             (assert= (expected :snippet) (hit :snippet))
             (each result hits
               (def result-table (plist->table result))
               (assert-false
                 (and (path-contains? (result-table :file) "slynet/slynk.janet")
                      (= 1 (result-table :line))
                      (path-contains? (result-table :snippet) "[& args]")))))))})

(register-test
  {:name "xref fixture definitions ignore comments strings and symbol substrings"
   :tags [:phase4 :xref :fixture]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def hits ((srv :emacs-rex!) '(find-definitions-for-emacs "fixture-target") :core nil 2011))
             (assert-true (> (length hits) 0))
             (each hit hits
               (def t (plist->table hit))
               (when (path-contains? (t :file) "test/fixtures/xref/sample_a.janet")
                 (assert-false (path-contains? (t :snippet) "fixture-target-extra"))
                 (assert-false (path-contains? (t :snippet) "fixture-target-string"))
                 (assert-false (path-contains? (t :snippet) "fixture-target-comment")))))))} )

(register-test
  {:name "xref fixture macro and interface kinds are explicit"
   :tags [:phase4 :xref :fixture]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def macro-hits ((srv :emacs-rex!) '(find-definitions-for-emacs "fixture-macro") :core nil 2012))
             (def interface-hits ((srv :emacs-rex!) '(find-definitions-for-emacs "fixture-interface") :core nil 2013))
             (def macro-hit (first-hit-in-file macro-hits "test/fixtures/xref/sample_a.janet"))
             (def interface-hit (first-hit-in-file interface-hits "test/fixtures/xref/sample_a.janet"))
             (assert-not-nil macro-hit)
             (assert-not-nil interface-hit)
             (assert= :macro (macro-hit :kind))
             (assert= :interface (interface-hit :kind)))))} )

(register-test
  {:name "inspector compatibility tools reuse native inspector state"
   :tags [:phase4 :inspector :compatibility]
   :covers ["init-inspector" "inspect-in-emacs" "inspect-nth-part"
            "inspector-nth-part-or-lose" "describe-inspectee"
            "pprint-inspector-part" "inspector-eval" "eval-for-inspector"
            "quit-inspector"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def root (plist->table ((srv :emacs-rex!) '(init-inspector @[10 20 30]) :core nil 2020)))
           (assert-true (string? (root :object-id)))
           (def child (plist->table ((srv :emacs-rex!) '(inspect-nth-part 1) :core nil 2021)))
           (assert= "20" (child :title))
           ((srv :emacs-rex!) '(inspector-pop) :core nil 2022)
           (assert= "30" ((srv :emacs-rex!) '(pprint-inspector-part 2) :core nil 2023))
           (def described (plist->table ((srv :emacs-rex!) '(describe-inspectee) :core nil 2024)))
           (assert= :ok (described :status))
           (assert= :array (described :type))
           (def evaluated (plist->table ((srv :emacs-rex!) '(inspector-eval "(+ 20 22)") :core nil 2025)))
           (assert= "42" (evaluated :title))
           (def evaluated-form (plist->table ((srv :emacs-rex!) '(eval-for-inspector (+ 40 3)) :core nil 2026)))
           (assert= "43" (evaluated-form :title))
           (def direct (plist->table ((srv :emacs-rex!) '(inspect-in-emacs @[7 8]) :core nil 2027)))
           (assert-true (string? (direct :object-id)))
           (def exact (plist->table ((srv :emacs-rex!) '(inspector-nth-part-or-lose 0) :core nil 2028)))
           (assert= "7" (exact :title))
           (def closed (plist->table ((srv :emacs-rex!) '(quit-inspector) :core nil 2029)))
           (assert= :closed (closed :status))
           (assert-true (> (closed :cleared) 0))))})

(register-test
  {:name "definition compatibility tools expose source-index locations"
   :tags [:phase4 :xref :compatibility]
   :covers ["find-definition-for-thing" "find-source-location-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def hit (plist->table
                      ((srv :emacs-rex!) '(find-definition-for-thing "fixture-target")
                       :core nil 2030)))
           (assert= "fixture-target" (hit :name))
           (assert-true (string? (hit :file)))
           (def location (plist->table
                           ((srv :emacs-rex!) '(find-source-location-for-emacs "fixture-target")
                            :core nil 2031)))
           (assert= (hit :file) (location :file))
           (assert= (hit :line) (location :line))
           (assert= (hit :column) (location :column))
           (assert= :definition (location :xref-kind))))})

