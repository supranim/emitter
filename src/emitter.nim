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
        events: Table[string, seq[Listener]]

when compileOption("threads"):
    var Event* {.threadvar.}: EventEmitter
else:
    var Event* = EventEmitter()

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
    if not emitter.events.hasKey(key):
        emitter.events[key] = newSeq[Listener]()
    emitter.events[key].add (id: key, runCallable: handler, runType: Anytime)

template listen*[E: EventEmitter](emitter: var E, key: string, handler: Callback): untyped =
    ## Subscribe to a specific event with a runnable callback.
    ##
    ## You may want to register a listener using the ``*``
    ## as a wildcard for ``key`` parameter. This allows you to catch
    ## register same listener to multiple events.
    runnableExamples:
        Event.listen("account.update.email") do(args: varargs[Arg]):
            echo "Email address has been changed."

        Event.listen("account.update.*") do(args: varargs[Arg]):
            echo "Listening for any events related to `account.update`"

    registerListener(emitter, key, handler, Anytime)

template listenOnce*[E: EventEmitter](emitter: var E, key: string, handler: Callback): untyped =
    ## Same as ``listen`` proc, the only difference is
    ## that this listener can run only once
    registerListener(emitter, key, handler, Once)

template emit*[E: EventEmitter](emitter: var E, id: string, args: varargs[Arg] = @[]):untyped =
    ## Call an event by ``id`` and trigger all registered listeners
    ## related to the event. You can pass one or more ``args``
    ## to listener callback using the ``newArg`` procedure.
    runnableExamples:
        Event.emit("account.update.email", newArg("new.address@example.com"), newArg("192.168.1.1"))

    if emitter.events.hasKey(id):
        for key, listener in pairs(emitter.events[id]):
            listener.runCallable(args)
            if listener.runType == Once:
                emitter.events[id].delete(key)
