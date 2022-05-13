# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Supranim's Event Emitter - Subscribe & listen for various events within your application"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0"

task tests, "Run tests":
    exec "testament p 'tests/*.nim'"