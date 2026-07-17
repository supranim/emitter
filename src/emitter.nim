# A simple event emitter implementation with support for
# multiple backends (Libevent and Powpow).
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/supranim/emitter

import std/[tables, strutils, sequtils, typeinfo, options, locks]

import pkg/openparser/fbe

when defined(supraNative):
  import pkg/powpow
else:
  import pkg/libevent/bindings/event

export tables, typeinfo, options

type
  RunType* = enum
    Anytime, Once

  Args* = seq[string]
  Callback* = proc(args: Option[Args]) {.nimcall.}

  Listener* = object
    id*: string
    token*: uint64
    runCallable*: Callback
    runType*: RunType

  QueuedEmit = object
    eventId: string
    args: Option[Args]

  EventEmitter* = ref object
    subscribers: Table[string, seq[Listener]]
    pending: seq[QueuedEmit]
    nextToken: uint64
    lock: Lock
    when defined(supraNative):
      loop*: Loop
      tickTimer: TimerId
    else:
      base*: ptr event_base
      tickEv: ptr event
      tickTv: Timeval

  EventEmitterError = object of CatchableError

proc newArg*(arg: string): string =
  var buf = initBuffer()
  buf.writeString(arg)
  result.setLen(buf.data.len)
  if buf.data.len > 0:
    copyMem(addr result[0], addr buf.data[0], buf.data.len)

proc newArg*(arg: int): string =
  var buf = initBuffer()
  buf.writeInt64LE(arg.int64)
  result.setLen(buf.data.len)
  if buf.data.len > 0:
    copyMem(addr result[0], addr buf.data[0], buf.data.len)

proc newArg*(arg: float): string =
  var buf = initBuffer()
  buf.writeFloat64LE(arg)
  result.setLen(buf.data.len)
  if buf.data.len > 0:
    copyMem(addr result[0], addr buf.data[0], buf.data.len)

proc unpackArg*[T](x: string): T =
  var buf = initBuffer()
  buf.data.setLen(x.len)
  if x.len > 0:
    copyMem(addr buf.data[0], addr x[0], x.len)
  buf.pos = 0
  when T is string:
    result = buf.readString()
  elif T is int:
    result = int(buf.readInt64LE())
  elif T is float:
    result = buf.readFloat64LE()

proc dispatchNow(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args]) =
  var toCall: seq[Callback]
  acquire(emitter.lock)
  defer: release(emitter.lock)
  if emitter.subscribers.hasKey(eventId):
    var i = emitter.subscribers[eventId].high
    while i >= 0:
      let listener = emitter.subscribers[eventId][i]
      if listener.runType == Once:
        emitter.subscribers[eventId].delete(i)
      toCall.add(listener.runCallable)
      dec i
  else:
    let keys = toSeq(emitter.subscribers.keys)
    for subId in keys:
      if subId.len > 0 and subId[^1] == '*' and eventId.startsWith(subId[0..^2]):
        var i = emitter.subscribers[subId].high
        while i >= 0:
          let listener = emitter.subscribers[subId][i]
          if listener.runType == Once:
            emitter.subscribers[subId].delete(i)
          toCall.add(listener.runCallable)
          dec i
  for cb in toCall:
    cb(args)

proc drainQueue(emitter: var EventEmitter|ptr EventEmitter) =
  var queue: seq[QueuedEmit]
  acquire(emitter.lock)
  if emitter.pending.len == 0:
    release(emitter.lock)
    return
  queue = move(emitter.pending)
  emitter.pending = @[]
  release(emitter.lock)
  for item in queue:
    emitter.dispatchNow(item.eventId, item.args)

proc registerListener*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback, runType: RunType): uint64 {.discardable.} =
  acquire(emitter.lock)
  if not emitter.subscribers.hasKey(key):
    emitter.subscribers[key] = @[]
  inc emitter.nextToken
  let tok = emitter.nextToken
  emitter.subscribers[key].add Listener(id: key, token: tok, runCallable: handler, runType: runType)
  result = tok
  release(emitter.lock)

proc listen*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback): uint64 {.discardable.} =
  emitter.registerListener(key, handler, Anytime)

proc listenOnce*(emitter: var EventEmitter|ptr EventEmitter, key: string, handler: Callback): uint64 {.discardable.} =
  emitter.registerListener(key, handler, Once)

proc off*(emitter: var EventEmitter|ptr EventEmitter, key: string, token: uint64): bool {.discardable.} =
  acquire(emitter.lock)
  if not emitter.subscribers.hasKey(key):
    release(emitter.lock)
    return false
  var i = emitter.subscribers[key].high
  while i >= 0:
    if emitter.subscribers[key][i].token == token:
      emitter.subscribers[key].delete(i)
      release(emitter.lock)
      return true
    dec i
  release(emitter.lock)
  false

proc emit*(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args] = none(Args)) =
  acquire(emitter.lock)
  emitter.pending.add QueuedEmit(eventId: eventId, args: args)
  release(emitter.lock)

proc emitNow*(emitter: var EventEmitter|ptr EventEmitter, eventId: string, args: Option[Args] = none(Args)) =
  emitter.dispatchNow(eventId, args)

when defined(supraNative):
  include emitter/emitter_powpow
else:
  include emitter/emitter_libevent
