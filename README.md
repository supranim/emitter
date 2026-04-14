<p align="center">
    <img src="https://raw.githubusercontent.com/supranim/emitter/main/.github/supranim-emitter.png" height="65px" alt="Supranim Events Emitter"><br>
    Supranim's Event Emitter - Subscribe & listen for various events within your application
</p>

## ✨ Key features
- [x] Framework Agnostic
- [x] Available in ⚡️ [Supranim Framework](https://github.com/supranim/supranim)
- [ ] Persistent Memory w/ Supranim Storage driver
- [x] Dependency-free
- [x] Open Source | `MIT` License

## Install
```bash
nimble install emitter
```

## Examples
Listeners can receive data as `varargs[Arg]` objects, containing a public `value` field of `Any` object. [Check std/typeinfo](https://nim-lang.org/docs/typeinfo.html#Any)

### Framework agnostic usage

```nim

# somewhere in your main application
Event.listen("account.email.changed") do(args: varargs[Arg]):
    echo "Email address has been changed."
    # do the do, send confirmation mails, etc...

# somewhere in your proc-based ``POST`` or ``UPDATE`` controller
let newEmailAddress = "new.address@example.com"
Event.emit("account.email.changed", newArg(newEmailAddress))
```

### Emitter from Supranim
For apps based on [Supranim Application Template](https://github.com/supranim/app).
Note that all listeners should be stored inside `events/listeners` directory.

In Supranim is highly recommended to create a `.nim` file for each branch of your application logic.
For example, `account.nim` should hold all listeners related to accounts (email updates, password reset requests and so on).

For loading listeners into your application is recommended to use `include`, instead of `import`. Listener files can be included
in the main state of your application (this is usually the main `.nim` file of your project.)

_TODO. Create new listeners using `Sup`, the Command Line Interface of your Supranim application_

```nim
# src/events/listeners/account.nim

Event.listen("account.email.update") do(args: varargs[Arg]):
    echo "The email address has been changed."

Event.listen("account.password.reset.request") do(args: varargs[Arg]):
    echo "Request for password reset."

Event.listen("account.password.update") do(args: varargs[Arg]):
    echo "Password has been changed."
```


### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/supranim/emitter/issues)
- 👋 Wanna help? [Fork it!](https://github.com/supranim/emitter/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)

### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright &copy; 2025 OpenPeeps & Contributors &mdash; All rights reserved.
