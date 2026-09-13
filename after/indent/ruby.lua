-- GetRubyIndent reads synID() to skip keywords inside strings/comments.
-- Tree-sitter highlighting leaves synID() empty, so indent collapses to
-- column 0. Load legacy syntax to feed synID(); tree-sitter still highlights.
vim.bo.syntax = "ruby"
