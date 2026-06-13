(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)


(defn- array-contains? [items value]
  (var found false)
  (each item items
    (when (= item value)
      (set found true)))
  found)

(defn- find-plist-by-key [items key value]
  (var found nil)
  (each item items
    (def table (plist->table item))
    (when (and (nil? found) (= value (table key)))
      (set found table)))
  found)

(deftest p21-execution-unit-registry-lifecycle {:tags [:phase21 :execution-unit-registry]}
  (tt/with-test-server [srv]
    (def created (plist->table ((srv :emacs-rex!) '(start-execution-unit "phase21 long eval" :eval @[:path "fixture.janet" :line 3]) :core nil 2101)))
    (def unit-id (created :id))
    (assert-true (string? unit-id))
    (assert= :running (created :status))
    (assert= :eval (created :role))
    (assert-true (number? (created :started-at)))
    (def listed ((srv :emacs-rex!) '(list-execution-units) :core nil 2102))
    (def listed-unit (find-plist-by-key listed :id unit-id))
    (assert-not-nil listed-unit)
    (assert= "phase21 long eval" (listed-unit :name))
    (assert= :managed (listed-unit :execution-unit-kind))
    (def interrupted (plist->table ((srv :emacs-rex!) (tuple 'interrupt-execution-unit unit-id) :core nil 2103)))
    (assert= :requested (interrupted :status))
    (assert= true (interrupted :interrupted))
    (assert= true ((srv :emacs-rex!) (tuple 'execution-unit-interrupted? unit-id) :core nil 2104))
    (def finished (plist->table ((srv :emacs-rex!) (tuple 'finish-execution-unit unit-id :completed "done") :core nil 2105)))
    (assert= :completed (finished :status))
    (assert= "done" (finished :last-output))))

(deftest p22-diagnostics-source-integration {:tags [:phase22 :diagnostics-source]}
  (tt/with-test-server [srv]
    (def compile-res (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(defn") :core nil 2201)))
    (def compile-diag (plist->table ((compile-res :diagnostics) 0)) )
    (assert= false (compile-res :success))
    (assert= :janet-diagnostics (compile-diag :diagnostic-model))
    (assert= :compile-string (compile-diag :phase))
    (assert-true (number? (compile-diag :line)))
    (assert-true (number? (compile-diag :column)))
    (assert= :buffer (compile-diag :source-kind))
    (def runtime-res (plist->table ((srv :emacs-rex!) '(runtime-eval-diagnostics "(error \"boom\")" "test/fixtures/xref/sample_a.janet" 12 3) :core nil 2202)))
    (def runtime-diag (plist->table ((runtime-res :diagnostics) 0)))
    (assert= false (runtime-res :success))
    (assert= :runtime-eval (runtime-diag :phase))
    (assert= "test/fixtures/xref/sample_a.janet" (runtime-diag :path))
    (assert= 12 (runtime-diag :line))
    (assert= 3 (runtime-diag :column))
    (assert= :slynet-diagnostic-source (runtime-diag :source-index))
    (def test-diag (plist->table ((srv :emacs-rex!) '(normalize-test-failure-diagnostic "fixture test" "bad" "test/fixtures/xref/sample_a.janet" 4) :core nil 2203)))
    (assert= :test-failure (test-diag :phase))
    (assert= "fixture test" (test-diag :test-name))))

(deftest p23-completion-namespace-source-index {:tags [:phase23 :completion-namespace]}
  (tt/with-test-server [srv]
    (def result ((srv :emacs-rex!) '(simple-completions "p23-fixture" "core") :core nil 2301))
    (def names (result 0))
    (assert-true (not (nil? (array-contains? names "p23-fixture-helper"))))
    (def candidates ((srv :emacs-rex!) '(source-index-completion-candidates "p23-fixture" "core") :core nil 2302))
    (def candidate (find-plist-by-key candidates :name "p23-fixture-helper"))
    (assert-not-nil candidate)
    (assert= :source-index (candidate :source))
    (assert= :emulated (candidate :support-class))
    (assert= "fixture.completion" (candidate :module))
    (assert-true (string? (candidate :doc-summary)))
    (assert-true (string? (candidate :file)))
    (assert-true (number? (candidate :line)))))

(deftest p24-project-server-lifecycle-status {:tags [:phase24 :project-server-lifecycle]}
  (tt/with-test-server [srv]
    (def ready (plist->table ((srv :emacs-rex!) '(ensure-project-server-ready "/tmp/slynet-p24" "p24") :core nil 2401)))
    (assert= :ready (ready :status))
    (assert= true (ready :ready))
    (assert= :observable-status (ready :readiness-source))
    (def reconnected (plist->table ((srv :emacs-rex!) '(project-server-reconnect "p24" "/tmp/slynet-p24") :core nil 2402)))
    (assert= :reconnected (reconnected :status))
    (assert= true (reconnected :identity-preserved))
    (def stale (plist->table ((srv :emacs-rex!) '(project-server-note-stale "/tmp/slynet-p24" "socket missing") :core nil 2403)))
    (assert= :stale (stale :status))
    (assert= false (stale :ready))
    (assert= "socket missing" (stale :reason))
    (def status (plist->table ((srv :emacs-rex!) '(project-server-status "/tmp/slynet-p24") :core nil 2404)))
    (assert= :stale (status :status))
    (assert= "p24" (status :name))))
