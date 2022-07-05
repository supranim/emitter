# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Supranim's Event Emitter - Subscribe & listen for various events within your application"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"

task docgen, "Generate API documentation":
    exec "nim doc --project --index:on --outdir:htmldocs src/emitter.nim"

task tests, "Run tests":
    exec "testament p 'tests/*.nim'"