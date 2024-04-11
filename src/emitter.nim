# Supranim's Event Emitter - Subscribe & listen for
# various events within your application.
#
# (c) 2024 Events is released under MIT License
#          Made by Humans from OpenPeeps
#          
#          https://github.com/supranim
#          https://supranim.com

import std/[tables, strutils, sequtils, macros, typeinfo]
import pkg/msgpack4nim
# import pkg/malebolgia

export tables, typeinfo

type
  RunType* = enum
    Anytime, Once

  Args* = seq[string]
  Callback* = proc(args: Args) {.nimcall.}

  Listener* = tuple[id: string, runCallable: Callback, runType: RunType]

  EventEmitter = ref object
    ## Main object that holds all events and listeners,
    ## available as a Singleton as ``Event``
    subscribers: Table[string, seq[Listener]]
    # m: Master

  EventEmitterError = object of CatchableError

# when compileOption("threads"):
#   var Event* {.threadvar.}: EventEmitter
# else:
var Event*: EventEmitter

proc init*(e: var EventEmitter) =
  Event = EventEmitter()

proc newArg*(arg: string): string =
  ## Packs a new string `arg` via MsgPack
  result = pack(arg)

proc newArg*(arg: int): string =
  ## Packs a new int `arg` via MsgPack
  result = pack(arg).stringify

proc newArg*(arg: float): string =
  ## Packs a new float `arg` via MsgPack
  result = pack(arg).stringify

proc unpackArg*(x: string): string =
  unpack(x, result)

proc registerListener(emitter: var EventEmitter, key: string, handler: Callback, runType: RunType) =
  ## Main proc for registering listeners to a specific events by ``key``.
  ## TODO allow only lowercase keys, separated by dot, e.g. "user.update.account"
  # if count(listener.id, '*') != 1:
  #     raise newException(EventEmitterError, "A key cannot contain more than one wildcard") # for now
  if not emitter.subscribers.hasKey(key):
    emitter.subscribers[key] = newSeq[Listener]()
  emitter.subscribers[key].add (id: key, runCallable: handler, runType: runType)

proc listen*(emitter: var EventEmitter, key: string, handler: Callback) =
  ## Subscribe to a specific event with a runnable callback.
  ##
  ## Use wildcard `*` to register the same listener
  ## to multiple events
  runnableExamples:
    Event.listen("account.update.email") do(args: Args):
      echo "Email address has been changed."

    Event.listen("account.*") do(args: Args):
      echo "Listening for any events related to `account.`"

  registerListener(emitter, key, handler, Anytime)

template listenOnce*(emitter: var EventEmitter, key: string, handler: Callback) =
  ## Same as `listen` proc, the only difference is
  ## that this listener can run only once
  registerListener(emitter, key, handler, Once)

proc runCallback(args: ptr Args, listen: ptr Listener) =
  {.gcsafe.}:
    listen[].runCallable(args[])

proc emit*(emitter: var EventEmitter, eventId: string, args: Args = @[]) =
  ## Call an event by `id` and trigger all registered listeners
  ## related to the event. You can pass one or more `args`
  ## to listener callback using the `newArg` procedure.
  runnableExamples:
    Event.emit("account.update.email", newArg("new.address@example.com"), newArg("192.168.1.1"))
  if emitter.subscribers.hasKey(eventId):
    for i, listener in pairs(emitter.subscribers[eventId]):
      let x = args
      runCallback(x.addr, listener.addr)
      if likely(listener.runType == Once):
        emitter.subscribers[eventId].delete(i)
  else:
    for subId, event in pairs(emitter.subscribers):
      if likely(subId[^1] == '*'):
        for i, listener in pairs(emitter.subscribers[subId]):
          if startsWith(eventId, subId[0 .. ^2]):
            listener.runCallable(args)
          if likely(listener.runType == Once):
            emitter.subscribers[subId].delete(i)
          else: continue
      else: continue
