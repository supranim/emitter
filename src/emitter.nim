# A simple event emitter implementation using Libevent
# for efficient event handling in Nim applications.
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/suprani/emitter

import std/[tables, strutils, sequtils, typeinfo, options]

import pkg/flatty
import pkg/libevent/bindings/event

export tables, typeinfo

type
  RunType* = enum
    ## RunType specifies how an event listener should be executed when
    ## the associated event is emitted.
    Anytime, Once

  Args* = seq[string]
  Callback* = proc(args: Option[Args]) {.nimcall.}
    ## The callback type for event listeners. It takes an optional
    ## sequence of string arguments.

  Listener* = object
    id*: string
      # The event key or pattern that this listener is subscribed to.
    token*: uint64
      # A unique token for this listener, used for unsubscription.
    runCallable*: Callback
      # The callback function that will be called when the event is emitted.
    runType*: RunType
      # Specifies whether the listener should be called every time the event is emitted (Anytime)
      # or only the next time the event is emitted (Once).

  QueuedEmit = object
    # QueuedEmit represents an event that has been emitted
    # but not yet dispatched. It contains the event ID and
    # optional arguments that will be passed to the listeners
    # when the event is dispatched.
    eventId: string
    args: Option[Args]

  EventEmitter* = ref object
    ## The EventEmitter is a simple event handling system that allows
    ## you to register listeners for specific events and emit those
    ## events with optional arguments. It uses Libevent for efficient
    ## event handling and supports both synchronous and asynchronous
    ## event dispatching.
    base*: ptr event_base
      ## The Libevent event base used for managing events and the event loop.
    subscribers: Table[string, seq[Listener]]
      # The subscribers table maps event keys to sequences of listeners.
      # Each listener has an ID, a token for unsubscription,
      # callback, and a run type (anytime or once)
    pending: seq[QueuedEmit]
      # The pending sequence holds events that have been emitted but
      # not yet dispatched
    nextToken: uint64
      # A counter for generating unique tokens for event listeners,
      # used for unsubscription.
    tickEv: ptr event
      # A Libevent event used for scheduling periodic checks to
      # dispatch pending events.
    tickTv: Timeval
      # The interval for the tick event, specifying how often to
      # check for pending events.

  EventEmitterError = object of CatchableError

proc newArg*(arg: string): string = toFlatty(arg)
proc newArg*(arg: int): string = toFlatty(arg)
proc newArg*(arg: float): string = toFlatty(arg)
proc unpackArg*[T](x: string): T = fromFlatty(x, T)

proc dispatchNow(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args]) =
  # Dispatches the event with the given ID and arguments to all
  # registered listeners. This is called by the Libevent tick event
  # to process pending events. It checks for listeners registered for
  # the specific event ID, as well as listeners registered for wildcard
  # patterns that match the event ID (e.g., "user.*" would match "user.login").
  if emitter.subscribers.hasKey(eventId):
    var i = emitter.subscribers[eventId].high
    while i >= 0:
      let listener = emitter.subscribers[eventId][i]
      listener.runCallable(args)
      if listener.runType == Once:
        emitter.subscribers[eventId].delete(i)
      dec i
  else:
    let keys = toSeq(emitter.subscribers.keys)
    for subId in keys:
      if subId.len > 0 and subId[^1] == '*' and eventId.startsWith(subId[0..^2]):
        # This subscriber is a wildcard pattern that matches the event ID
        var i = emitter.subscribers[subId].high
        while i >= 0:
          let listener = emitter.subscribers[subId][i]
          listener.runCallable(args)
          if listener.runType == Once:
            emitter.subscribers[subId].delete(i)
          dec i

proc drainQueue(emitter: var EventEmitter|ptr EventEmitter) =
  # Drains the pending event queue and dispatches all queued events.
  # This is called periodically by the Libevent tick event to ensure
  # that emitted events
  if emitter.pending.len == 0: return
  # Detach current queue, then process detached items.
  let queue = move(emitter.pending)
  emitter.pending = @[]
  for item in queue:
    emitter.dispatchNow(item.eventId, item.args)

