-- nvim-treesitter `main` branch: highlighting and folds are opt-in per buffer
-- via `vim.treesitter.start`. We do that on `FileType` for any filetype Neovim
-- can map to a parser, wrapped in `pcall` so unknown or uninstalled parsers
-- fail silent.
local treesitter = require("nvim-treesitter")

local ensure_installed = {
    "bash",
    "c",
    "css",
    "diff",
    "dockerfile",
    "dtd",
    "fish",
    "git_config",
    "git_rebase",
    "gitattributes",
    "gitcommit",
    "gitignore",
    "go",
    "gomod",
    "gosum",
    "gotmpl",
    "gowork",
    "haskell",
    "hcl",
    "helm",
    "html",
    "http",
    "hyprlang",
    "javascript",
    "jsdoc",
    "json",
    "json5",
    "just",
    "lua",
    "luadoc",
    "luap",
    "markdown",
    "markdown_inline",
    "nix",
    "printf",
    "python",
    "query",
    "regex",
    "ron",
    "ruby",
    "rust",
    "sql",
    "terraform",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "xml",
    "yaml",
}

treesitter.install(ensure_installed)

-- Helm values files are plain YAML under a compound filetype (see options.lua).
vim.treesitter.language.register("yaml", "yaml.helm-values")

-- `vim.treesitter.start` clears 'syntax'. Vim's Ruby and shell indent scripts
-- read synID() to leave string and heredoc bodies alone, so without the regex
-- syntax underneath `=` reindents them and changes the string's value. These
-- filetypes keep it loaded; tree-sitter still owns the highlighting.
local regex_syntax_for_indent = { ruby = true, sh = true, bash = true }

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

        if pcall(vim.treesitter.start, buf, lang) and regex_syntax_for_indent[ft] then
            vim.bo[buf].syntax = "ON"
        end

        -- Use tree-sitter folds wherever the parser is available, falling
        -- back to the global `indent` method for filetypes without one.
        -- Skip filetypes that already set their own foldmethod in ftplugin
        -- (currently only markdown via after/ftplugin/markdown.lua).
        if ft ~= "markdown" then
            vim.api.nvim_buf_call(buf, function()
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
            end)
        end
    end,
})
