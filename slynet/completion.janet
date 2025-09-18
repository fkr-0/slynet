# SLYNK Symbol Completion for Janet
# Translated from slynk-completion.lisp

# Import required modules
(import ./backend)

# Simple completion
(defn prefix-match-p [prefix string]
  "Return true if PREFIX is a prefix of STRING."
  (and (>= (length string) (length prefix))
       (= (string/slice string 0 (length prefix)) prefix)))

(defn format-completion-set [strings internal? package-name]
  "Format a set of completion strings."
  strings)
(defn all-simple-completions [prefix package]
  "Return all symbols that match PREFIX in PACKAGE."
  (var result @[])
  # First try matching bindings in the current environment
  (var env (fiber/getenv (fiber/current)))
  (while env
    (eachp [k v] env
      (var sym-name (string k))
      (when (prefix-match-p prefix sym-name)
        (array/push result sym-name)))
    (set env (table/getproto env)))

  # Also match imported modules and their bindings
  (eachp [mod-name _] module/paths
    (var mod-str (string mod-name))
    (when (prefix-match-p prefix mod-str)
      (array/push result mod-str)))

  # Format and return results
  (format-completion-set (sort result) false package))

(defn longest-common-prefix [strings]
  "Return the longest common prefix of STRINGS."
  (if (empty? strings)
    ""
    (let [first-str (first strings)
          len (length first-str)]
      (var common-len len)
      (each str (array/slice strings 1)
        (var i 0)
        (while (and (< i common-len)
                   (< i (length str))
                   (= (string/slice first-str i (+ i 1))
                      (string/slice str i (+ i 1))))
          (++ i))
        (set common-len i))
      (string/slice first-str 0 common-len))))
(defn simple-completions [prefix package]
  "Return completions for PREFIX in PACKAGE as [COMPLETIONS COMMON-PREFIX]."
  (let [symbols (all-simple-completions prefix package)]
    (if (empty? symbols)
      [[] prefix]
      (let [common (longest-common-prefix symbols)]
        [symbols common]))))

(defn flex-match-p [pattern string]
  "Return true if PATTERN flex-matches STRING."
  # Simple implementation for now - just checks if all chars are present in order
  (var i 0)
  (var j 0)
  (while (and (< i (length pattern))
             (< j (length string)))
    (if (= (string/slice pattern i (+ i 1))
           (string/slice string j (+ j 1)))
      (do (++ i) (++ j))
      (++ j)))
  (= i (length pattern)))

(defn find-flex-matches [pattern package]
  "Find symbols matching PATTERN with a flex-matching approach."
  # Simple implementation for now
  (let [result @[]]
    # Implement flex matching logic here
    # This could involve a more sophisticated substring matching algorithm
    (var env (fiber/getenv (fiber/current)))
    (while env
      (eachp [k v] env
        (let [sym-name (string k)]
          (when (flex-match-p pattern sym-name)
            (array/push result [sym-name [0 (length sym-name)]]))))
      (set env (table/getproto env)))
    result))




# Flex matching completion

(defn flex-completions [pattern package]
  "Return flex-matched completions for PATTERN in PACKAGE."
  # This is a more sophisticated completion mechanism that allows for
  # non-contiguous matches, e.g. "mv" matching "move-to"
  (let [result (find-flex-matches pattern package)]
    (if (empty? result)
      [[] pattern]
      (let [completions (map first result)
            common (longest-common-prefix completions)]
        [result common]))))





# Export public API
(def export-api
  @{:simple-completions simple-completions
    :flex-completions flex-completions
    :format-completion-set format-completion-set})
