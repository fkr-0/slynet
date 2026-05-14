(use ../mini-test)
(import ../slynet/contrib :as contrib)
(import ../slynet/contrib/slynet-apropos :as apropos)
(import ../slynet/contrib/slynet-arglists :as arglists)

(register-test
  {:name "list-contrib-modules exposes known modules"
   :tags [:contrib]
   :fn (fn []
         (def mods (contrib/list-contrib-modules))
         (assert-true (array? mods))
         (assert-true (some (fn [m] (= m :apropos)) mods))
         (assert-true (some (fn [m] (= m :arglists)) mods)))})

(deftest
  initialize-contrib-returns-status-map
  :tags [:contrib]
  (def results (contrib/initialize-contrib [:apropos :arglists]))
  (assert-true (table? results))
  (assert-true (results :apropos))
  (assert-true (results :arglists))
  (eachp [_ v] results
    (assert= :ok (v :status))))

(register-test
  {:name "apropos module finds core symbols"
   :tags [:contrib]
   :fn (fn []
         (apropos/initialize-module)
         (def matches (apropos/search-symbols "print" true true 5))
         (assert-true (array? matches))
         (assert-true (> (length matches) 0)))})

(register-test
  {:name "arglists module caches overrides"
   :tags [:contrib]
   :fn (fn []
         (arglists/initialize-module)
         (arglists/clear-arglists-cache)
         (arglists/update-arglist 'sample/fn "[x y]")
         (def cached (arglists/get-arglist-from-cache 'sample/fn))
         (assert-true cached)
         (assert-true (string/find cached "[x y]")))})
