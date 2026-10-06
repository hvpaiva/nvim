-- A REPL in a terminal split, fed from the buffer: irb for Ruby and python3
-- for Python (both under the project's toolchain through `mise exec`), the
-- matching shell for shell scripts. One REPL per command and project root.
-- Text goes in as a bracketed paste, so a multi-line block arrives whole
-- instead of each line being run (and re-indented) as it is typed.
--   <Leader>ii  open or show the REPL      <Leader>il  send the line
--   <Leader>ip  send the paragraph         <Leader>i   send the selection (visual)
local M = {}

local programs = {
    ruby = { "irb" },
    python = { "python3" },
    sh = { "bash" },
    bash = { "bash" },
    zsh = { "zsh" },
}

local roots = { "Gemfile", "pyproject.toml", ".git" }

local repls = {}

--- The command and working directory of the REPL for the current buffer.
function M.target()
    local program = programs[vim.bo.filetype] or { vim.o.shell }
    local managed = vim.bo.filetype == "ruby" or vim.bo.filetype == "python"
    local cmd = managed and vim.fn.executable("mise") == 1 and vim.list_extend({ "mise", "exec", "--" }, program)
        or program
    local name = vim.api.nvim_buf_get_name(0)
    local cwd = vim.fs.root(0, roots) or (name ~= "" and vim.fs.dirname(name)) or vim.fn.getcwd()
    return cmd, cwd
end

local function alive(repl)
    return repl and vim.api.nvim_buf_is_valid(repl.buf) and vim.fn.jobwait({ repl.job }, 0)[1] == -1
end

local function show(repl)
    if vim.fn.bufwinid(repl.buf) == -1 then
        vim.cmd("botright 12split")
        vim.api.nvim_win_set_buf(0, repl.buf)
        vim.cmd.wincmd("p")
    end
end

--- The REPL for the current buffer, started if needed and shown.
function M.ensure()
    local cmd, cwd = M.target()
    local key = table.concat(cmd, " ") .. "\0" .. cwd
    local repl = repls[key]
    if not alive(repl) then
        vim.cmd("botright 12split")
        vim.cmd.enew()
        local buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].bufhidden = "hide"
        repl = { buf = buf, job = vim.fn.jobstart(cmd, { term = true, cwd = cwd }) }
        repls[key] = repl
        vim.cmd.wincmd("p")
    end
    show(repl)
    return repl
end

--- Sends `lines` to the REPL and runs them.
function M.send(lines)
    if #lines == 0 then
        return
    end
    local repl = M.ensure()
    vim.fn.chansend(repl.job, "\27[200~" .. table.concat(lines, "\n") .. "\27[201~\r")
end

--- The blank-line-delimited block around `row` (1-based) of the current buffer.
function M.paragraph(row)
    local last = vim.api.nvim_buf_line_count(0)
    local function blank(n)
        return not vim.fn.getline(n):match("%S")
    end
    if blank(row) then
        return {}
    end
    local first, final = row, row
    while first > 1 and not blank(first - 1) do
        first = first - 1
    end
    while final < last and not blank(final + 1) do
        final = final + 1
    end
    return vim.api.nvim_buf_get_lines(0, first - 1, final, false)
end

local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

map("n", "<Leader>ii", M.ensure, "Open REPL")
map("n", "<Leader>il", function()
    M.send({ vim.api.nvim_get_current_line() })
end, "Send line to REPL")
map("n", "<Leader>ip", function()
    M.send(M.paragraph(vim.fn.line(".")))
end, "Send paragraph to REPL")
map("x", "<Leader>i", function()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    M.send(lines)
end, "Send selection to REPL")

return M
