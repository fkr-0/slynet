(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/source_index :as source-index)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(defn- fixture-root []
  (string "/tmp/slynet-completion-namespace-" (os/getpid)))

(defn- write-fixture! [root body]
  (try (os/mkdir root) ([_ _] nil))
  (spit (string root "/complete.janet") body)
  (string root "/complete.janet"))

(deftest p23-namespace-completion-uses-source-index-docs {:tags [:phase23 :completion-namespace]}
  (def root (fixture-root))
  (def file (write-fixture! root "(module completion.fixture)\n(defn local-alpha [x]\n  \"Adds one for completion tests.\"\n  (+ x 1))\n(def local-value 42)\n(import ./other :as other)\n"))
  (source-index/clear-cache!)
  (tt/with-test-server [srv]
    (def result ((srv :emacs-rex!) (tuple 'namespace-completions "local" root "completion.fixture") :core nil 2301))
    (def candidates (result 0))
    (def common (result 1))
    (assert= "local-" common)
    (assert-true (>= (length candidates) 2))
    (def first (plist->table (candidates 0)))
    (assert= "local-alpha" (first :name))
    (assert= file (first :file))
    (assert= "completion.fixture" (first :module))
    (assert= :function (first :form-kind))
    (assert= :slynet-source-index-v2 (first :source-index))
    (assert-true (string? (first :doc-summary)))
    (assert= :native (first :support-class))))

(deftest p23-namespace-completion-cache-invalidates-on-source-edit {:tags [:phase23 :completion-namespace]}
  (def root (string (fixture-root) "-cache"))
  (write-fixture! root "(defn stale-completion [] :old)\n")
  (source-index/clear-cache!)
  (tt/with-test-server [srv]
    (def first ((srv :emacs-rex!) (tuple 'namespace-completions "fresh" root "core") :core nil 2302))
    (assert= 0 (length (first 0)))
    (spit (string root "/complete.janet") "(defn fresh-completion [] :new)\n")
    (def second ((srv :emacs-rex!) (tuple 'namespace-completions "fresh" root "core") :core nil 2303))
    (assert= 1 (length (second 0)))
    (def candidate (plist->table ((second 0) 0)))
    (assert= "fresh-completion" (candidate :name))))
