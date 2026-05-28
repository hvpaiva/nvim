-- nvim-treesitter `main` branch: highlighting and folds are no longer wired
-- up by a `setup()` call. Each buffer opts in by calling `vim.treesitter.start`
-- on the right language. We do that on `FileType` for any filetype Neovim can
-- map to a parser, and `pcall` so unknown / uninstalled parsers fail silent
-- instead of throwing on every buffer open.
local treesitter = require("nvim-treesitter")

local ensure_installed = {
    "bash",
    "css",
    "dockerfile",
    "go",
    "html",
    "http",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "query",
    "ruby",
    "rust",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}

treesitter.install(ensure_installed)

vim.api.nvim_create_autocmd("FileType", {
    pattern = "*",
    callback = function(args)
        local buf = args.buf
        local ft = vim.bo[buf].filetype

        local lang = vim.treesitter.language.get_lang(ft)
        if not lang then
            return
        end

        local ok_add = pcall(vim.treesitter.language.add, lang)
        if not ok_add then
            return
        end

        pcall(vim.treesitter.start, buf, lang)
    end,
})
