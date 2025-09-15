# == slynet/slynk_janet/gray.janet ==
# SLYNK Gray Stream Support for Janet
# Translated from slynk-gray.lisp — provides stream handling for redirected I/O

(import ./backend :as b)
(import ./primitives :as prim)
## Light helper import to parse forms for MREPL helpers
(import ./rpc :as rpc)

(def sly-output-buffer-size 4096)

(defn sly-output-stream [output-fn]
  @{:type :sly-output-stream
    :output-fn output-fn
    :buffer @""
    :column 0
    :lock (prim/make-lock "sly-output-stream")
    :flush-scheduled false})

(defn sly-input-stream [input-fn]
  @{:type :sly-input-stream
    :input-fn input-fn
    :buffer @""
    :position 0
    :lock (prim/make-lock "sly-input-stream")})

# --- Output ---
(defn flush-stream [stream]
  (when (= (stream :type) :sly-output-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (when (> (length (stream :buffer)) 0)
                        ((stream :output-fn) (stream :buffer))
                        (set (stream :buffer) @"")
                        (set (stream :flush-scheduled) false))))))

(defn maybe-schedule-flush [stream]
  (when (and (= (stream :type) :sly-output-stream)
             (> (length (stream :buffer)) sly-output-buffer-size)
             (not (stream :flush-scheduled)))
    (set (stream :flush-scheduled) true)
    (flush-stream stream)))


(defn stream-finish-output [stream]
  (when (= (stream :type) :sly-output-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (flush-stream stream)))
    nil))


# --- Thunk form (works without any extra macro) ---
(defn find-last [newline s]
  (let [pos (string/find-all s newline)]
    (if pos (last pos) nil)))


(defn stream-write-char [stream ch]
  (when (= (stream :type) :sly-output-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (let [buf (stream :buffer)]
                        (buffer/push-byte buf (string/bytes ch 0))
                        (if (= ch "\n") (set (stream :column) 0) (++ (stream :column)))
                        (maybe-schedule-flush stream))))
    ch))

(defn stream-write-string [stream s &opt start end]
  (when (= (stream :type) :sly-output-stream)
    (default start 0)
    (default end (length s))
    (prim/with-lock (stream :lock)
                    (fn []
                      (let [buf (stream :buffer)
                            sub (string/slice s start end)]
                        (buffer/push-string buf sub)
                        (def last-nl (last (string/find-all "\n" sub)))
                        (if last-nl
                          (set (stream :column) (- (length sub) last-nl 1))
                          (+= (stream :column) (length sub)))
                        (maybe-schedule-flush stream))))
    s))

(defn stream-read-char [stream]
  (when (= (stream :type) :sly-input-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (let [buf (stream :buffer)
                            pos (stream :position)]
                        (if (< pos (length buf))
                          (do (def ch (string/slice buf pos (+ pos 1)))
                            (++ (stream :position))
                            ch)
                          (do
                            (def new ((stream :input-fn)))
                            (if (= new "")
                              :eof
                              (do
                                (set (stream :buffer) new)
                                (set (stream :position) 1)
                                (string/slice new 0 1))))))))))

(defn stream-unread-char [stream _ch]
  (when (= (stream :type) :sly-input-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (if (<= (stream :position) 0)
                        (error "Cannot unread at start of stream")
                        (-- (stream :position)))))))

(defn stream-line-column [stream]
  (when (= (stream :type) :sly-output-stream)
    (prim/with-lock (stream :lock)
                    (fn []
                      (stream :column)))))

# --- Redirection helper ---

(defmacro with-sly-output-stream [stream & body]
  ~(let [o (dyn :out)
         e (dyn :err)]
     (try
       (do (setdyn :out ,stream)
         (setdyn :err ,stream)
         ,;body)
       ([err _]
         (setdyn :out o)
         (setdyn :err e)))))

# --- Convenience helpers used by contrib/mrepl ---

(defn make-mrepl-input-stream
  "Create an input stream bound to an MREPL table.
   Expects MREPL to optionally provide a :read-input function that
   returns the next chunk of input as a string (or empty string for EOF).
   Falls back to returning an empty string (EOF) when none is provided."
  [mrepl]
  (sly-input-stream (fn []
                      (try
                        (let [rf (and (table? mrepl) (mrepl :read-input))]
                          (if (function? rf)
                            (do (rf))
                            ""))
                        ([err _]
                          "")))))

(defn make-listener-output-stream
  "Create an output stream for listener output associated with an MREPL.
   Currently routes to local stdout/stderr; integration with Emacs wiring
   can be added by swapping the write function."
  [mrepl which]
  (default which :stdout)
  (sly-output-stream (fn [s]
                       (match which
                         :stderr (eprint s)
                         :stdout (print s)
                         (print s)))))

(defn read-forms-from-string
  "Parse STRING into a sequence (array) of Janet forms using the RPC parser."
  [s]
  (try
    (or (rpc/parse-string s) @[])
    ([err _]
      @[])))

# --- Register with backend (no import loop since backend never imports us) ---

(b/register-implementation "make-output-stream" (fn [write-string]
                                                  (sly-output-stream write-string)))

(b/register-implementation "make-input-stream" (fn [read-string]
                                                 (sly-input-stream read-string)))

(b/register-implementation "stream-flush-output" (fn [stream]
                                                   (stream-finish-output stream)))

(b/register-implementation "stream-line-column" (fn [stream]
                                                  (stream-line-column stream)))

# Optional local exports (not strictly needed)
(def export-api
  @{:sly-output-stream sly-output-stream
    :sly-input-stream sly-input-stream
    :stream-write-char stream-write-char
    :stream-write-string stream-write-string
    :stream-read-char stream-read-char
    :stream-unread-char stream-unread-char
    :stream-finish-output stream-finish-output
    :with-sly-output-stream with-sly-output-stream
    :make-mrepl-input-stream make-mrepl-input-stream
    :make-listener-output-stream make-listener-output-stream
    :read-forms-from-string read-forms-from-string})
# == end/gray.janet ==
