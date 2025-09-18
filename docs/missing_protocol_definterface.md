# Missing SLYNET Protocol definterface Definitions

This document provides `definterface` sketches for the missing SLYNET protocol messages, grouped by their original SLYNK modules.

## Core SLYNK

### slynk.lisp

```janet
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

d(definterface operator-arglist (operator-name package)
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
```

### slynk-completion.lisp

```janet
(definterface flex-completions (string prefix package)
  "Return a list of flex completions for a given prefix and package.")
```

### slynk-gray.lisp

```janet
(definterface io-speed-test (bytes-to-write)
  "Perform an I/O speed test.")

(definterface flow-control-test ()
  "Perform a flow control test.")
```

### xref.lisp

```janet
(definterface xref (type symbol)
  "Return cross-reference information.")

(definterface xrefs (types symbol)
  "Return multiple types of cross-reference information.")
```

### slynk-fancy-inspector.lisp

```janet
(definterface init-inspector (form)
  "Initialize the inspector.")

(definterface inspector-nth-part (n)
  "Return the nth part of the inspected object.")

(definterface inspector-nth-part-or-lose (n)
  "Return the nth part of the inspected object or lose.")

(definterface inspect-nth-part (n)
  "Inspect the nth part of the inspected object.")

(definterface inspector-range (from to)
  "Return a range of parts of the inspected object.")

(definterface inspector-call-nth-action (n)
  "Call the nth action of the inspected object.")

(definterface inspector-pop ()
  "Pop the inspector stack.")

(definterface inspector-next ()
  "Go to the next object in the inspector history.")

(definterface inspector-reinspect ()
  "Reinspect the current object.")

(definterface inspector-toggle-verbose ()
  "Toggle the verbosity of the inspector.")

(definterface inspector-eval (string)
  "Evaluate a string in the context of the inspector.")

(definterface inspector-history ()
  "Return the inspector history.")

(definterface quit-inspector ()
  "Quit the inspector.")

(definterface describe-inspectee ()
  "Describe the inspected object.")

(definterface describe-inspector-part (id)
  "Describe a part of the inspected object.")

p(definterface pprint-inspector-part (id)
  "Pretty-print a part of the inspected object.")

(definterface inspect-in-frame (form frame-number)
  "Inspect a form in a given frame.")

(definterface inspect-current-condition ()
  "Inspect the current condition.")

(definterface inspect-frame-var (frame-number var-id)
  "Inspect a variable in a frame.")

(definterface pprint-frame-var (frame-number var-id)
  "Pretty-print a variable in a frame.")

(definterface describe-frame-var (frame-number var-id)
  "Describe a variable in a frame.")

(definterface eval-for-inspector (form)
  "Evaluate a form for the inspector.")
```

### mop.lisp

```janet
(definterface mop ()
  "Metaobject Protocol features.")
```

## Contrib

### slynk-stickers.lisp

```janet
(definterface compile-for-stickers (form)
  "Compile a form for stickers.")

(definterface kill-stickers (ids)
  "Kill stickers.")

(definterface toggle-break-on-stickers ()
  "Toggle breaking on stickers.")

(definterface total-recordings ()
  "Return the total number of recordings.")

(definterface search-for-recording (query)
  "Search for a recording.")

(definterface fetch (id)
  "Fetch a recording.")

(definterface forget (id)
  "Forget a recording.")

(definterface find-recording-or-lose (id)
  "Find a recording or lose.")

(definterface inspect-sticker (id)
  "Inspect a sticker.")

(definterface inspect-sticker-recording (id)
  "Inspect a sticker recording.")
```

### slynk-package-fu.lisp

```janet
(definterface package= (package1 package2)
  "Check if two packages are equal.")

(definterface export-symbol-for-emacs (symbol-name package-name)
  "Export a symbol for Emacs.")

(definterface import-symbol-for-emacs (symbol-name package-name)
  "Import a symbol for Emacs.")

(definterface unexport-symbol-for-emacs (symbol-name package-name)
  "Unexport a symbol for Emacs.")
```

### sly-autodoc.el (emacs-side)

```janet
(definterface autodoc (form)
  "Autodoc a form.")

(definterface complete-form (form)
  "Complete a form.")
```

### slynk-mrepl.lisp

```janet
(definterface create-mrepl ()
  "Create an MREPL.")

(definterface globally-save-object (symbol value)
  "Globally save an object.")

(definterface eval-for-mrepl (form)
  "Evaluate a form for MREPL.")

(definterface inspect-entry (index)
  "Inspect an MREPL entry.")

(definterface describe-entry (index)
  "Describe an MREPL entry.")

(definterface pprint-entry (index)
  "Pretty-print an MREPL entry.")

(definterface guess-and-set-package (string)
  "Guess and set the package.")

(definterface copy-to-repl (index)
  "Copy an MREPL entry to the REPL.")

(definterface sync-package-and-default-directory ()
  "Sync the package and default directory.")
```

### slynk-trace-dialog.lisp

```janet
(definterface trace-format (trace)
  "Format a trace.")

(definterface trace-or-lose (id)
  "Trace a part or lose.")

(definterface report-partial-tree (id)
  "Report a partial trace tree.")

(definterface report-specs (id)
  "Report trace specs.")

(definterface report-total (id)
  "Report total trace time.")

(definterface clear-trace-tree ()
  "Clear the trace tree.")

(definterface trace-part-or-lose (id)
  "Trace a part or lose.")

(definterface trace-arguments-or-lose (id)
  "Trace arguments or lose.")

(definterface inspect-trace-part (id)
  "Inspect a trace part.")

(definterface pprint-trace-part (id)
  "Pretty-print a trace part.")

(definterface describe-trace-part (id)
  "Describe a trace part.")

(definterface inspect-trace (id)
  "Inspect a trace.")

(definterface trace-location (id)
  "Get the location of a trace.")

(definterface dialog-trace (spec)
  "Trace a function via dialog.")

(definterface dialog-untrace (spec)
  "Untrace a function via dialog.")

d(definterface dialog-toggle-trace (spec)
  "Toggle tracing for a function via dialog.")

(definterface dialog-traced-p (spec)
  "Check if a function is traced via dialog.")

(definterface dialog-untrace-all ()
  "Untrace all functions via dialog.")
```

### slynk-profiler.lisp

```janet
(definterface time-spec (spec)
  "Time a spec.")

(definterface untime-spec (spec)
  "Untime a spec.")

(definterface toggle-timing (spec)
  "Toggle timing for a spec.")

(definterface timed-spec-p (spec)
  "Check if a spec is timed.")

(definterface untime-all ()
  "Untime all specs.")

(definterface report-latest-timings ()
  "Report the latest timings.")

(definterface clear-timing-tree ()
  "Clear the timing tree.")