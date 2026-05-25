-- Opt into the experimental cmdline + messages UI shipped in 0.12. It moves
-- the cmdline to a centered float and routes `:messages` through the same
-- system, which lets mini.cmdline (in mini.lua) own the prompt. Underscore
-- namespace = unstable API: keep this protected so a future nvim minor bump
-- does not break startup if the API moves or disappears.
local ok_ui2, ui2 = pcall(require, "vim._core.ui2")
if ok_ui2 and ui2.enable then
    ui2.enable({})
end

-- Load order matters: `plugins` registers everything via `vim.pack.add`, so it
-- must precede `mini`/`theme`/`treesitter`/`lsp`, all of which `require` plugin
-- modules. `spell`/`training` depend on plugin specs being registered. `lsp`
-- is last because it consumes `mini.completion` capabilities.
require("options")
require("keymaps")
require("autocmds")
require("plugins")
require("spell")
require("mini")
require("training")
require("theme")
require("treesitter")
require("lsp")
