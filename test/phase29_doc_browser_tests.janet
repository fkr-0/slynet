(use ../mini-test)
(import ../test-tools :as tt)

(defn- normalize-key [key]
  (cond
    (keyword? key) key
    (symbol? key) (keyword (string key))
    (string? key) (keyword key)
    :else key))

(defn- plist->table [plist]
  (def out @{})
  (if (or (table? plist) (struct? plist))
    (eachp [k v] plist
      (put out (normalize-key k) v))
    (do
      (var i 0)
      (while (< i (length plist))
        (put out (normalize-key (plist i)) (plist (+ i 1)))
        (set i (+ i 2)))))
  out)

(defn- find-plist-by-key [items key value]
  (var found nil)
  (each item items
    (def table (plist->table item))
    (when (and (nil? found) (= value (table key)))
      (set found table)))
  found)

(deftest p29-autodoc-returns-operator-arglist-doc-and-provenance {:tags [:phase29 :autodoc]}
  (tt/with-test-server [srv]
    (def auto (plist->table ((srv :emacs-rex!) '(autodoc "(connection-info") :core nil 2902)))
    (assert= :ok (auto :status))
    (assert= "connection-info" (auto :operator))
    (assert= :autodoc (auto :frontend-surface))
    (assert= :workaround (auto :support-class))
    (assert= false (auto :cl-autodoc-equivalent))
    (assert-true (string? (auto :arglist)))
    (assert-true (string? (auto :documentation)))
    (assert-true (array? (auto :source-locations)))))

(deftest p29-complete-form-carries-doc-and-source-metadata {:tags [:phase29 :completion]}
  (tt/with-test-server [srv]
    (def payload (plist->table ((srv :emacs-rex!) '(complete-form "(con") :core nil 2903)))
    (assert= :ok (payload :status))
    (assert= "con" (payload :prefix))
    (assert= :completion (payload :frontend-surface))
    (assert= :workaround (payload :support-class))
    (assert= false (payload :cl-complete-form-equivalent))
    (assert-true (array? (payload :candidates)))
    (def candidate (find-plist-by-key (payload :candidates) :name "connection-info"))
    (assert-not-nil candidate)
    (assert-true (string? (candidate :doc-summary)))
    (assert= :slynet-source-index-v2 (candidate :source-index))
    (assert-true (string? (candidate :file)))))
