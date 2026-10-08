-- Ruby buffer-local mappings and indent style.

-- treesj knows Ruby's blocks (`{ |x| }` <-> `do |x| end`), modifier
-- conditionals (`x if y` <-> `if y ... end`) and literals; mini.splitjoin keeps
-- `gS` in every other filetype. Its first use sets it up: split hashes and
-- arrays end without a comma, as Standard and RuboCop's default want, and its
-- own keymaps stay off.
vim.keymap.set("n", "gS", function()
    local first = not package.loaded.treesj
    local treesj = require("treesj")
    if first then
        local no_trailing_comma = { split = { last_separator = false } }
        treesj.setup({
            use_default_keymaps = false,
            langs = { ruby = { array = no_trailing_comma, hash = no_trailing_comma } },
        })
    end
    treesj.toggle()
end, { buffer = true, desc = "Split/join (tree-sitter)" })

vim.keymap.set("n", "<Leader>fp", function()
    require("ruby_tools").pick_gems()
end, { buffer = true, desc = "Project gems (ruby-lsp)" })

-- vim-ruby maps the tag keys to `:tag <word>`, a by-name search through
-- vim.lsp.tagfunc; unmapped, they jump to ruby-lsp's definition at the cursor.
for _, lhs in ipairs({ "<C-]>", "g<C-]>", "g]", "<C-W>]", "<C-W><C-]>", "<C-W>g<C-]>", "<C-W>g]", "<C-W>}", "<C-W>g}" }) do
    pcall(vim.keymap.del, "n", lhs, { buffer = true })
end

-- vim-ruby's class objects follow syntax groups and stop at the wrong class
-- in nested code; its keys select mini.ai's tree-sitter class instead.
for _, scope in ipairs({ "a", "i" }) do
    vim.keymap.set({ "x", "o" }, scope .. "M", scope .. "c", { buffer = true, remap = true, desc = "Class" })
end

-- vim-ruby's indent settings are global and read on every indent, so the
-- current buffer's style picks them: its defaults are RuboCop's, and Standard
-- indents continuation lines and `x = if` bodies from the start of the line.
local function indent_style(bufnr)
    local standard = require("ruby_tools").style(vim.api.nvim_buf_get_name(bufnr)) == "standard"
    vim.g.ruby_indent_assignment_style = standard and "variable" or "hanging"
    vim.g.ruby_indent_hanging_elements = standard and 0 or 1
end
indent_style(0)
local indent_group = vim.api.nvim_create_augroup("hvpaiva-ruby-indent", { clear = false })
vim.api.nvim_clear_autocmds({ group = indent_group, buffer = 0 })
vim.api.nvim_create_autocmd("BufEnter", {
    group = indent_group,
    buffer = 0,
    callback = function(ev)
        indent_style(ev.buf)
    end,
})
