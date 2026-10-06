-- rust-analyzer's "Run" and "Debug" code lenses carry client-side commands
-- whose argument is a runnable: { label, kind = "cargo", args = { cargoArgs,
-- executableArgs, cwd, environment, overrideCargo } }, or kind = "shell" with
-- args = { program, args, cwd, environment }. JSON nulls arrive as vim.NIL.
local M = {}

local function value(x)
    if x == vim.NIL then
        return nil
    end
    return x
end

local function runnable(cmd)
    local r = (cmd.arguments or {})[1] or {}
    return r, r.args or {}
end

local function environment(args)
    local env = {}
    for key, val in pairs(value(args.environment) or {}) do
        env[key] = value(val)
    end
    return env
end

--- argv that runs a runnable (cargo: `cargo <cargoArgs> -- <executableArgs>`).
function M.argv(cmd)
    local r, args = runnable(cmd)
    if r.kind == "shell" then
        return vim.list_extend({ args.program }, vim.deepcopy(value(args.args) or {}))
    end
    local argv = vim.list_extend({ value(args.overrideCargo) or "cargo" }, vim.deepcopy(value(args.cargoArgs) or {}))
    local executable_args = value(args.executableArgs) or {}
    if #executable_args > 0 then
        argv[#argv + 1] = "--"
        vim.list_extend(argv, executable_args)
    end
    return argv
end

--- The shell line for a runnable, with its environment in front.
function M.command_line(cmd)
    local _, args = runnable(cmd)
    local assignments = {}
    for key, val in pairs(environment(args)) do
        assignments[#assignments + 1] = key .. "=" .. vim.fn.shellescape(val)
    end
    table.sort(assignments)
    local line = table.concat(vim.tbl_map(vim.fn.shellescape, M.argv(cmd)), " ")
    return #assignments > 0 and table.concat(assignments, " ") .. " " .. line or line
end

function M.run(cmd)
    local _, args = runnable(cmd)
    require("lenses").run_in_test_terminal(M.command_line(cmd), value(args.cwd) or vim.fn.getcwd())
end

--- The cargo invocation that builds a runnable's binary without running it,
--- printing the artifacts as JSON (`cargo test --no-run`, `cargo build`).
function M.build_argv(cmd)
    local _, args = runnable(cmd)
    local cargo_args = vim.deepcopy(value(args.cargoArgs) or {})
    if cargo_args[1] == "test" then
        table.insert(cargo_args, 2, "--no-run")
    elseif cargo_args[1] == "run" then
        cargo_args[1] = "build"
    end
    local argv = vim.list_extend({ value(args.overrideCargo) or "cargo" }, cargo_args)
    argv[#argv + 1] = "--message-format=json"
    return argv
end

--- The last executable cargo reported building, from its JSON messages.
function M.executable(stdout)
    local program
    for line in stdout:gmatch("[^\n]+") do
        local ok, message = pcall(vim.json.decode, line)
        if ok and type(message) == "table" and message.reason == "compiler-artifact" then
            program = value(message.executable) or program
        end
    end
    return program
end

--- Builds the runnable's binary, then debugs it with codelldb (the same
--- adapter as `<Leader>rr` on Rust).
function M.debug(cmd)
    local r, args = runnable(cmd)
    if r.kind ~= "cargo" then
        vim.notify("Debug lens: only cargo runnables are supported", vim.log.levels.WARN)
        return
    end
    local cwd = value(args.cwd) or vim.fn.getcwd()
    local env = environment(args)
    vim.notify("Building " .. tostring(r.label) .. " for debugging")
    vim.system(M.build_argv(cmd), { cwd = cwd, env = env, text = true }, function(result)
        vim.schedule(function()
            local program = result.code == 0 and M.executable(result.stdout or "")
            if not program then
                local reason = result.code ~= 0 and vim.trim(result.stderr or ""):match("[^\n]*$")
                    or "no executable built"
                vim.notify("Debug lens: " .. reason, vim.log.levels.ERROR)
                return
            end
            require("dap").run({
                name = tostring(r.label),
                type = "codelldb",
                request = "launch",
                program = program,
                args = value(args.executableArgs) or {},
                cwd = cwd,
                env = env,
            })
        end)
    end)
end

return M
