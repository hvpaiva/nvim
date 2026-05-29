-- General mappings ===========================================================
-- Edits, motions and quality-of-life mappings that enhance Vim defaults.

-- Paste in visual mode without overwriting the unnamed register with the
-- selection that was just replaced.
vim.keymap.set("x", "p", [["_dP]], { desc = "Paste over selection without yanking" })

-- Linewise paste above / below, with indent matching the surrounding context.
-- `:iput` is `:put` with auto-indent (`:h :iput`). Forces linewise paste even
-- when the register is character-wise. Useful for `yiw` → `]p` to drop the
-- word on a new line at the current indent level.
vim.keymap.set("n", "[p", '<Cmd>exe "iput! " . v:register<CR>', { desc = "Paste above (linewise, indented)" })
vim.keymap.set("n", "]p", '<Cmd>exe "iput " . v:register<CR>', { desc = "Paste below (linewise, indented)" })

-- In insert mode, send a real Esc so InsertLeave and abbreviations fire
-- (default <C-c> skips them).
vim.keymap.set("i", "<C-c>", "<Esc>", { desc = "Esc with InsertLeave" })

-- Clear search highlight from the last `/` or `?`.
vim.keymap.set("n", "<C-c>", ":nohl<CR>", { desc = "Clear search highlight", silent = true })

-- Indent / unindent while keeping the visual selection active.
vim.keymap.set("v", "<", "<gv", { desc = "Unindent and keep selection" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent and keep selection" })

-- Join the next line onto this one without the cursor jumping to the join point.
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines, keep cursor" })

-- Half-page scroll, then recenter the cursor line.
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half page down, recentered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half page up, recentered" })

-- Jump to next / previous search hit, recenter and open any fold around it.
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search hit, recentered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search hit, recentered" })

-- Disable arrow keys in normal mode to enforce hjkl muscle memory.
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- File explorer (oil.nvim, set up in plugins.lua). `-` opens the parent
-- directory of the current file; navigate up with `-`, into dirs with `<CR>`.
vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory" })

-- Leader mappings ============================================================
-- Convention: <Leader>{group}{action}. First key picks a semantic group
-- (Buffer, Explore, Find, Git, Other, Session, Training, Visits, Yank),
-- second key triggers the action.
-- Lowercase = global/regular scope; uppercase = local/heavy variant.

-- Helpers for compact declarations.
local nmap_leader = function(suffix, rhs, desc, opts)
    vim.keymap.set("n", "<leader>" .. suffix, rhs, vim.tbl_extend("force", { desc = desc }, opts or {}))
end
local xmap_leader = function(suffix, rhs, desc, opts)
    vim.keymap.set("x", "<leader>" .. suffix, rhs, vim.tbl_extend("force", { desc = desc }, opts or {}))
end

-- Text-editing operators. Common usage:
-- - `<Leader>d{motion}`   - delete into the black hole register (no yank)
-- - `<Leader>S`           - prefill substitute for the word under cursor
-- - `<Leader>y{i,a}{obj}` - yank a text object; cursor returns to its start

-- Delete into the black hole register (does not touch the unnamed register).
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Pre-fill a global, case-insensitive substitute for the word under the cursor.
-- Cursor lands on the replacement, ready to type the new text.
vim.keymap.set(
    "n",
    "<leader>S",
    [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
    { desc = "Substitute word under cursor" }
)

-- <leader>y{scope}{obj}: yank a text object and keep cursor + scroll where
-- they were before the operator ran.
-- Example: `<leader>yiw` yanks the inner word; cursor stays put.
local function yank_textobject(scope, obj)
    return function()
        local view = vim.fn.winsaveview()
        vim.cmd.normal({ "y" .. scope .. obj, bang = true })
        vim.fn.winrestview(view)
    end
end
for _, scope in ipairs({ "i", "a" }) do
    for _, obj in ipairs({
        "p",
        "s",
        "B",
        "w",
        "W",
        "(",
        "[",
        "{",
        "<",
        ")",
        "]",
        "}",
        ">",
        "b",
        "`",
        "q",
        "?",
        "t",
        "f",
        "F",
        "a",
    }) do
        vim.keymap.set(
            "n",
            "<leader>y" .. scope .. obj,
            yank_textobject(scope, obj),
            { desc = "Yank " .. scope .. obj .. " (keep cursor)" }
        )
    end
end

-- b is for 'Buffer'. Common usage:
-- - `<Leader>ba` - go to the alternate buffer
-- - `<Leader>bd` - delete buffer; preserves the window (mini.bufremove)
-- - `<Leader>bs` - new scratch (throwaway) buffer
-- Uppercase `bD` / `bW` force-close buffers with unsaved changes.
local new_scratch_buffer = function()
    vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end
nmap_leader("ba", "<Cmd>b#<CR>", "Alternate")
nmap_leader("bd", "<Cmd>lua MiniBufremove.delete()<CR>", "Delete")
nmap_leader("bD", "<Cmd>lua MiniBufremove.delete(0, true)<CR>", "Delete!")
nmap_leader("bs", new_scratch_buffer, "Scratch")
nmap_leader("bw", "<Cmd>lua MiniBufremove.wipeout()<CR>", "Wipeout")
nmap_leader("bW", "<Cmd>lua MiniBufremove.wipeout(0, true)<CR>", "Wipeout!")

-- e is for 'Explore' / 'Edit'. Common usage:
-- - `<Leader>ed` - open file explorer (oil) at cwd (`-` opens the file's dir)
-- - `<Leader>en` - show notification history
-- - `<Leader>eq` - toggle the quickfix list
-- - `<Leader>eQ` - toggle the location list
local toggle_quickfix = function()
    vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and "cclose" or "copen")
end
local toggle_loclist = function()
    vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and "lclose" or "lopen")
end

nmap_leader("ed", "<Cmd>Oil .<CR>", "Directory (cwd)")
nmap_leader("en", "<Cmd>lua MiniNotify.show_history()<CR>", "Notifications")
nmap_leader("eq", toggle_quickfix, "Quickfix list")
nmap_leader("eQ", toggle_loclist, "Location list")

-- f is for 'Find'. Common usage:
-- - `<Leader>ff` - find files; requires `ripgrep` for best performance
-- - `<Leader>fg` - find inside files (live grep); requires `ripgrep`
-- - `<Leader>fb` - pick from open buffers
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume the last picker
-- All these use `mini.pick` / `mini.extra`. See `:h MiniPick-overview`.
nmap_leader("f/", '<Cmd>Pick history scope="/"<CR>', '"/" history')
nmap_leader("f:", '<Cmd>Pick history scope=":"<CR>', '":" history')
nmap_leader("fa", '<Cmd>Pick git_hunks scope="staged"<CR>', "Added hunks (all)")
nmap_leader("fA", '<Cmd>Pick git_hunks path="%" scope="staged"<CR>', "Added hunks (buf)")
nmap_leader("fb", "<Cmd>Pick buffers<CR>", "Buffers")
nmap_leader("fc", "<Cmd>Pick git_commits<CR>", "Commits (all)")
nmap_leader("fC", '<Cmd>Pick git_commits path="%"<CR>', "Commits (buf)")
nmap_leader("fd", '<Cmd>Pick diagnostic scope="all"<CR>', "Diagnostic workspace")
nmap_leader("fD", '<Cmd>Pick diagnostic scope="current"<CR>', "Diagnostic buffer")
nmap_leader("ff", "<Cmd>Pick files<CR>", "Files")
nmap_leader("fg", "<Cmd>Pick grep_live<CR>", "Grep live")
nmap_leader("fG", '<Cmd>Pick grep pattern="<cword>"<CR>', "Grep current word")
nmap_leader("fh", "<Cmd>Pick help<CR>", "Help")
nmap_leader("fH", "<Cmd>Pick hl_groups<CR>", "Highlight groups")
nmap_leader("fk", "<Cmd>Pick keymaps<CR>", "Keymaps")
nmap_leader("fl", '<Cmd>Pick buf_lines scope="all"<CR>', "Lines (all)")
nmap_leader("fL", '<Cmd>Pick buf_lines scope="current"<CR>', "Lines (buf)")
nmap_leader("fm", "<Cmd>Pick git_hunks<CR>", "Modified hunks (all)")
nmap_leader("fM", '<Cmd>Pick git_hunks path="%"<CR>', "Modified hunks (buf)")
nmap_leader("fr", "<Cmd>Pick resume<CR>", "Resume last picker")
nmap_leader("fR", '<Cmd>Pick lsp scope="references"<CR>', "References (LSP)")
nmap_leader("fs", '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>', "Symbols workspace (live)")
nmap_leader("fS", '<Cmd>Pick lsp scope="document_symbol"<CR>', "Symbols document")
nmap_leader("ft", "<Cmd>TodoQuickFix<CR>", "Todo quickfix")
nmap_leader("fv", '<Cmd>Pick visit_paths cwd=""<CR>', "Visit paths (all)")
nmap_leader("fV", "<Cmd>Pick visit_paths<CR>", "Visit paths (cwd)")

-- g is for 'Git'. Common usage:
-- - `<Leader>gg` - open Fugitive in a full-page tab (status view)
-- - `<Leader>gc` - git commit
-- - `<Leader>gd` - git diff (workspace patch in a buffer)
-- - `<Leader>gv` - vertical side-by-side diff of the current buffer
-- - `<Leader>go` - toggle inline diff overlay (mini.diff)
-- - `<Leader>gl` - git log (oneline custom format)
-- Powered by `vim-fugitive` + `mini.diff`. Lowercase = workspace; uppercase = current buffer.
local git_log_cmd = [[<cmd>Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order<CR>]]
local git_log_buf_cmd = [[<cmd>Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order --follow -- %<CR>]]

nmap_leader("ga", "<cmd>Git diff --cached<CR>", "Added diff")
nmap_leader("gA", "<cmd>Git diff --cached -- %<CR>", "Added diff (buf)")
nmap_leader("gc", "<cmd>Git commit<CR>", "Commit")
nmap_leader("gC", "<cmd>Git commit --amend<CR>", "Commit amend")
nmap_leader("gd", "<cmd>Git diff<CR>", "Diff")
nmap_leader("gD", "<cmd>Git diff -- %<CR>", "Diff (buf)")
nmap_leader("gg", "<cmd>tabnew | Git | only<cr>", "Fugitive full page")
nmap_leader("gl", git_log_cmd, "Log")
nmap_leader("gL", git_log_buf_cmd, "Log (buf)")
nmap_leader("go", "<cmd>lua MiniDiff.toggle_overlay()<CR>", "Toggle diff overlay")
nmap_leader("gv", "<cmd>Gvdiffsplit<CR>", "Visual diff split")

-- LSP extras that do not have a Neovim default (`:h lsp-defaults`). All other
-- LSP actions go through native keys: K, grn, gra, grr, gri, grt, gO, <C-]>,
-- <C-w>d. Motion-based formatting works through `gq{motion}` because
-- formatexpr is wired to conform in plugins.lua.
-- - `gK` - signature help (pairs with K = hover)
-- - `gl` - run code lens at cursor
-- - `gQ` - format the whole buffer via conform (overrides Ex mode)
vim.keymap.set("n", "gK", function()
    vim.lsp.buf.signature_help()
end, { desc = "Signature help" })
vim.keymap.set("n", "gl", function()
    vim.lsp.codelens.run()
end, { desc = "Run code lens" })
vim.keymap.set("n", "gQ", function()
    require("conform").format({ async = true })
end, { desc = "Format buffer" })

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle window zoom (focus current pane fullscreen)
-- - `<Leader>ou` - toggle undotree.vim
-- - `<Leader>os` - toggle spelling for the current buffer/window
-- - `<Leader>oc` - chmod +x the current file
-- - `<Leader>oh` - toggle LSP inlay hints in the current buffer
-- - `<Leader>om` - toggle render-markdown in-buffer rendering
-- - `<Leader>oR` - restart Neovim with the new config (`:restart`)
local function toggle_inlay_hints()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
    vim.notify("inlay hints " .. (not enabled and "on" or "off"))
end

nmap_leader("oc", "<cmd>!chmod +x %<CR>", "Make file executable", { silent = true })
nmap_leader("oh", toggle_inlay_hints, "Toggle inlay hints")
nmap_leader("om", "<cmd>RenderMarkdown toggle<CR>", "Toggle markdown render")
nmap_leader("oR", "<cmd>restart<cr>", "Restart Neovim")
nmap_leader("os", "<cmd>setlocal spell!<CR>", "Toggle spelling")
nmap_leader("ou", "<cmd>UndotreeToggle<CR>", "Toggle undotree")
nmap_leader("oz", "<cmd>lua MiniMisc.zoom()<CR>", "Zoom toggle")

-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - new session (prompts for a name)
-- - `<Leader>sr` - read a saved session (picker)
-- - `<Leader>sw` - overwrite the current session file
-- - `<Leader>sR` - restart Neovim preserving the current session
-- - `<Leader>sd` - delete a session (picker)
-- Sessions are stored under `~/.local/share/nvim/sessions/`.
nmap_leader("sd", '<cmd>lua MiniSessions.select("delete")<CR>', "Delete")
nmap_leader("sn", function()
    vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)
end, "New")
nmap_leader("sr", '<cmd>lua MiniSessions.select("read")<CR>', "Read")
nmap_leader("sR", "<cmd>lua MiniSessions.restart()<CR>", "Restart (keep session)")
nmap_leader("sw", "<cmd>lua MiniSessions.write()<CR>", "Write current")

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - mark current file with the "core" label
-- - `<Leader>vV` - remove the "core" label
-- - `<Leader>vC` - pick from "core" files in the current project (cwd)
-- - `<Leader>vc` - pick from "core" files across all projects
-- - `<Leader>vl` / `vL` - add / remove a custom label (prompts for name)
-- Differs from `fv`/`fV`: those pick from all visited paths (auto-ranked),
-- these pick from your explicitly curated "core" shortlist.
local make_pick_core = function(cwd, desc)
    return function()
        local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
        local local_opts = { cwd = cwd, filter = "core", sort = sort_latest }
        MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
    end
end
nmap_leader("vc", make_pick_core("", "Core visits (all)"), "Core visits (all)")
nmap_leader("vC", make_pick_core(nil, "Core visits (cwd)"), "Core visits (cwd)")
nmap_leader("vv", '<cmd>lua MiniVisits.add_label("core")<CR>', 'Add "core" label')
nmap_leader("vV", '<cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader("vl", "<cmd>lua MiniVisits.add_label()<CR>", "Add label")
nmap_leader("vL", "<cmd>lua MiniVisits.remove_label()<CR>", "Remove label")
