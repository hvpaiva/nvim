-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- In visual mode, J moves the selected block one line DOWN, keeps selection, and reindents
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move block [J] down' })

-- In visual mode, K moves the selected block one line UP, keeps selection, and reindents
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move block [K] up' })

-- Join lines but preserve cursor position by marking it and jumping back afterward
vim.keymap.set('n', 'J', 'mzJ`z', { desc = '[J]oin lines keeping cursor' })

-- Half-page down and recenter the cursor line
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Page down and center' })

-- Half-page up and recenter the cursor line
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Page up and center' })

-- Next search result, then recenter and open folds if needed
vim.keymap.set('n', 'n', 'nzzzv', { desc = '[n]ext search result (centered)' })

-- Previous search result, then recenter and open folds if needed
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Prev search result (centered)' })

-- Reindent the paragraph text object around cursor (=ap) and return to the original line using mark 'a
vim.keymap.set('n', '=ap', "ma=ap'a", { desc = 'Reindent [a]round [p]aragraph' })

-- Paste over selection without overwriting the unnamed register (use black hole register)
vim.keymap.set('x', '<leader>p', [["_dP]], { desc = '[p]aste without yanking' })

-- Yank to the system clipboard in normal/visual modes
vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]], { desc = '[y]ank to system clipboard' })

-- Yank the entire line to the system clipboard
vim.keymap.set('n', '<leader>Y', [["+Y]], { desc = '[Y]ank line to system clipboard' })

-- Delete to the black hole register (do not clobber the unnamed register)
vim.keymap.set({ 'n', 'v' }, '<leader>d', '"_d', { desc = '[d]elete without yanking' })

-- Make <C-c> behave like <Esc> in insert mode (exit to normal mode)
vim.keymap.set('i', '<C-c>', '<Esc>', { desc = 'Map <C-c> as <Esc>' })

-- Prepare a global, case-insensitive substitution of the WORD under cursor; leave cursor before flags to edit
vim.keymap.set('n', '<leader>S', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = '[S]ubstitute current word' })

-- Make the current file executable (chmod +x %) without noise
vim.keymap.set('n', '<leader>x', '<cmd>!chmod +x %<CR>', { silent = true, desc = 'Make file e[x]ecutable' })

-- Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- vim: ts=2 sts=2 sw=2 et
