# == slynet-tests/tests/deftest_group.janet ==
# A convenience macro for Judge that:
# - defines a per-group custom test type (via `deftest-type`)
# - lets you write (setup ...), (reset ...), (teardown ...) once for the group
# - rewrites any `(deftest "Name" ...)` inside the group into
#   `(deftest: <group-type> "Group / Name" [context] ...)`
# - prefixes test names with the group title for nicer reports
#
# Usage example is shown after the macro.

(import judge)
(defmacro deftest-group
  # Group tests under shared setup/reset/teardown.
  # Signature:
  #   (deftest-group "Group Title"
  #     (setup    [_] ...returns context...)
  #     (reset    [ctx] ...return fresh ctx...)
  #     (teardown [ctx] ...)
  #     (deftest "Test 1" ...body...)
  #     (deftest "Test 2" ...body...))
  #
  # Notes:
  # - (setup) and (teardown) are optional. (reset) is also optional; default reset is identity.
  # - Inside each test, the group context is bound as `context`.
  # - Test names are prefixed as: "<Group Title> / <Test Name>".
  [group-title & body-forms]
  (when (not (string? group-title))
    (error "deftest-group: first argument must be a string group title."))

  (var setup-form nil)
  (var reset-form nil)
  (var teardown-form nil)
  (var rewritten-tests @[])
  (var passthrough-forms @[]) # any non-(setup/reset/teardown/deftest) forms; kept & emitted

  # Helper: prefix test names consistently.
  (defn prefix-name [n]
    (if (string? n) (string group-title " / " n) (string group-title " / " (n :to-string))))

  # Parse group body
  (each f body-forms
    (if (and (tuple? f) (symbol? (first f)))
      (case (first f)
        'setup (set setup-form (slice f 2)) # (setup [_] <...>) -> keep body (after params)
        'reset (set reset-form (slice f 2)) # (reset [ctx] <...>)
        'teardown (set teardown-form (slice f 2)) # (teardown [ctx] <...>)

        judge/deftest
        (do
          # (deftest "name" ...body...)
          (def name (get f 1))
          (def body (slice f 2))
          (array/push rewritten-tests
                      ~(judge/deftest: ,(gensym) ,(prefix-name name) [context]
                                       ,;body)))

        'deftest: # If someone already wrote a typed test, force it onto this group's type.
        (do
          # Expect shape: (deftest: <type> "name" [params] body...)
          (def name (get f 2))
          (def body (slice f 4))
          (array/push rewritten-tests
                      ~(judge/deftest: ,(gensym) ,(prefix-name name) [context]
                                       ,;body)))

        # anything else -> keep order and emit verbatim (definitions, helpers, etc.)
        (array/push passthrough-forms f))
      # Non-tuples (rare) -> keep verbatim
      (array/push passthrough-forms f)))

  # Sensible defaults
  (def setup-fn
    (if setup-form
      ~(fn [] ,;setup-form)
      ~(fn [] nil))) # default context is nil

  (def reset-fn
    (if reset-form
      ~(fn [context] ,;reset-form)
      ~(fn [context] context))) # default reset = identity

  (def teardown-fn
    (if teardown-form
      ~(fn [context] ,;teardown-form)
      ~(fn [context] nil))) # default teardown does nothing

  # Create a *stable-ish* type symbol from the title for nicer reporting/tools.
  # Fallback to gensym if we can't sanitize well.
  (def sanitized (string/trim
                   (string/replace (string/ascii-lower group-title) "[^\\w]+" "_")
                   "_"))
  (def type-sym (cond
                  (empty? sanitized) (gensym)
                  (or (= sanitized "_") (= sanitized "__")) (gensym)
                  :else (symbol (string "group_" sanitized))))

  # Rebind placeholder type symbols inside rewritten tests to the real `type-sym`.
  (def patched-tests
    (map (fn [t]
           (let [ts (tuple t)]
             ~(judge/deftest: ,type-sym ,(ts 2) ,(ts 3) ,@[slice ts 4])))
         rewritten-tests))

  # Final expansion:
  (do
    # 1) define the per-group type
    ~(judge/deftest-type ,type-sym
                         :setup ,setup-fn
                         :reset ,reset-fn
                         :teardown ,teardown-fn)

    # 2) keep any pass-through group-local definitions
    passthrough-forms

    # 3) define the tests using the group type
    patched-tests))
# (defmacro deftest-group
#   "Group tests under shared setup/reset/teardown.
#    Signature:
#      (deftest-group \"Group Title\"
#        (setup    [_] ...returns context...)
#        (reset    [ctx] ...return fresh ctx...)
#        (teardown [ctx] ...)
#        (deftest \"Test 1\" ...body...)
#        (deftest \"Test 2\" ...body...))

