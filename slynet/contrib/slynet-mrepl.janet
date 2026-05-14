# SLYNET MREPL Support
#
# This module provides a lightweight MREPL implementation adequate for
# exercising the Janet backend and driving an interactive CLI client.
# It intentionally focuses on the core behaviours: creating a channel,
# evaluating strings of Janet code, tracking history, and pushing
# prompt/value notifications back to the client.

(import ../backend :as backend)
(import ../infrastructure :as inf)
(import ../rpc :as rpc)
(import ../slynk :as slynk)

# -----------------------------------------------------------------------------
# Mutable module state
# -----------------------------------------------------------------------------
(var *saved-objects* @[])
(var *mrepls* @{})
(var *last-mrepl* nil)

# -----------------------------------------------------------------------------
# Small helpers
# -----------------------------------------------------------------------------
(defn- short-repr [value]
  (match (type value)
    :nil "nil"
    :boolean (if value "true" "false")
    :number (string value)
    :string value
    :symbol (string value)
    :keyword (string value)
    _ nil))

(defn- format-value [entry-index value]
  [(slynk/slynk-pprint-for-emacs value)
   entry-index
   (short-repr value)])

(defn- send-channel [mrepl payload]
  (slynk/send-to-remote-channel (mrepl :remote-id)
                                (mrepl :channel-id)
                                payload))

(defn- history-entry [mrepl entry-index]
  (let [history (mrepl :history)]
    (if (and (int? entry-index)
             (>= entry-index 0)
             (< entry-index (length history)))
      (history entry-index)
      (error (string "MREPL history index out of range: " entry-index)))))

(defn- record-history! [mrepl values]
  (array/push (mrepl :history) values)
  (dec (length (mrepl :history))))

