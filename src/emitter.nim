# Supranim's Event Emitter - Subscribe & listen for
# various events within your application.
# 
# This package is part of Supranim Hyper Framework.
# 
# Supranim is a simple MVC-style web framework for building
# fast web applications, REST API microservices and other cool things.
#
# (c) 2021 Events is released under MIT License
#          Made by Humans from OpenPeep
#          
#          https://github.com/supranim
#          https://supranim.com

import std/[tables, macros, typeinfo]
from std/strutils import count, startsWith

export tables, typeinfo

type
    RunType* = enum
        Anytime, Once

    Arg* = ref object
        value*: Any

    Callback* = proc(args: varargs[Arg] = @[]) {.nimcall.}

    Listener* = tuple[id: string, runCallable: Callback, runType: RunType]

    EventEmitter = object
        ## Main object that holds all events and listeners,
        ## available as a Singleton as ``Event``
        subscribers: Table[string, seq[Listener]]

    EventEmitterError = object of CatchableError

when compileOption("threads"):
    var Event* {.threadvar.}: EventEmitter
else:
    var Event*: EventEmitter

proc init*[E: EventEmitter](e: var E) =
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

proc registerListener[E: EventEmitter](emitter: var E, key: string, handler: Callback, runType: RunType) =
    ## Main proc for registering listeners to a specific events by ``key``.
    ## TODO allow only lowercase keys, separated by dot, e.g. "user.update.account"
    # if count(listener.id, '*') != 1:
    #     raise newException(EventEmitterError, "A key cannot contain more than one wildcard") # for now
    if not emitter.subscribers.hasKey(key):
        emitter.subscribers[key] = newSeq[Listener]()
    emitter.subscribers[key].add (id: key, runCallable: handler, runType: runType)

template listen*[E: EventEmitter](emitter: var E, key: string, handler: Callback): untyped =
    ## Subscribe to a specific event with a runnable callback.
    ##
    ## You may want to register a listener using the ``*``
    ## as a wildcard for ``key`` parameter. This allows you to
    ## register same listener to multiple events.
    runnableExamples:
        Event.listen("account.update.email") do(args: varargs[Arg]):
            echo "Email address has been changed."

        Event.listen("account.*") do(args: varargs[Arg]):
            echo "Listening for any events related to `account.`"

    registerListener(emitter, key, handler, Anytime)

template listenOnce*[E: EventEmitter](emitter: var E, key: string, handler: Callback): untyped =
    ## Same as ``listen`` proc, the only difference is
    ## that this listener can run only once
    registerListener(emitter, key, handler, Once)

template emit*[E: EventEmitter](emitter: var E, eventId: string, args: varargs[Arg] = @[]): untyped =
    ## Call an event by ``id`` and trigger all registered listeners
    ## related to the event. You can pass one or more ``args``
    ## to listener callback using the ``newArg`` procedure.
    runnableExamples:
        Event.emit("account.update.email", newArg("new.address@example.com"), newArg("192.168.1.1"))

    if emitter.subscribers.hasKey(eventId):
        for i, listener in pairs(emitter.subscribers[eventId]):
            listener.runCallable(args)
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
