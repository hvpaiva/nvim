-- Native LSP defaults in 0.11+ already provide:
--   K (hover), grn (rename), gra (code action), grr (references),
--   gri (implementation), gO (document symbol), <C-]>/<C-w>d.
-- Custom <leader>l* mappings (incl. <leader>lf for format) live in keymaps.lua.

vim.diagnostic.config({
    severity_sort = true,
    virtual_text = false,
    float = { border = "rounded", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
    },
})

-- mini.completion already extends the default client capabilities with the
-- completion/signature features it implements, so use the result directly.
vim.lsp.config("*", { capabilities = require("mini.completion").get_lsp_capabilities() })

-- Per-server tuning lives in `after/lsp/<name>.lua` (see `after/lsp/lua_ls.lua`).

vim.lsp.enable({
    "lua_ls",
    "marksman",
    "gopls",
    "rust_analyzer",
    "ruby_lsp",
})
