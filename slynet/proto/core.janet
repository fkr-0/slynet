(definterface simple-completions (prefix package)
  "Return a list of simple completions for a given prefix and package.")

(definterface apropos-list-for-emacs (string &optional external-only case-sensitive package)
  "Return a list of apropos matches for a string.")

(definterface ping (tag)
  "A simple ping to check the connection.")

(definterface connection-info ()
  "Return information about the current connection.")

(definterface toggle-debug-on-slynk-error ()
  "Toggle debugging on SLYNK errors.")

(definterface interactive-eval-region (region)
  "Evaluate a region of code interactively.")

(definterface re-evaluate-defvar (form)
  "Re-evaluate a defvar form.")

(definterface pprint-eval (string)
  "Pretty-print the evaluation of a string.")

(definterface set-package (package-name)
  "Set the current package.")

(definterface ed-in-emacs (what)
  "Edit a file or function in Emacs.")

(definterface inspect-in-emacs (what)
  "Inspect an object in Emacs.")

(definterface value-for-editing (form)
  "Get a value for editing.")

(definterface commit-edited-value (form new-value)
  "Commit an edited value.")

(definterface backtrace (start end)
  "Return a backtrace.")

(definterface debugger-info-for-emacs (start end)
  "Return debugger information for Emacs.")

(definterface invoke-nth-restart (level n)
  "Invoke the nth restart.")

(definterface sly-db-abort ()
  "Abort the current debugger.")

(definterface sly-db-continue ()
  "Continue from the current debugger.")

(definterface throw-to-toplevel ()
  "Throw to the toplevel.")

(definterface invoke-nth-restart-for-emacs (level n)
  "Invoke the nth restart for Emacs.")

(definterface eval-string-in-frame (string frame-number)
  "Evaluate a string in a given frame.")

(definterface pprint-eval-string-in-frame (string frame-number)
  "Pretty-print the evaluation of a string in a given frame.")

(definterface frame-package-name (frame-number)
  "Return the package name of a given frame.")

(definterface frame-locals-and-catch-tags (frame-number)
  "Return the locals and catch tags of a given frame.")

(definterface sly-db-disassemble (frame-number)
  "Disassemble a frame.")

(definterface sly-db-return-from-frame (frame-number form)
  "Return from a frame.")

(definterface sly-db-break (function-name)
  "Set a breakpoint on a function.")

(definterface sly-db-step (frame-number)
  "Step the debugger.")

(definterface sly-db-next (frame-number)
  "Step to the next form in the debugger.")

(definterface sly-db-out (frame-number)
  "Step out of the current form in the debugger.")

(definterface toggle-break-on-signals (condition)
  "Toggle breaking on signals.")

(definterface sdlb-print-condition ()
  "Print the current condition in the debugger.")

(definterface compile-file-for-emacs (filename load-p &rest options)
  "Compile a file for Emacs.")

(definterface compile-string-for-emacs (string buffer position filename policy)
  "Compile a string for Emacs.")

(definterface compile-multiple-strings-for-emacs (strings policy)
  "Compile multiple strings for Emacs.")

(definterface compile-file-if-needed (filename load-p)
  "Compile a file if it is needed.")

(definterface load-file (filename)
  "Load a file.")

(definterface slynk-require (modules)
  "Require a list of SLYNK modules.")

(definterface slynk-add-load-paths (paths)
  "Add paths to the load path.")

(definterface slynk-macroexpand-1 (form)
  "Macroexpand a form once.")

(definterface slynk-macroexpand (form)
  "Macroexpand a form.")

(definterface slynk-macroexpand-all (form)
  "Macroexpand a form completely.")

(definterface slynk-compiler-macroexpand-1 (form)
  "Compiler-macroexpand a form once.")

(definterface slynk-compiler-macroexpand (form)
  "Compiler-macroexpand a form.")

(definterface slynk-expand-1 (form)
  "Expand a form once.")

(definterface slynk-expand (form)
  "Expand a form.")

(definterface slynk-format-string-expand (format-string)
  "Expand a format string.")

(definterface disassemble-form (form)
  "Disassemble a form.")

d (definterface operator-arglist (operator-name package)
    "Return the arglist of an operator.")

(definterface describe-function (function-name)
  "Describe a function.")

(definterface describe-definition-for-emacs (name type)
  "Describe a definition for Emacs.")

(definterface documentation-symbol (symbol-name)
  "Return the documentation for a symbol.")

(definterface list-all-package-names (&optional nicknames)
  "List all package names.")

(definterface slynk-toggle-trace (spec)
  "Toggle tracing for a function.")

(definterface untrace-all ()
  "Untrace all functions.")

(definterface undefine-function (symbol-name)
  "Undefine a function.")

(definterface remove-method-by-name (name qualifiers specializers)
  "Remove a method by name.")

(definterface generic-method-specs (name)
  "Return the specs of a generic method.")

(definterface unintern-symbol (symbol-name package-name)
  "Unintern a symbol.")

(definterface slynk-delete-package (package-name)
  "Delete a package.")

(definterface find-definition-for-thing (thing)
  "Find the definition for a thing.")

(definterface find-source-location-for-emacs (thing)
  "Find the source location for a thing for Emacs.")

(definterface find-definitions-for-emacs (name)
  "Find definitions for a name for Emacs.")

(definterface list-threads ()
  "List all threads.")

(definterface quit-thread-browser ()
  "Quit the thread browser.")

(definterface debug-nth-thread (n)
  "Debug the nth thread.")

(definterface kill-nth-thread (n)
  "Kill the nth thread.")

(definterface start-slynk-server-in-thread (thread-id port-file)
  "Start a SLYNK server in a thread.")

(definterface update-indentation-information (info)
  "Update indentation information.")
