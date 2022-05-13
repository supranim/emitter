import unittest
import emitter

test "do the do":
    let eventId = "account.password.update"
    let emailAddress = "new.address@example.com"
    Event.listen(eventId) do(args: varargs[Arg]):
        check args.len == 1
        check args[0].value.getString == "new.address@example.com"

    Event.emit(eventId, newArg(emailAddress))
