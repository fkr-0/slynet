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
  (string "/tmp/slynet-source-index-v2-" (os/getpid)))

(defn- ensure-dir [path]
  (try (os/mkdir path) ([_ _] nil))
  path)

(defn- write-fixture! [root body]
  (ensure-dir root)
  (spit (string root "/alpha.janet") body)
  (string root "/alpha.janet"))

(defn- first-record [records name]
  (var found nil)
  (each record records
    (when (and (nil? found) (= name (record :name)))
      (set found record)))
  found)

(deftest p18-source-index-v2-records-span-aware-facts {:tags [:phase18 :source-index-v2]}
  (def root (fixture-root))
  (def file (write-fixture! root "# ignored fixture-target-comment\n(def fixture-target-string \"not a defn fixture-target\")\n(module fixture.alpha)\n(import ./beta :as beta)\n(use ./gamma)\n(definterface fixture-interface [x] \"fixture protocol\")\n(defmacro fixture-macro [x]\n  x)\n(defn fixture-target [x]\n  (+ x 1))\n(def fixture-value 42)\n(defn fixture-target-extra [] :nope)\n"))
  (source-index/clear-cache!)
  (def records (source-index/index-project root))
  (def target (first-record records "fixture-target"))
  (def macro-record (first-record records "fixture-macro"))
  (def interface-record (first-record records "fixture-interface"))
  (def import-record (first-record records "./beta"))
  (def use-record (first-record records "./gamma"))
  (assert-not-nil target)
  (assert= file (target :file))
  (assert= 9 (target :line))
  (assert= 7 (target :column))
  (assert= 10 (target :end-line))
  (assert-true (number? (target :end-column)))
  (assert= :function (target :form-kind))
  (assert= "fixture.alpha" (target :module))
  (assert= "(defn fixture-target [x]" (target :snippet))
  (assert= :macro (macro-record :form-kind))
  (assert= :interface (interface-record :form-kind))
  (assert= :import (import-record :form-kind))
  (assert= :use (use-record :form-kind)))

(deftest p18-source-index-v2-cache-invalidates {:tags [:phase18 :source-index-v2]}
  (def root (string (fixture-root) "-cache"))
  (write-fixture! root "(defn stale-target [] :old)\n")
  (source-index/clear-cache!)
  (def first (source-index/find-definitions root "stale-target"))
  (assert= 1 (length first))
  (spit (string root "/alpha.janet") "(defn stale-target [] :old)\n(defn fresh-target [] :new)\n")
  (def fresh (source-index/find-definitions root "fresh-target"))
  (assert= 1 (length fresh))
  (assert= 2 ((fresh 0) :line))
  (assert= "fresh-target" ((fresh 0) :name)))

(deftest p18-source-index-v2-cache-invalidates-same-size-edit {:tags [:phase18 :source-index-v2]}
  (def root (string (fixture-root) "-same-size-cache"))
  (def file (write-fixture! root "(defn old-target [] :ok)\n"))
  (source-index/clear-cache!)
  (assert= 1 (length (source-index/find-definitions root "old-target")))
  # Janet 1.40 exposes the file timestamp as :modified. Wait across the
  # filesystem timestamp boundary, then rewrite with identical byte length so
  # cache invalidation cannot accidentally pass because :size changed.
  (os/sleep 1.05)
  (spit file "(defn new-target [] :ok)\n")
  (assert= 0 (length (source-index/find-definitions root "old-target")))
  (def fresh (source-index/find-definitions root "new-target"))
  (assert= 1 (length fresh))
  (assert= 1 ((fresh 0) :line)))

(deftest p18-xref-prefers-source-index-v2-facts {:tags [:phase18 :source-index-v2 :xref]}
  (tt/with-test-server [srv]
    (def hits ((srv :emacs-rex!) '(find-definitions-for-emacs "fixture-target") :core nil 1818))
    (assert-true (> (length hits) 0))
    (def hit (plist->table (hits 0)))
    (assert= :slynet-source-index-v2 (hit :source-index))
    (assert= :definition (hit :xref-kind))
    (assert= :function (hit :form-kind))
    (assert-true (number? (hit :end-line)))
    (assert-true (number? (hit :end-column)))
    (assert-true (string? (hit :module)))))
