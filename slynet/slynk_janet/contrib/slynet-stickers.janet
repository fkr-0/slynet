# slynet/slynk_janet/contrib/slynet-stickers.janet
# Adapted from slynk-stickers.lisp
# Provides code annotation and instrumentation capabilities (stickers)

## (declare-source "slynet-stickers")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

(def version "0.1.0")

# Module state
(def sticker-registry @{}) # Tracks all active stickers
(var next-sticker-id 1) # Unique ID for new stickers
(def sticker-recording @{}) # Records sticker execution results

# Sticker definition
(defstruct Sticker
  id # Unique numeric ID
  form # The instrumented form
  source # Source file and position
  value-fn # Function to extract value
  recording # Record of executions
  active # Whether the sticker is active
)

# RPC Interface definitions are now in slynet/slynk_janet/interfaces.janet

# Implementation
(defn- next-id []
  "Generate a new unique sticker ID."
  (def id next-sticker-id)
  (++ next-sticker-id)
  id)

(defn create-sticker [source-file form position]
  "Create a new sticker on the specified form."
  (def id (next-id))
  (def sticker
    (Sticker
      id
      form
      {:file source-file :position position}
      nil # value-fn will be compiled later
      @[] # empty recording
      true # active by default
))

  # Compile the value extraction function
  # This would need to be implemented based on Janet's eval capabilities
  # and code transformation to add instrumentation

  (put sticker-registry id sticker)
  {:sticker-id id})

(defn delete-sticker [sticker-id]
  "Delete a sticker by its ID."
  (def sticker (get sticker-registry sticker-id))
  (when sticker
    # Remove any instrumentation hooks
    (put sticker-registry sticker-id nil)
    true))

(defn toggle-sticker [sticker-id active]
  "Toggle a sticker's active state."
  (def sticker (get sticker-registry sticker-id))
  (when sticker
    (put sticker :active active)
    active))

(defn clear-stickers-recording []
  "Clear all recording data for stickers."
  (each [id sticker] (pairs sticker-registry)
    (put sticker :recording @[]))
  (table/clear sticker-recording)
  true)

(defn fetch-sticker-recordings [sticker-ids]
  "Fetch the recording data for specified stickers."
  (def result @{})
  (each id sticker-ids
    (def sticker (get sticker-registry id))
    (when sticker
      (put result id (get sticker :recording))))
  result)

(defn list-stickers [&opt source-file]
  "List all stickers, optionally filtered by source file."
  (def result @[])
  (each [id sticker] (pairs sticker-registry)
    (when (or (nil? source-file)
              (= (get-in sticker [:source :file]) source-file))
      (array/push result
                  {:id id
                   :file (get-in sticker [:source :file])
                   :position (get-in sticker [:source :position])
                   :active (get sticker :active)
                   :recordings (length (get sticker :recording))})))
  result)

(defn initialize-module []
  "Initialize the stickers module."
  (print "Initializing SLYNET Stickers module version " version)
  # Setup any necessary hooks for code instrumentation

  true)

(def export-api
  @{:initialize-module initialize-module
    :create-sticker create-sticker
    :delete-sticker delete-sticker
    :toggle-sticker toggle-sticker
    :clear-stickers-recording clear-stickers-recording
    :fetch-sticker-recordings fetch-sticker-recordings
    :list-stickers list-stickers})
