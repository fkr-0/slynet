(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(defn- find-plist-by-key [items key value]
  (var found nil)
  (each item items
    (def table (plist->table item))
    (when (and (nil? found) (= value (table key)))
      (set found table)))
  found)

(deftest p25-trace-and-timing-records-source-linked-dev-utility {:tags [:phase25 :trace-profiling]}
  (tt/with-test-server [srv]
    (def trace (plist->table ((srv :emacs-rex!) '(slynet-trace-eval "(+ 1 2)" "/tmp/trace.janet" 7 3) :core nil 2501)))
    (assert= :ok (trace :status))
    (assert= :trace-record (trace :record-kind))
    (assert= "/tmp/trace.janet" (trace :file))
    (assert= 7 (trace :line))
    (assert= "3" (trace :result))
    (assert-true (number? (trace :elapsed-us)))
    (def trace-id (trace :id))
    (assert-true (string? trace-id))
    (def report ((srv :emacs-rex!) '(slynet-trace-report) :core nil 2502))
    (def listed (find-plist-by-key report :id trace-id))
    (assert-not-nil listed)
    (assert= :slynet-source-index-v2 (listed :source-index))
    (def cleared (plist->table ((srv :emacs-rex!) '(slynet-clear-trace-report) :core nil 2503)))
    (assert= :cleared (cleared :status))
    (assert= 1 (cleared :cleared-count))))

(deftest p26-protocol-interface-browser-describes-janet-native-interfaces {:tags [:phase26 :protocol-browser]}
  (tt/with-test-server [srv]
    (def interfaces ((srv :emacs-rex!) '(slynet-protocol-interfaces "namespace") :core nil 2601))
    (def namespace (find-plist-by-key interfaces :name "namespace-completions"))
    (assert-not-nil namespace)
    (assert= :slynet-interface-registry (namespace :source))
    (assert= :native (namespace :support-class))
    (assert-true (string? (namespace :doc)))
    (assert-true (array? (namespace :args)))
    (def described (plist->table ((srv :emacs-rex!) '(slynet-describe-protocol-interface "namespace-completions") :core nil 2602)))
    (assert= "namespace-completions" (described :name))
    (assert= :interface-description (described :record-kind))
    (assert= :native (described :support-class))))

(deftest p27-project-snapshot-and-session-metadata-are-janet-native {:tags [:phase27 :project-snapshot]}
  (tt/with-test-server [srv]
    (def snapshot (plist->table ((srv :emacs-rex!) '(slynet-project-snapshot "/tmp/p27" "demo" @[:deps ["jpm_tree"] :entry "main.janet"]) :core nil 2701)))
    (assert= :ok (snapshot :status))
    (assert= :janet-project-snapshot (snapshot :snapshot-kind))
    (assert= false (snapshot :cl-image-equivalent))
    (assert= "/tmp/p27" (snapshot :project-root))
    (assert= "demo" (snapshot :name))
    (assert-true (string? (snapshot :id)))
    (def session (plist->table ((srv :emacs-rex!) '(slynet-record-session-event "/tmp/p27" "repl-eval" "(+ 1 2)") :core nil 2702)))
    (assert= :recorded (session :status))
    (assert= "repl-eval" (session :event-kind))
    (def metadata (plist->table ((srv :emacs-rex!) '(slynet-session-metadata "/tmp/p27") :core nil 2703)))
    (assert= :janet-repl-session (metadata :session-kind))
    (assert= false (metadata :cl-image-equivalent))
    (assert= 1 (length (metadata :events)))
    (assert= "demo" (((metadata :snapshots) 0) 3))))
