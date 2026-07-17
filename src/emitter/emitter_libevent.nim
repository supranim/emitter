# A simple event emitter implementation with support for
# multiple backends (Libevent and Powpow).
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/supranim/emitter

when defined(macosx):
  {.passC: "-I/usr/local/include -I/opt/homebrew/include".}
  {.passL: "-L/usr/local/lib -L/opt/homebrew/lib -Wl,-rpath,/usr/local/lib -Wl,-rpath,/opt/homebrew/lib -levent".}
elif defined(linux):
  {.passL: "-levent".}

proc onTick(fd: cint, events: cshort, arg: pointer) {.cdecl.} =
  var emitter = cast[EventEmitter](arg)
  emitter.drainQueue()

proc init*(emitter: var EventEmitter|ptr EventEmitter, intervalMs = 5000) =
  emitter.subscribers = initTable[string, seq[Listener]]()
  emitter.pending = @[]
  emitter.nextToken = 0
  initLock(emitter.lock)
  emitter.base = event_base_new()
  if emitter.base.isNil:
    raise newException(EventEmitterError, "event_base_new() failed")

  emitter.tickTv.tv_sec = clong(intervalMs div 1000)
  emitter.tickTv.tv_usec = clong((intervalMs mod 1000) * 1000)

  emitter.tickEv = event_new(
    emitter.base,
    -1,
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
  if emitter.isNil: return
  if not emitter.tickEv.isNil:
    discard event_del(emitter.tickEv)
    event_free(emitter.tickEv)
    emitter.tickEv = nil
  if not emitter.base.isNil:
    event_base_free(emitter.base)
    emitter.base = nil

proc run*(emitter: var EventEmitter|ptr EventEmitter) =
  if emitter.isNil or emitter.base.isNil: return
  discard event_base_dispatch(emitter.base)

proc stop*(emitter: var EventEmitter|ptr EventEmitter) =
  if emitter.isNil or emitter.base.isNil: return
  discard event_base_loopbreak(emitter.base)
