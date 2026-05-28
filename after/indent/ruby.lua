-- Use tree-sitter indent for Ruby. The runtime `GetRubyIndent` reads the
-- current line's text to decide indent, so a blank line inside `do...end`
-- evaluates to 0 and `<CR>` (or `cc`) lands the cursor at column 1.
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
