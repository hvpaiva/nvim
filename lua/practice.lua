local M = {}

M.source = vim.fn.stdpath("config") .. "/practice"
M.copy = vim.fn.stdpath("state") .. "/practice"

local function run(argv, cwd)
    local result = vim.system(argv, { cwd = cwd, text = true }):wait()
    if result.code ~= 0 then
        error(table.concat(argv, " ") .. ": " .. vim.trim(result.stderr or ""), 0)
    end
end

local function inside(path, dir)
    return path == dir or vim.startswith(path, dir .. "/")
end

local function reload_buffers(copy)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if inside(name, copy) then
            if not vim.uv.fs_stat(name) then
                vim.api.nvim_buf_delete(buf, { force = true })
            elseif vim.api.nvim_buf_is_loaded(buf) then
                vim.api.nvim_buf_call(buf, function()
                    vim.cmd("edit!")
                end)
            end
        end
    end
end

function M.create(copy)
    local cwd = vim.fn.getcwd()
    if vim.fn.isdirectory(copy) == 1 and vim.fn.delete(copy, "rf") ~= 0 then
        error("Could not remove " .. copy, 0)
    end
    vim.fn.mkdir(vim.fs.dirname(copy), "p")
    run({ "cp", "-R", M.source, copy })
    run({ "git", "init", "--quiet" }, copy)
    run({ "git", "add", "--all" }, copy)
    run({ "git", "-c", "commit.gpgsign=false", "commit", "--quiet", "--message", "Start the practice" }, copy)
    if inside(cwd, copy) then
        vim.fn.chdir(vim.fn.isdirectory(cwd) == 1 and cwd or copy)
    end
    reload_buffers(copy)
end

function M.open(opts)
    opts = opts or {}
    local copy = opts.copy or M.copy
    if opts.reset or vim.fn.isdirectory(copy) == 0 then
        M.create(copy)
    end
    vim.cmd.edit(vim.fn.fnameescape(copy .. "/00_README.md"))
end

vim.api.nvim_create_user_command("Practice", function(opts)
    M.open({ reset = opts.bang })
end, { bang = true, desc = "Open the practice files, or a fresh copy of them with !" })

return M
