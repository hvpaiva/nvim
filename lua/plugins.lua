-- ============================================================================
-- Plugin manifest, non-mini plugin setups, and user commands
-- ============================================================================
-- This file does, in order:
--   1. `vim.pack.add` registers every external plugin so subsequent `require`s
--      can resolve them. Must run before mini.lua / theme.lua / treesitter.lua
--      / lsp.lua, all of which `require` plugin modules.
--   2. Sets up editing plugins that don't fit in mini.lua: conform,
--      treesitter-context, nvim-highlight-colors, todo-comments.
--   3. Exposes `:PackUpdate` to refresh plugins.
-- Mini.* setups live in `lua/mini.lua`; training tools in `lua/training.lua`;
-- spell commands in `lua/spell.lua`; theme + palette in `lua/theme.lua`.
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
    "https://github.com/tpope/vim-sleuth",
    "https://github.com/psliwka/vim-dirtytalk",
    "https://github.com/gthelding/monokai-pro.nvim",
    "https://github.com/mbbill/undotree",
    "https://github.com/m4xshen/hardtime.nvim",
    "https://github.com/tris203/precognition.nvim",
    "https://github.com/MeanderingProgrammer/render-markdown.nvim",
    "https://github.com/stevearc/oil.nvim",
    "https://github.com/folke/lazydev.nvim",
})

-- Interactive training games stay managed by vim.pack, but their `plugin/`
-- files are not sourced on startup. `lua/training.lua` adds each runtime path
-- only when its command/keymap is used.
vim.pack.add({
    "https://github.com/szymonwilczek/vim-be-better",
    "https://github.com/brentsec/VimTeacher",
    "https://github.com/Weyaaron/nvim-training",
}, {
    load = function() end,
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

-- conform.nvim: per-filetype formatters. Lua + Markdown get explicit external
-- formatters; Ruby is project-detected (Standard vs RuboCop). For Go and Rust
-- the LSP formats and conform falls back to it via `lsp_format = "fallback"`.
-- ruby-lsp is told not to format (see after/lsp/ruby_lsp.lua) so the choice
-- below is the single source of truth for Ruby. Formatting is invoked via
-- the native `gq{motion}` operator (formatexpr wired below) and `gQ` for the
-- whole buffer (see keymaps.lua). External tooling (prettier, rubocop,
-- standardrb) is installed by scripts/nvim-lsp-install; project-bundled
-- versions override these when present.
require("conform").setup({
    default_format_opts = { lsp_format = "fallback" },
    formatters_by_ft = {
        lua = { "stylua" },
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
        -- Ruby: prefer Standard if the project ships a Standard config,
        -- then RuboCop if it ships a RuboCop config, then fall back to
        -- Standard (matches modern Ruby ecosystem convention).
        ruby = function(bufnr)
            local path = vim.api.nvim_buf_get_name(bufnr)
            local has_standard = vim.fs.find(
                { ".standard.yml", "standard.yml" },
                { upward = true, path = path }
            )[1]
            if has_standard then
                return { "standardrb" }
            end
            local has_rubocop = vim.fs.find(
                { ".rubocop.yml", ".rubocop_todo.yml", "rubocop.yml" },
                { upward = true, path = path }
            )[1]
            if has_rubocop then
                return { "rubocop" }
            end
            return { "standardrb" }
        end,
    },
})

-- Route the native `gq{motion}` operator through conform, so motion-based
-- formatting (gqip, gqap, gqG, visual + gq) uses the same formatter stack
-- as the explicit `gQ` mapping in keymaps.lua.
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

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

-- render-markdown.nvim: in-buffer rendering of markdown (headings, tables,
-- code blocks, callouts, checkboxes). Off by default; toggle with
-- `<Leader>om` (keymaps.lua) when reading or reviewing.
require("render-markdown").setup({ enabled = false })

-- oil.nvim: edit the filesystem like a normal buffer. `-` opens the parent
-- directory; rename/create/delete by editing lines and `:w` to apply.
-- `columns = {}` drops the icon column to keep the listing plain (no devicons
-- dependency). Hidden files toggle with `g.`, preview with `<C-p>` (defaults).
-- Opening a directory (`nvim .`, `:e somedir/`) lands in oil; see the netrw
-- note in options.lua. Keymaps live in keymaps.lua.
require("oil").setup({ columns = {} })

-- lazydev.nvim: manages the lua_ls `workspace.library` dynamically. Seeds it
-- with VIMRUNTIME (the `vim.*` API) and adds a plugin's types only when a file
-- `require`s it. The `luv` entry pulls in `vim.uv` annotations on demand.
require("lazydev").setup({
    library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
})

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
