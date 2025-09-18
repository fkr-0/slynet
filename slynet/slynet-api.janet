# # ------------------------------------------------------------------
# #  SLYNET – core macro helpers
# #
# #  • quasi-quote  :  ~
# #  • unquote      :  ,
# #  • splice       :  ;          ; ← list-splice, only valid in [ ... ]
# # ------------------------------------------------------------------

# ### Registry --------------------------------------------------------

# (def interfaces-registry @{})   # for reflection / tooling

# ### slynet-defclass -------------------------------------------------
# # (slynet-defclass 'Backend)  ⇒  Backend = :Backend

# (defmacro slynet-defclass [sym]
#   ~(def ,sym ,(keyword sym)))    # convert symbol → keyword constant

# ### slynet-definterface --------------------------------------------
# # Registers the interface and builds either a user-supplied default
# # body or a stub that raises an error when called.

# (defmacro slynet-definterface
#   [name args doc &opt default-body]
#   (let [stub-body
#         (if default-body
#             default-body
#             ## build a single-form body: (error "...interface stub...")
#             [[error
#               (string "Interface stub '" (string name)
#                       "' called with no implementation.")]])]
#     ~(do
#         (put interfaces-registry ',name
#              {:args ',args :doc ,doc :type :interface})
#         [defn ,name ,args ;stub-body])))

# ### slynet-defimplementation ---------------------------------------

# (defmacro slynet-defimplementation [name args & body]
#   (when (empty? body)
#     (error (string/format "Implementation body for  %j  is empty." name)))
#   ~(do
#       (put interfaces-registry ',name
#            {:args ',args :type :implementation})
#       [defn ,name ,args ;body]))

# ### Optional re-exports --------------------------------------------

# # (export slynet-defclass
# #         slynet-definterface
# #         slynet-defimplementation
# #         interfaces-registry)
