# Supranim's Event Emitter - Subscribe & listen for
# various events within your application.
#
# (c) 2021 Events is released under MIT License
#          Made by Humans from OpenPeep
#          
#          https://github.com/supranim
#          https://supranim.com

import std/[tables, sequtils, macros, typeinfo]
from std/strutils import count, startsWith

# import std/threadpool
# import pkg/malebolgia

export tables, typeinfo

type
  RunType* = enum
    Anytime, Once

  Arg* = ref object
    value*: Any

  Callback* = proc(args: seq[Arg]) {.nimcall.}

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

template newArg*(argValue: auto): untyped =
  ## Create a new Arg object instance based on
  ## ``Any`` value from ``std/typeinfo``
  var
    vany: Any
    val = argValue
  proc initNewArg(v: Any): Arg =
    return Arg(value: v)
  vany = toAny(val)
  initNewArg(vany)


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
  ## You may want to register a listener using the ``*``
  ## as a wildcard for ``key`` parameter. This allows you to
  ## register same listener to multiple events.
  runnableExamples:
    Event.listen("account.update.email") do(args: seq[Arg]):
      echo "Email address has been changed."

    Event.listen("account.*") do(args: seq[Arg]):
      echo "Listening for any events related to `account.`"

  registerListener(emitter, key, handler, Anytime)

template listenOnce*(emitter: var EventEmitter, key: string, handler: Callback) =
  ## Same as ``listen`` proc, the only difference is
  ## that this listener can run only once
  registerListener(emitter, key, handler, Once)

proc runCallback(args: ptr seq[Arg], listen: ptr Listener) =
  {.gcsafe.}:
    listen[].runCallable(@[])

proc emit*(emitter: var EventEmitter, eventId: string, args: seq[Arg] = @[]) =
  ## Call an event by ``id`` and trigger all registered listeners
  ## related to the event. You can pass one or more ``args``
  ## to listener callback using the ``newArg`` procedure.
  runnableExamples:
    Event.emit("account.update.email", newArg("new.address@example.com"), newArg("192.168.1.1"))
  if emitter.subscribers.hasKey(eventId):
    for i, listener in pairs(emitter.subscribers[eventId]):
      let x = args
      # spawn runCallback(x.addr, listener.addr)
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
