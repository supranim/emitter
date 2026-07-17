suite "EventEmitter - Sync (emitNow)":
  var emitter: EventEmitter

  setup:
    emitter = EventEmitter()
    emitter.init(50)

  teardown:
    emitter.close()

  test "listen fires on emitNow":
    var fired = false
    emitter.listen("test.event") do(args: Option[Args]):
      fired = true
    emitter.emitNow("test.event")
    check fired

  test "listenOnce fires only once":
    var count = 0
    emitter.listenOnce("test.event") do(args: Option[Args]):
      inc count
    emitter.emitNow("test.event")
    check count == 1
    emitter.emitNow("test.event")
    check count == 1

  test "off prevents dispatch":
    var fired = false
    let token = emitter.listen("test.event") do(args: Option[Args]):
      fired = true
    emitter.off("test.event", token)
    emitter.emitNow("test.event")
    check not fired

  test "wildcard matches sub-events":
    var fired = false
    emitter.listen("user.*") do(args: Option[Args]):
      fired = true
    emitter.emitNow("user.login")
    check fired

  test "wildcard does not match unrelated":
    var fired = false
    emitter.listen("user.*") do(args: Option[Args]):
      fired = true
    emitter.emitNow("admin.login")
    check not fired

  test "multiple listeners all fire":
    var count = 0
    emitter.listen("test.event") do(args: Option[Args]):
      inc count
    emitter.listen("test.event") do(args: Option[Args]):
      inc count
    emitter.emitNow("test.event")
    check count == 2

  test "args passed through correctly":
    var received: Option[Args]
    emitter.listen("test.event") do(args: Option[Args]):
      received = args
    emitter.emitNow("test.event", some(@["hello", "world"]))
    check received.isSome
    check received.get == @["hello", "world"]

  test "emitNow without args gives none":
    var opt: Option[Args]
    emitter.listen("test.event") do(args: Option[Args]):
      opt = args
    emitter.emitNow("test.event")
    check opt.isNone

  test "off returns true when removed":
    let token = emitter.listen("test.event") do(args: Option[Args]): discard
    check emitter.off("test.event", token)

  test "off returns false for unknown token":
    check not emitter.off("test.event", 999)

  test "off returns false for unknown key":
    check not emitter.off("nonexistent", 1)

suite "EventEmitter - Async (emit + tick drain)":
  var emitter: EventEmitter

  setup:
    emitter = EventEmitter()
    emitter.init(50)

  teardown:
    emitter.close()

  test "emit dispatches via tick":
    var fired = false
    emitter.listen("test.event") do(args: Option[Args]):
      fired = true
      emitter.stop()
    emitter.emit("test.event")
    emitter.run()
    check fired

  test "multiple queued emits":
    var count = 0
    emitter.listen("test.event") do(args: Option[Args]):
      inc count
      if count == 3:
        emitter.stop()
    emitter.emit("test.event")
    emitter.emit("test.event")
    emitter.emit("test.event")
    emitter.run()
    check count == 3

suite "EventEmitter - Lifecycle":
  test "init then close":
    var e = EventEmitter()
    e.init()
    e.close()

  test "double close is safe":
    var e = EventEmitter()
    e.init()
    e.close()
    e.close()

  test "close without init is safe":
    var e = EventEmitter()
    e.close()

  test "custom interval":
    var e = EventEmitter()
    e.init(100)
    e.close()

  test "run without init is safe":
    var e = EventEmitter()
    e.run()

  test "stop without init is safe":
    var e = EventEmitter()
    e.stop()

suite "EventEmitter - Serialization":
  test "newArg string roundtrip":
    let s = "hello emitter"
    let packed = newArg(s)
    let unpacked = unpackArg[string](packed)
    check unpacked == s

  test "newArg int roundtrip":
    let n = 42
    let packed = newArg(n)
    let unpacked = unpackArg[int](packed)
    check unpacked == n

  test "newArg float roundtrip":
    let f = 3.14159
    let packed = newArg(f)
    let unpacked = unpackArg[float](packed)
    check abs(unpacked - f) < 0.001
