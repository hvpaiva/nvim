-- Opt into the experimental cmdline + messages UI shipped in 0.12. It moves
-- the cmdline to a centered float and routes `:messages` through the same
-- system, which lets mini.cmdline (in mini.lua) own the prompt. Underscore
-- namespace = unstable API: revisit on every nvim minor bump.
require("vim._core.ui2").enable({})

-- Load order matters: `plugins` registers everything via `vim.pack.add`, so it
-- must precede `mini`/`theme`/`treesitter`/`lsp`, all of which `require` plugin
-- modules. `lsp` is last because it consumes `mini.completion` capabilities.
require("options")
require("keymaps")
require("autocmds")
require("plugins")
require("mini")
require("theme")
require("treesitter")
require("lsp")
