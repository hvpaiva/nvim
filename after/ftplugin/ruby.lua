-- Ruby buffer-local mappings.

-- treesj knows Ruby's blocks (`{ |x| }` <-> `do |x| end`), modifier
-- conditionals (`x if y` <-> `if y ... end`) and literals; mini.splitjoin keeps
-- `gS` in every other filetype.
vim.keymap.set("n", "gS", function()
    require("treesj").toggle()
end, { buffer = true, desc = "Split/join (tree-sitter)" })

vim.keymap.set("n", "<Leader>fp", function()
    require("ruby_tools").pick_gems()
end, { buffer = true, desc = "Project gems (ruby-lsp)" })
