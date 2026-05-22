-- ============================================================================
-- Plugin manifest, non-mini plugin setups, and user commands
-- ============================================================================
-- This file does, in order:
--   1. `vim.pack.add` registers every external plugin so subsequent `require`s
--      can resolve them. Must run before mini.lua / theme.lua / treesitter.lua
--      / lsp.lua, all of which `require` plugin modules.
--   2. Sets up plugins that don't fit in mini.lua: conform, treesitter-context,
--      nvim-highlight-colors, todo-comments.
--   3. Defines spell-related user commands (`:DirtytalkUpdate` override,
--      `:CustomSpellUpdate`) that depend on vim-dirtytalk being on disk.
--   4. Exposes `:PackUpdate` to refresh plugins.
-- Mini.* setups live in `lua/mini.lua`; theme + palette in `lua/theme.lua`.
vim.pack.add({
    "https://github.com/nvim-mini/mini.nvim",
    "https://github.com/rafamadriz/friendly-snippets",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
    "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
    "https://github.com/nvim-treesitter/nvim-treesitter-context",
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/tpope/vim-fugitive",
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/brenoprata10/nvim-highlight-colors",
    "https://github.com/nvim-lua/plenary.nvim",
    "https://github.com/folke/todo-comments.nvim",
    "https://github.com/theprimeagen/vim-be-good",
    "https://github.com/tpope/vim-sleuth",
    "https://github.com/psliwka/vim-dirtytalk",
    "https://github.com/gthelding/monokai-pro.nvim",
    "https://github.com/mbbill/undotree",
    "https://github.com/m4xshen/hardtime.nvim",
    "https://github.com/tris203/precognition.nvim",
})

-- ============================================================================
-- Editing tools
-- ============================================================================

-- undotree.vim: richer UI around Vim's native undo tree, with a diff panel.
vim.g.undotree_WindowLayout = 3 -- Tree + diff on the right, matching splitright=true.
vim.g.undotree_SplitWidth = 32
vim.g.undotree_DiffpanelHeight = 12
vim.g.undotree_DiffAutoOpen = 1
vim.g.undotree_SetFocusWhenToggle = 1

-- conform.nvim: per-filetype formatters where the LSP does not format itself.
-- For LSP-formatted languages (Go, Rust, Ruby), the default falls through to
-- the LSP formatter. Formatting is manual — `<Leader>lf` from keymaps.lua.
require("conform").setup({
    default_format_opts = { lsp_format = "fallback" },
    formatters_by_ft = {
        lua = { "stylua" },
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
        -- Ruby: prefer Standard, fall back to RuboCop if the project ships one.
        ruby = function(bufnr)
            local has_rubocop = vim.fs.find(
                { ".rubocop.yml", ".rubocop_todo.yml" },
                { upward = true, path = vim.api.nvim_buf_get_name(bufnr) }
            )[1]
            return has_rubocop and { "rubocop" } or { "standardrb" }
        end,
    },
})

-- treesitter-context: sticky scope header at the top of the window.
require("treesitter-context").setup({
    max_lines = 3,
    trim_scope = "outer",
    mode = "cursor",
})

-- nvim-highlight-colors: inline color preview for #hex, rgb(), hsl(), named.
require("nvim-highlight-colors").setup({})

-- todo-comments: highlight TODO / FIXME / HACK / NOTE / WARN in comments.
-- Signs off so the gutter stays clean.
require("todo-comments").setup({ signs = false })

-- hardtime.nvim: warns on repeated hjkl, blocks arrow keys in normal/visual.
require("hardtime").setup({
    max_count = 3,
    disable_mouse = true,
    hint = true,
    notification = true,
    allow_different_key = true,
})

-- precognition.nvim: virtual-text hints for motions (w, e, f<x>, ^, $) on the
-- current line. Toggle with :Precognition toggle when reflex is firm.
require("precognition").setup({
    startVisible = false,
    showBlankVirtLine = true,
})

-- vim-dirtytalk: ships wordlists for programming jargon (languages, tooling,
-- acronyms). The plugin's own `:DirtytalkUpdate` calls `spellfile#WritableSpellDir`,
-- which Neovim 0.12 removed when porting `spellfile.vim` to Lua. We override
-- the command with a Lua reimplementation that compiles `wordlists/*.words`
-- straight into `stdpath('data')/site/spell/programming.utf-8.spl`.
-- The override must run on `VimEnter`: `vim.pack.add` defers sourcing the
-- plugin's `plugin/dirtytalk.vim` until then, so anything we register inline
-- gets clobbered by the plugin's `command!` definition.
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("hvpaiva-dirtytalk", { clear = true }),
    callback = function()
        -- Defer so our override runs after the plugin's own `command!`, which
        -- nvim 0.12 sources from `plugin/dirtytalk.vim` on the same VimEnter.
        vim.schedule(function()
            vim.api.nvim_create_user_command("DirtytalkUpdate", function()
            local plugin_dir = vim.fn.expand("~/.local/share/nvim/site/pack/core/opt/vim-dirtytalk")
            local files = vim.fn.glob(plugin_dir .. "/wordlists/*.words", true, true)
            local blacklist = vim.tbl_map(tostring, vim.g.dirtytalk_blacklist or {})
            local words = {}
            for _, f in ipairs(files) do
                local name = vim.fn.fnamemodify(f, ":t:r")
                if not vim.tbl_contains(blacklist, name) then
                    vim.list_extend(words, vim.fn.readfile(f))
                end
            end
            local tmp = vim.fn.tempname()
            vim.fn.writefile(words, tmp)
            local spell_dir = vim.fn.stdpath("data") .. "/site/spell"
            vim.fn.mkdir(spell_dir, "p")
            vim.cmd("mkspell! " .. spell_dir .. "/programming " .. tmp)
            vim.fn.delete(tmp)
        end, { desc = "Compile vim-dirtytalk wordlists into programming.utf-8.spl" })
        end)
    end,
})

-- :CustomSpellUpdate — compile `~/.config/nvim/spell/custom.words` (one word
-- per line, `#` comments) into `custom.utf-8.spl`. Run this after editing the
-- wordlist; the `custom` entry in `spelllang` (see `after/ftplugin/markdown.lua`)
-- then picks the result up on the next buffer reload.
vim.api.nvim_create_user_command("CustomSpellUpdate", function()
    local src = vim.fn.stdpath("config") .. "/spell/custom.words"
    if vim.fn.filereadable(src) == 0 then
        vim.notify("custom.words not found at " .. src, vim.log.levels.ERROR)
        return
    end
    local words = {}
    for _, line in ipairs(vim.fn.readfile(src)) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            table.insert(words, trimmed)
        end
    end
    local tmp = vim.fn.tempname()
    vim.fn.writefile(words, tmp)
    local spell_dir = vim.fn.stdpath("data") .. "/site/spell"
    vim.fn.mkdir(spell_dir, "p")
    vim.cmd("mkspell! " .. spell_dir .. "/custom " .. tmp)
    vim.fn.delete(tmp)
end, { desc = "Compile ~/.config/nvim/spell/custom.words into custom.utf-8.spl" })

-- ============================================================================
-- Plugin manager commands
-- ============================================================================

-- :PackUpdate            update everything
-- :PackUpdate name1 name2  update only those
vim.api.nvim_create_user_command("PackUpdate", function(opts)
    if opts.args:match("%S") then
        local plugins = vim.split(opts.args, "%s+", { trimempty = true })
        vim.pack.update(plugins)
    else
        vim.pack.update()
    end
end, { nargs = "*", desc = "Update plugins (all if no args given)" })
