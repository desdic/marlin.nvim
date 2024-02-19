# FAQ

## "project root not found"

If the project root is not found it can't save the jump points. You can fix this by defining more project roots like

```lua
    opts = {
        open_callback = require("marlin.callbacks").use_split,
        patterns = { ".git", ".svn", "Makefile", "Cargo.toml", "." },
    },
```

Or disabling the message with (But jump points won't be saved)

```lua
    opts = {
        suppress = {
            missing_root = false
        }
    }
```
