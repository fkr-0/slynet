(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(defn- find-action [actions action-id]
  (var found nil)
  (each action actions
    (def table (plist->table action))
    (when (and (nil? found) (= action-id (table :action-id)))
      (set found table)))
  found)

(deftest p19-inspector-ranges-page-large-arrays {:tags [:phase19 :inspector-ranges]}
  (tt/with-test-server [srv]
    (def values (array/new-filled 20 0))
    (for i 0 20 (put values i i))
    ((srv :emacs-rex!) (tuple 'inspect-for-emacs values) :core nil 1901)
    (def page (plist->table ((srv :emacs-rex!) '(inspector-range 5 10) :core nil 1902)))
    (assert= 5 (page :start))
    (assert= 10 (page :end))
    (assert= 20 (page :total))
    (assert= 5 (length (page :parts)))
    (def first (plist->table ((page :parts) 0)))
    (assert= 5 (first :index))
    (assert= "[5]" (first :label))
    (assert= "5" (first :summary))
    (assert= :native (first :support-class))))

(deftest p19-inspector-history-preserves-object-identity {:tags [:phase19 :inspector-history]}
  (tt/with-test-server [srv]
    (def root (plist->table ((srv :emacs-rex!) '(inspect-for-emacs @[10 20 30]) :core nil 1903)))
    (def child (plist->table ((srv :emacs-rex!) '(inspector-nth-part 1) :core nil 1904)))
    (def history ((srv :emacs-rex!) '(inspector-history) :core nil 1905))
    (assert= 2 (length history))
    (def first (plist->table (history 0)))
    (def second (plist->table (history 1)))
    (assert= (root :object-id) (first :object-id))
    (assert= (child :object-id) (second :object-id))
    (assert= true (second :current))
    (assert= (root :object-id) (second :parent-object-id))))

(deftest p19-inspector-actions-support-metadata {:tags [:phase19 :inspector-actions]}
  (tt/with-test-server [srv]
    ((srv :emacs-rex!) '(inspect-for-emacs @{:a 1}) :core nil 1906)
    (def actions ((srv :emacs-rex!) '(inspector-actions) :core nil 1907))
    (assert-true (> (length actions) 0))
    (def copy-action (find-action actions :copy-value))
    (def edit-action (find-action actions :edit-value))
    (assert-not-nil copy-action)
    (assert-not-nil edit-action)
    (assert= :native (copy-action :support-class))
    (assert= :safe (copy-action :safety-level))
    (assert= :unsupported (edit-action :support-class))
    (assert= :unsafe (edit-action :safety-level))
    (assert-true (string? (edit-action :unsupported-reason)))))
