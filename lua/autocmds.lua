-- Briefly highlight the region that was just yanked. The named augroup is
-- cleared on each load so re-sourcing this file does not duplicate callbacks.
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("hvpaiva-yank-highlight", { clear = true }),
    desc = "Highlight yanked text",
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Strip `c` (auto-wrap comments) and `o` (continue comment leader on `o`/`O`)
-- per-buffer on every `FileType`, because most ftplugins re-add them after the
-- global `formatoptions` set in options.lua is applied.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("hvpaiva-formatopts", { clear = true }),
    desc = "Proper 'formatoptions'",
    callback = function()
        vim.opt_local.formatoptions:remove("c")
        vim.opt_local.formatoptions:remove("o")
    end,
})

-- Rebuild tree-sitter parsers after the `nvim-treesitter` plugin updates,
-- keeping parser ABI in sync with the plugin. On the `main` branch the
-- entry point is `require('nvim-treesitter').install()` (no `:TSUpdate`).
vim.api.nvim_create_autocmd("PackChanged", {
    group = vim.api.nvim_create_augroup("hvpaiva-ts-rebuild", { clear = true }),
    desc = "Rebuild TS parsers when nvim-treesitter updates",
    callback = function(ev)
        if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
            require("nvim-treesitter").install()
        end
    end,
})

-- When an LSP attaches, bind mini.completion's LSP-aware function to the
-- buffer's `omnifunc`. We set `omnifunc` (not `completefunc`) so `<C-x><C-u>`
-- stays free, and the function is only wired where it has work to do.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("hvpaiva-lsp-omnifunc", { clear = true }),
    desc = "Set omnifunc to mini.completion's LSP function",
    callback = function(ev)
        vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
    end,
})
