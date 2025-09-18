# == slynet/macros.janet ==
# Safer defdyn replacement that won’t treat table value as metadata.

# Side doc registry (dynamic, optional)
(def- slynet-binding-docs-key :slynet-binding-docs)

(defn- record-doc! [sym doc]
  (when doc
    (var docs (or (dyn slynet-binding-docs-key) @{}))
    (put docs sym doc)
    (setdyn slynet-binding-docs-key docs)))

(defmacro defdyn! [name value &opt doc]
  ~(do
     # Force value position to be a non-table form so core 'def' won't parse metadata
     (def ,name (do ,value))
     ,(if doc
          ~(record-doc! ',name ,doc)
          nil)
     ,name))
# == end/macros.janet ==

# Export public API
(def export-api
  @{:record-doc! record-doc!
    :defdyn! defdyn!})
