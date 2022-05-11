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

import std/tables
from std/strutils import `%`

type
    RunType* = enum
        Anytime, Once

    EventArgs* = ref object of RootObj

    CallableEvent* = proc() {.closure.}

    Listener = tuple[id: string, runCallable: CallableEvent, runType: RunType]

    EventEmitter = object
        ## Available as a Singleton instance ``Events``
        events: Table[string, seq[Listener]]

    SupranimEventEmitter = object of CatchableError

var Events* = EventEmitter()

proc on*[E: EventEmitter](emitter: var E, id: string, handler: CallableEvent) =
    ## Subscribe to an event every time is triggered
    runnableExamples:
        Events.on("signup") do (arg: EventArgs):
            echo "something useful"
    if not emitter.events.hasKey(id):
        emitter.events[id] = newSeq[Listener]()
    emitter.events[id].add (id: id, runCallable: handler, runType: Anytime)

proc once*[E: EventEmitter](emitter: var E, id: string, handler: CallableEvent) =
    ## Subscribe to an event once and delete after
    if not emitter.events.hasKey(id):
        emitter.events[id] = newSeq[Listener]()
    emitter.events[id].add (id: id, runCallable: handler, runType: Once)

proc emit*[E: EventEmitter](emitter: var E, id: string) =
    ## Trigger an event by ``id`` with provided arguments
    if emitter.events.hasKey(id):
        for key, listener in pairs(emitter.events[id]):
            listener.runCallable()
            if listener.runType == Once:
                emitter.events[id].delete(key) # delete the listener once called