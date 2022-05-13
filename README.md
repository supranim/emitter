<p align="center">
    <img src="https://raw.githubusercontent.com/supranim/emitter/main/.github/supranim-emitter.png" height="65px" alt="Supranim Events Emitter"><br>
    Supranim's Event Emitter - Subscribe & listen for various events within your application
</p>

## ✨ Key features
- [x] Framework Agnostic
- [x] Available in ⚡️ [Supranim Framework](https://github.com/supranim/supranim)
- [x] Dependency-free
- [x] Open Source | `MIT` License

## Install
```bash
nimble install emitter
```

## Examples

Using Emitter from your Supranim Application
```nim
# todo
```

Using Emitter from any project
```nim

# somewhere in your main application
Event.listen("account.email.changed") do(args: varargs[Arg]):
    echo "Email address has been changed."
    # do the do, send confirmation mails, etc...

# somewhere in your proc-based ``POST`` or ``UPDATE`` controller
let newEmailAddress = "new.address@example.com"
Event.emit("account.email.changed", newArg(newEmailAddress))
```

### ❤ Contributions
If you like this project you can contribute to Tim project by opening new issues, fixing bugs, contribute with code, ideas and you can even [donate via PayPal address](https://www.paypal.com/donate/?hosted_button_id=RJK3ZTDWPL55C) 🥰

### 👑 Discover Nim language
<strong>What's Nim?</strong> Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula. [Find out more about Nim language](https://nim-lang.org/)

<strong>Why Nim?</strong> Performance, fast compilation and C-like freedom. We want to keep code clean, readable, concise, and close to our intention. Also a very good language to learn in 2022.

### 🎩 License
Events is an Open Source Software released under `MIT` license. [Made by Humans from OpenPeep](https://github.com/openpeep).<br>
Copyright &copy; 2022 Supranim & OpenPeep &mdash; All rights reserved.

<a href="https://hetzner.cloud/?ref=Hm0mYGM9NxZ4"><img src="https://openpeep.ro/banners/openpeep-footer.png" width="100%"></a>
