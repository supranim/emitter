# Package

version       = "0.1.2"
author        = "Supranim"
description   = "Supranim's Event Emitter - Subscribe & listen for events"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"
requires "libevent"
requires "flatty"

task docgen, "Generate API documentation":
    exec "nim doc --project --index:on --outdir:htmldocs src/emitter.nim"

task tests, "Run tests":
    exec "testament p 'tests/*.nim'"