proc onTick(fd: cint, events: cshort, arg: pointer) {.cdecl.} =
  # Libevent callback for the tick event. This is called
  # periodically based on the tick interval.
  var emitter = cast[EventEmitter](arg)
  emitter.drainQueue()

proc init*(emitter: var EventEmitter|ptr EventEmitter, intervalMs = 5000) =
  ## Initializes the EventEmitter. This sets up the internal data structures
  ## and starts the Libevent event loop in a separate thread. The `intervalMs`
  ## parameter specifies how often (in milliseconds) the event loop should check
  ## for pending events to dispatch.
  emitter.subscribers = initTable[string, seq[Listener]]()
  emitter.pending = @[]
  emitter.nextToken = 0
  emitter.base = event_base_new()
  if emitter.base.isNil:
    raise newException(EventEmitterError, "event_base_new() failed")

  emitter.tickTv.tv_sec = clong(intervalMs div 1000)
  emitter.tickTv.tv_usec = clong((intervalMs mod 1000) * 1000)

  emitter.tickEv = event_new(
    emitter.base,
    -1, # no file descriptor, this is a timer event
    (EV_TIMEOUT or EV_PERSIST).cushort,
    onTick,
    cast[pointer](emitter)
  )
  if emitter.tickEv.isNil:
    event_base_free(emitter.base)
    raise newException(EventEmitterError, "event_new() failed")

  if event_add(emitter.tickEv, addr emitter.tickTv) != 0:
    event_free(emitter.tickEv)
    event_base_free(emitter.base)
    raise newException(EventEmitterError, "event_add() failed")

proc close*(emitter: var EventEmitter|ptr EventEmitter) =
  ## Closes the EventEmitter and frees associated resources. After calling this
  if emitter.isNil: return
  if not emitter.tickEv.isNil:
    discard event_del(emitter.tickEv)
    event_free(emitter.tickEv)
    emitter.tickEv = nil
  if not emitter.base.isNil:
    event_base_free(emitter.base)
    emitter.base = nil

proc run*(emitter: var EventEmitter|ptr EventEmitter) =
  ## Runs the event loop. This will block until `stop` is called.
  if emitter.isNil or emitter.base.isNil: return
  discard event_base_dispatch(emitter.base)

proc stop*(emitter: var EventEmitter|ptr EventEmitter) =
  ## Stops the event loop. This will cause the `run` procedure to return.
  if emitter.isNil or emitter.base.isNil: return
  discard event_base_loopbreak(emitter.base)

proc registerListener*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback, runType: RunType): uint64 {.discardable.} =
  ## Registers a listener for the specified event key with
  ## the given handler and run type (anytime or once). Returns a token that can be used to
  ## unregister the listener.
  if not emitter.subscribers.hasKey(key):
    emitter.subscribers[key] = @[]
  inc emitter.nextToken
  let tok = emitter.nextToken
  emitter.subscribers[key].add Listener(id: key, token: tok, runCallable: handler, runType: runType)
  result = tok

proc listen*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback): uint64 =
  ## Registers a listener for the specified event key. The handler
  ## will be called every time the event is emitted.
  emitter.registerListener(key, handler, Anytime)

proc listenOnce*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback): uint64 =
  ## Registers a listener for the specified event key. The handler
  ## will be called only the next time the event is emitted, and then it
  ## will be automatically unregistered.
  emitter.registerListener(key, handler, Once)

proc off*(emitter: var EventEmitter|ptr EventEmitter, key: string, token: uint64): bool =
  ## Unregisters a listener for the specified event key and token. Returns true if the
  ## listener was found and removed, false otherwise.
  if not emitter.subscribers.hasKey(key): return false
  var i = emitter.subscribers[key].high
  while i >= 0:
    if emitter.subscribers[key][i].token == token:
      emitter.subscribers[key].delete(i)
      return true
    dec i
  false

proc emit*(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args] = none(Args)) =
  ## Async enqueue: delivered by Libevent tick callback.
  emitter.pending.add QueuedEmit(eventId: eventId, args: args)

proc emitNow*(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args] = none(Args)) =
  ## Immediate sync dispatch (no queue).
  emitter.dispatchNow(eventId, args)