#    Notes:
#    - (setup) and (teardown) are optional. (reset) is also optional; default reset is identity.
#    - Inside each test, the group context is bound as `context`.
#    - Test names are prefixed as: \"<Group Title> / <Test Name>\"."
#   [group-title & body-forms]
#   (when (not (string? group-title))
#     (error "deftest-group: first argument must be a string group title."))

#   (var setup-form nil)
#   (var reset-form nil)
#   (var teardown-form nil)
#   (var rewritten-tests @[])
#   (var passthrough-forms @[]) # any non-(setup/reset/teardown/deftest) forms; kept & emitted

#   # Helper: prefix test names consistently.
#   (defn prefix-name [n]
#     (if (string? n) (string group-title " / " n) (string group-title " / " (n :to-string))))

#   # Parse group body
#   (each f body-forms
#     (if (and (tuple? f) (symbol? (first f)))
#       (case (first f)
#         setup (set setup-form (slice f 2)) # (setup [_] <...>) -> keep body (after params)
#         reset (set reset-form (slice f 2)) # (reset [ctx] <...>)
#         teardown (set teardown-form (slice f 2)) # (teardown [ctx] <...>)

#         deftest
#         (do
#           # (deftest "name" ...body...)
#           (def name (get f 1))
#           (def body (slice f 2))
#           (array/push rewritten-tests
#                       ~(deftest: ,(gensym '____placeholder____) ,(prefix-name name) [context]
#                          ,@body)))

#         'deftest: # If someone already wrote a typed test, force it onto this group's type.
#         (do
#           # Expect shape: (deftest: <type> "name" [params] body...)
#           (def name (get f 2))
#           (def maybe-params (get f 3))
#           (def body (slice f 4))
#           (array/push rewritten-tests
#                       ~(deftest: ,(gensym '____placeholder____) ,(prefix-name name) [context]
#                          ,@body)))

#         # anything else -> keep order and emit verbatim (definitions, helpers, etc.)
#         (array/push passthrough-forms f))
#       # Non-tuples (rare) -> keep verbatim
#       (array/push passthrough-forms f)))

#   # Sensible defaults
#   (def setup-fn
#     (if setup-form
#       ~(fn [] ,@setup-form)
#       ~(fn [] nil))) # default context is nil

#   (def reset-fn
#     (if reset-form
#       ~(fn [context] ,@reset-form)
#       ~(fn [context] context))) # default reset = identity

#   (def teardown-fn
#     (if teardown-form
#       ~(fn [context] ,@teardown-form)
#       ~(fn [context] nil))) # default teardown does nothing

#   # Create a *stable-ish* type symbol from the title for nicer reporting/tools.
#   # Fallback to gensym if we can't sanitize well.
#   (def sanitized (string/trim
#                    (string/replace (string/lower group-title) "[^\\w]+" "_")
#                    "_"))
#   (def type-sym (cond
#                   (empty? sanitized) (gensym "group_type_")
#                   (or (= sanitized "_") (= sanitized "__")) (gensym "group_type_")
#                   :else (symbol (string "group_" sanitized))))

#   # Rebind placeholder type symbols inside rewritten tests to the real `type-sym`.
#   (def patched-tests
#     (map (fn [t]
#            # t is ~(deftest: ____placeholder____ "name" [context] ...)
#            (let [tt (tuple t)]
#              (tuple
#                'deftest:
#                type-sym
#                (tt 2) # name
#                (tt 3) # [context]
#                ;body...
#                ;`slice` on tuples returns a new tuple from index:
#                ;indices: 0:deftest: ,1:placeholder ,2:name ,3: [context] ,4..:body
#                ;so we splice back body entries:
#                ;but we are constructing a tuple ;easier: rebuild via quasiquote:)))
#          rewritten-tests))

#   # The above `map` is a bit clunky to patch tuples; easier: re-emit via a fresh QQ:
#   (def patched-tests
#     (map (fn [t]
#            (let [ts (tuple t)]
#              ~(deftest: ,type-sym ,(ts 2) ,(ts 3) ,@[slice ts 4])))
#          rewritten-tests))

#   # Final expansion:
#   ~(do
#      # 1) define the per-group type
#      (deftest-type ,type-sym
#        :setup ,setup-fn
#        :reset ,reset-fn
#        :teardown ,teardown-fn)

#      # 2) keep any pass-through group-local definitions
#      ,@passthrough-forms

#      # 3) define the tests using the group type
#      ,@patched-tests))
# == end/deftest_group.janet ==

(def export-api
  @{:deftest-group deftest-group})
