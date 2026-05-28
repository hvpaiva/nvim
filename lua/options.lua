-- General ====================================================================
vim.g.mapleader = " " -- Use `<Space>` as <Leader> key

-- Disable language providers we do not use. Saves startup cost and removes
-- "missing provider" warnings from `:checkhealth`.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Register custom filetypes that Neovim does not detect by default.
vim.filetype.add({
    extension = {
        gotmpl = "gotmpl",
        mdx = "markdown.mdx",
    },
    filename = {
        ["go.work"] = "gowork",
    },
})

-- Defer enabling the system clipboard until the UI is up. Touching it at
-- startup can stall when running over SSH or with a slow clipboard provider.
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)

vim.o.mouse = "" -- Disable mouse
vim.o.switchbuf = "usetab" -- Reuse already opened buffers when switching
vim.o.confirm = true -- Prompt for confirmation when an operation would fail or lose changes

-- No swap or backup files; persist undo across sessions instead.
vim.o.swapfile = false
vim.o.backup = false
vim.o.undofile = true

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

vim.opt.isfname:append("@-@") -- Treat `@` as part of filenames so `gf` works on paths with `@`
vim.o.updatetime = 250 -- Faster CursorHold and swap write triggers (default 4000ms)

-- UI =========================================================================
-- Disable netrw entirely; mini.files owns the file-explorer role. Has to be
-- set before the FileExplorer autocmd registers netrw's :Explore handler.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Hybrid line numbers: absolute on the current line, relative on the others.
-- Relative numbers make `{count}j`/`{count}k` motions a glance-and-go.
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true -- Required for `cursorlineopt` below
vim.o.cursorlineopt = "number" -- Highlight only the current line *number*, not the whole line
vim.o.colorcolumn = "" -- No vertical ruler
vim.o.signcolumn = "yes" -- Always show signcolumn (avoids buffer shift)
vim.o.scrolloff = 10 -- Keep N lines of context above/below cursor
vim.o.wrap = false -- Don't visually wrap long lines
vim.o.guicursor = "" -- Let the terminal render its own cursor (no nvim styling)
vim.o.ruler = false -- Don't show cursor coordinates in the cmdline
vim.o.shortmess = "CFOSWaco" -- Mute noisy completion / file / search messages
vim.o.laststatus = 3 -- Single global statusline shared by all windows
vim.o.statusline = " %f %m%= %p%% " -- Path · modified flag · (right) percentage
vim.o.pumborder = "single" -- Border style for the popup menu
vim.o.pumheight = 10 -- Cap popup menu height
vim.o.pummaxwidth = 100 -- Cap popup menu width
vim.o.winborder = "single" -- Default border for floating windows
-- New splits land below / to the right of the focused window, matching the
-- left-to-right, top-down reading order so the new pane is where the eye
-- moves next, not behind the cursor.
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.splitkeep = "screen" -- Reduce scroll/jump when opening a split
vim.o.fillchars = "fold:╌" -- Fold separator character

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
vim.o.foldlevel = 10 -- Open all folds by default (lower this to fold)
vim.o.foldmethod = "indent" -- Fold based on indent level
vim.o.foldnestmax = 10 -- Cap nested fold levels
vim.o.foldtext = "" -- Render folded text with its own highlighting

-- Editing ====================================================================
-- Indent with spaces, 2-wide. vim-sleuth (plugins.lua) overrides this per
-- buffer when the surrounding file uses tabs or a different width, so this
-- is just the fallback for fresh / unknown files.
vim.o.expandtab = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.autoindent = true -- Carry indent over to the next line
vim.o.smartindent = true -- Add an extra step after `{` and friends
vim.o.virtualedit = "block" -- Allow cursor past EOL in visual block
vim.o.ignorecase = true -- Ignore case while searching...
vim.o.smartcase = true -- ...unless the pattern has uppercase letters
vim.o.inccommand = "split" -- Live preview for `:s` / `:%s` in a scratch split
vim.o.formatoptions = "rqnl1j" -- Comment editing (autocmds.lua strips `c` and `o` per filetype)
vim.o.spelloptions = "camel" -- Treat camelCase parts as separate words for spell
-- `noinsert` keeps the buffer text as typed while the popup is open: the
-- first match is highlighted but not committed, so `<C-n>`/`<C-p>` move the
-- highlight without rewriting the buffer and `<C-y>` is the only confirm.
vim.o.completeopt = "menuone,noinsert,fuzzy,nosort"

-- `iskeyword` extensions like adding `-` are filetype-local (markdown link
-- slugs, CSS class names); set them in after/ftplugin/{markdown,css}.lua,
-- not here, otherwise word motions in Ruby/Lua/Rust behave incorrectly
-- (e.g. `method-name` would count as one word).

-- Pattern for the start of a numbered list (used by `gw`):
-- one or more digits / `-` / `+` / `*`, optionally followed by `.` or `)`, then a space.
vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]
