# SLYNK Symbol Completion for Janet
# Translated from slynk-completion.lisp

# Import required modules
(import ./backend)

# Simple completion
(defn prefix-match-p [prefix string]
  "Return true if PREFIX is a prefix of STRING."
  (and (>= (length string) (length prefix))
       (= (string/slice string 0 (length prefix)) prefix)))

(defn format-completion-set [strings _internal? _package-name]
  "Format a set of completion strings."
  (array/slice (sorted strings) 0))


(defn all-simple-completions [prefix package]
  "Return all symbols that match PREFIX in PACKAGE."
  (default prefix "")
  (var result @[])
  (var seen @{})
  # First try matching bindings in the current environment
  (var env (fiber/getenv (fiber/current)))
  (while (table? env)
    (eachp [k _] env
      (let [sym-name (string k)]
        (when (and (prefix-match-p prefix sym-name)
                   (not (get seen sym-name)))
          (put seen sym-name true)
          (array/push result sym-name))))
    (set env (table/getproto env)))

  # Format and return results
  (format-completion-set result false package))

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
      [@[] prefix]
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
  (default pattern "")
  (let [result @[]
        seen @{}]
    (var env (fiber/getenv (fiber/current)))
    (while (table? env)
      (eachp [k _] env
        (let [sym-name (string k)]
          (when (and (not (get seen sym-name))
                     (flex-match-p pattern sym-name))
            (put seen sym-name true)
            (array/push result @[sym-name [0 (length sym-name)]]))))
      (set env (table/getproto env)))
    (sorted result)))


# Flex matching completion

(defn flex-completions [pattern package]
  "Return flex-matched completions for PATTERN in PACKAGE."
  # This is a more sophisticated completion mechanism that allows for
  # non-contiguous matches, e.g. "mv" matching "move-to"
  (let [result (find-flex-matches pattern package)]
    (if (empty? result)
      [@[] pattern]
      (let [completions (map first result)
            common (longest-common-prefix completions)]
        [result common]))))


# Export public API
(def export-api
  @{:simple-completions simple-completions
    :flex-completions flex-completions
    :format-completion-set format-completion-set})