(defn- send-prompt! [mrepl &opt condition]
  (let [pkg (or slynk/*package* @{:name "core" :nick "core"})
        payload @[ (pkg :name)
                   (pkg :nick)
                   (length (mrepl :pending-errors))
                   (length (mrepl :history))]]
    (when condition
      (array/push payload condition))
    (send-channel mrepl (array/concat [:prompt] payload))
    (put mrepl :mode :eval)
    true))

(defn- eval-string [code]
  (match (backend/interactive-eval code)
    [:ok value] {:status :ok :values @[value]}
    [:abort reason] {:status :abort :reason (string reason)}
    other {:status :ok :values @[other]}))

(defn- handle-eval! [mrepl code]
  (put mrepl :mode :busy)
  (set *last-mrepl* mrepl)
  (let [result (eval-string code)]
    (cond
      (= :ok (result :status))
      (let [values (result :values)
            entry-index (record-history! mrepl values)
            formatted (map (fn [value] (format-value entry-index value)) values)]
        (slynk/flush-listener-streams mrepl)
        (send-channel mrepl [:write-values formatted]))

      (= :abort (result :status))
      (do
        (slynk/flush-listener-streams mrepl)
        (send-channel mrepl [:evaluation-aborted (result :reason)]))))
  (send-prompt! mrepl)
  true)

(defn- clear-history! [mrepl]
  (set (mrepl :history) @[])
  (send-channel mrepl [:clear-history])
  (send-prompt! mrepl)
  true)

(defn- teardown! [mrepl]
  (send-channel mrepl [:server-side-repl-close])
  (slynk/send-channel-close (mrepl :remote-id) (mrepl :channel-id))
  (rpc/close-channel (mrepl :channel-id))
  (put *mrepls* (mrepl :channel-id) nil)
  (when (= *last-mrepl* mrepl)
    (set *last-mrepl* nil))
  (put mrepl :mode :teardown)
  true)

(defn- attach-channel-handlers [mrepl]
  (put mrepl :mrepl-channel-process (fn [code] (handle-eval! mrepl code)))
  (put mrepl :mrepl-channel-clear-history (fn [] (clear-history! mrepl)))
  (put mrepl :mrepl-channel-teardown (fn [] (teardown! mrepl)))
  (put mrepl :mrepl-channel-inspect-object
       (fn [entry-index value-index]
         (let [entry (history-entry mrepl entry-index)
               values (if (array? entry) entry @[entry])
               idx (if (and (int? value-index)
                            (>= value-index 0)
                            (< value-index (length values)))
                     value-index
                     0)
               value (values idx)]
           (send-channel mrepl [:describe-entry
                                 (slynk/slynk-pprint-for-emacs value)])
           true)))
  mrepl)

(defn- register-mrepl! [mrepl]
  (let [channel-id (rpc/register-channel-object mrepl)]
    (put mrepl :channel-id channel-id)
    (put *mrepls* channel-id mrepl)
    (set *last-mrepl* mrepl)
    channel-id))

# -----------------------------------------------------------------------------
# Public (interface) functions
# -----------------------------------------------------------------------------
(defn create-mrepl [&opt remote-id]
  (default remote-id :current)
  (let [mrepl (attach-channel-handlers
               @{:remote-id remote-id
                 :history @[]
                 :pending-errors @[]
                 :mode :eval
                 :thread-id (fiber/current)})
        channel-id (register-mrepl! mrepl)]
    (send-channel mrepl
                  [:write-string
                   (string "; SLYNET mrepl ready (channel " channel-id ")\n")])
    (send-prompt! mrepl)
    [channel-id (mrepl :thread-id)]))

(defn globally-save-object [_slot value]
  (array/push *saved-objects* value)
  (dec (length *saved-objects*)))

(defn eval-for-mrepl [form]
  (backend/interactive-eval (string form)))

(defn inspect-entry [entry-index]
  (let [mrepl (or *last-mrepl*
                  (error "inspect-entry: no active MREPL"))
        entry (history-entry mrepl entry-index)]
    @{:entry entry-index
      :values entry
      :count (length entry)}))

(defn describe-entry [entry-index]
  (let [mrepl (or *last-mrepl*
                  (error "describe-entry: no active MREPL"))
        entry (history-entry mrepl entry-index)]
    (slynk/slynk-pprint-for-emacs entry)))

(defn pprint-entry [entry-index]
  (describe-entry entry-index))

(defn guess-and-set-package [pkg-name]
  (let [pkg (slynk/set-package pkg-name)]
    (when *last-mrepl*
      (send-prompt! *last-mrepl*))
    (or (pkg :name) pkg-name)))

(defn copy-to-repl [saved-index]
  (if (and (int? saved-index)
           (>= saved-index 0)
           (< saved-index (length *saved-objects*)))
    (get *saved-objects* saved-index)
    (error (string "copy-to-repl: invalid saved object index " saved-index))))

(defn sync-package-and-default-directory []
  @{:package (or (slynk/*package* :name) "core")
    :directory (os/cwd)})

# -----------------------------------------------------------------------------
# Module initialisation & interface registration
# -----------------------------------------------------------------------------
(defn initialize-module []
  (set *saved-objects* @[])
  (set *mrepls* @{})
  (set *last-mrepl* nil)
  true)

# Register implementations so they surface in the interface registry.
(inf/defimpl 'create-mrepl create-mrepl)
(inf/defimpl 'globally-save-object globally-save-object)
(inf/defimpl 'eval-for-mrepl eval-for-mrepl)
(inf/defimpl 'inspect-entry inspect-entry)
(inf/defimpl 'describe-entry describe-entry)
(inf/defimpl 'pprint-entry pprint-entry)
(inf/defimpl 'guess-and-set-package guess-and-set-package)
(inf/defimpl 'copy-to-repl copy-to-repl)
(inf/defimpl 'sync-package-and-default-directory sync-package-and-default-directory)

(def export-api
  @{:initialize-module initialize-module
    :create-mrepl create-mrepl
    :globally-save-object globally-save-object
    :eval-for-mrepl eval-for-mrepl
    :inspect-entry inspect-entry
    :describe-entry describe-entry
    :pprint-entry pprint-entry
    :guess-and-set-package guess-and-set-package
    :copy-to-repl copy-to-repl
    :sync-package-and-default-directory sync-package-and-default-directory})
