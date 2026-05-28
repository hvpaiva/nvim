-- Use tree-sitter indent for Ruby. The runtime `GetRubyIndent` reads the
-- current line's text to decide indent, so a blank line inside `do...end`
-- evaluates to 0 and `<CR>` (or `cc`) lands the cursor at column 1.
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

-- The runtime indent script re-triggers on `.` and `:` to realign method
-- chains and hash literals. Tree-sitter evaluates a partial parse tree on
-- each keystroke and can snap the line back a level mid-typing, so drop
-- both triggers; `end`, `else`, `}`, `)`, `]` are still in `indentkeys`.
vim.opt_local.indentkeys:remove({ ".", ":" })
