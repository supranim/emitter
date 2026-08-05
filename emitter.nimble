# Package

version       = "0.2.1"
author        = "Supranim"
description   = "Supranim's Event Emitter - Subscribe & listen for events"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.10"
requires "threading >= 0.1.0"
requires "openparser >= 0.1.4"

feature "powpow":
  requires "powpow >= 0.1.4"

feature "libevent":
  requires "libevent >= 0.1.2"

task test, "Run all tests":
  exec "nim c -r tests/test_libevent.nim"
  exec "nim c -r -d:features.emitter.powpow tests/test_powpow.nim"