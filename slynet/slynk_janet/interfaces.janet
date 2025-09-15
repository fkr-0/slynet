# SLYNET Core RPC Interfaces
# This file centralizes all `slynet-definterface` calls for the core backend.

(defn define-core-interfaces [definterface]
  # From backend.janet
  (definterface 'gray-package-name [] "Return a module name that contains the Gray stream symbols.")
  (definterface 'stream-line-column [:stream] "Return the column number at STREAM's position.")
  (definterface 'stream-flush-output [:stream] "Flush output on STREAM.")
  (definterface 'make-output-stream [:write-string] "Return a new character output stream that calls WRITE-STRING.")
  (definterface 'make-input-stream [:read-string] "Return a new character input stream that calls READ-STRING.")
  (definterface 'make-fd-stream [:fd :external-format] "Create a character stream from a file descriptor.")
  (definterface 'getpid [] "Return the process ID of the running Janet instance.")
  (definterface 'default-directory [] "Return the current default pathname-directory.")
  (definterface 'set-default-directory [:directory] "Set the current default pathname-directory.")
  (definterface 'create-repl [:opt :io-input :io-output] "Create a new REPL, optionally with I/O streams.")
  (definterface 'eval-in-context [:form :context] "Evaluate FORM in CONTEXT.")
  (definterface 'call-with-compilation-hooks [:func] "Call FUNC but intercept compiler conditions.")
  (definterface 'compile-string [:string :filename :line :column] "Compile STRING as if it appeared in a file.")
  (definterface 'compile-file [:filename :output-file :load] "Compile FILENAME to OUTPUT-FILE and load if LOAD is true.")
  (definterface 'make-lock [:name] "Create a lock with NAME.")
  (definterface 'with-lock [:lock :thunk] "Invoke (thunk) while holding LOCK.")
  (definterface 'make-thread [:name :function] "Create a new thread with NAME that runs FUNCTION with ARGS.")
  (definterface 'find-source-location [:symbol] "Return the source location of SYMBOL as (path line column) or nil.")
  (definterface 'symbol-info [:sym] "Return detailed info for SYM: type, value, docstring.")
  (definterface 'eval-for-emacs [:string :buffer-package :id] "Evaluate STRING in the context of BUFFER-PACKAGE.")
  (definterface 'system-info [] "Return basic system/environment info for diagnostics.")
  (definterface 'list-modules [] "Return a list of loaded module names.")
  (definterface 'list-directory [:path] "List files and directories at PATH. Returns array of names.")
  (definterface 'file-exists? [:path] "Return true if PATH exists and is a file.")
  (definterface 'directory-exists? [:path] "Return true if PATH exists and is a directory.")
  (definterface 'read-file [:path] "Read the contents of PATH as a string.")
  (definterface 'write-file [:path :string] "Write STRING to PATH. Returns true on success.")
  (definterface 'current-thread-id [] "Return the ID of the current thread.")
  (definterface 'thread-name [:thread] "Return the name of THREAD.")
  (definterface 'interactive-eval [:string] "Evaluate STRING interactively.")
  (definterface 'describe-symbol [:symbol-name] "Return a property list with information about SYMBOL-NAME.")
  (definterface 'arglist [:function-name] "Return the argument list of FUNCTION-NAME.")
  (definterface 'frame-locals [:index] "Return the local variables for the frame at INDEX.")

  # From contrib/slynet-apropos.janet
  (definterface 'slynet-apropos/search-symbols [:string-or-pattern :extern-symbols :case-sensitive :limit] "Search for symbols matching the given string or pattern.")
  (definterface 'slynet-apropos/list-all-symbols [:package-name] "List all symbols in the specified package/module.")
  (definterface 'slynet-apropos/describe-symbol-for-emacs [:symbol] "Return a property list with documentation about a symbol.")

  # From contrib/slynet-indentation.janet
  (definterface 'slynet-indentation/update-indentation-rule [:symbol :spec] "Update the indentation rule for a specific symbol.")
  (definterface 'slynet-indentation/get-indentation-rule [:symbol] "Get the indentation rule for a specific symbol.")
  (definterface 'slynet-indentation/load-default-rules [] "Load the default indentation rules.")

  # From contrib/slynet-arglists.janet
  (definterface 'slynet-arglists/update-arglist [:symbol :new-arglist] "Update the argument list for a function. This can be used by editor extensions to supplement or correct arglist information.")
  (definterface 'slynet-arglists/clear-arglists-cache [] "Clear the arglist cache.")
  (definterface 'slynet-arglists/get-arglist-from-cache [:symbol] "Retrieve the cached arglist for a function, if available.")
  (definterface 'slynet-arglists/show-arglist [:symbol] "Display the arglist in the minibuffer.")
  )

(def export-api @{:define-core-interfaces define-core-interfaces})
