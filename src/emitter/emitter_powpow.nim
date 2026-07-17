# A simple event emitter implementation with support for
# multiple backends (Libevent and Powpow).
#
# (c) 2025 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/supranim/emitter

proc init*(emitter: var EventEmitter|ptr EventEmitter, intervalMs = 5000) =
  emitter.subscribers = initTable[string, seq[Listener]]()
  emitter.pending = @[]
  emitter.nextToken = 0
  initLock(emitter.lock)
  emitter.loop = newLoop()
  if emitter.loop.isNil:
    raise newException(EventEmitterError, "newLoop() failed")

  let self = emitter
  emitter.tickTimer = emitter.loop.addInterval(intervalMs) do (id: int):
    self.drainQueue()

proc close*(emitter: var EventEmitter|ptr EventEmitter) =
  if emitter.isNil: return
  if not emitter.loop.isNil:
    emitter.loop.cancelTimer(emitter.tickTimer)
    emitter.loop.close()
    emitter.loop = nil

proc run*(emitter: var EventEmitter|ptr EventEmitter) =
  if emitter.isNil or emitter.loop.isNil: return
  emitter.loop.run()

proc stop*(emitter: var EventEmitter|ptr EventEmitter) =
  if emitter.isNil or emitter.loop.isNil: return
  emitter.loop.stop()
