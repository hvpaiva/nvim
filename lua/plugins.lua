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
