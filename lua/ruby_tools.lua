-- Ruby project tooling shared by formatting (conform), linting (ruby-lsp or
-- nvim-lint), ruby-lsp's test code lenses and debugging.
local M = {}

function M.bundle_root(filename)
    return vim.fs.root(filename, { "Gemfile", "gems.rb" })
end

--- Gems a bundle resolves (`all`, the 4-space `specs` entries) and the ones its
--- Gemfile names directly (`direct`, the DEPENDENCIES section). nil when the
--- bundle has no lockfile yet.
---@param root string
---@return { all: table<string, true>, direct: table<string, true> }?
function M.lock(root)
    local path = root .. (vim.fn.filereadable(root .. "/Gemfile") == 1 and "/Gemfile.lock" or "/gems.locked")
    if vim.fn.filereadable(path) == 0 then
        return nil
    end
    local all, direct, section = {}, {}, nil
    for _, line in ipairs(vim.fn.readfile(path)) do
        if line:match("^%u") then
            section = line
        end
        local spec = line:match("^    ([%w_.-]+) %(")
        if spec then
            all[spec] = true
        elseif section == "DEPENDENCIES" then
            local dep = line:match("^  ([%w_.-]+)")
            if dep then
                direct[dep] = true
            end
        end
    end
    return { all = all, direct = direct }
end

local function depends_on_rubocop(lock)
    for name in pairs(lock.direct) do
        if name:match("^rubocop") then
            return true
        end
    end
    return false
end

local function find_up(names, filename)
    return vim.fs.find(names, { upward = true, path = vim.fs.dirname(filename) })[1]
end

--- The style a Ruby file follows: an explicit config file wins, then what the
--- bundle depends on, then Standard (the modern default).
---@param filename string
---@return "standard"|"rubocop"
function M.style(filename)
    if find_up({ ".standard.yml", "standard.yml" }, filename) then
        return "standard"
    end
    if find_up({ ".rubocop.yml", ".rubocop_todo.yml", "rubocop.yml" }, filename) then
        return "rubocop"
    end
    local root = M.bundle_root(filename)
    local lock = root and M.lock(root)
    if lock then
        if lock.direct.standard then
            return "standard"
        end
        if depends_on_rubocop(lock) then
            return "rubocop"
        end
    end
    return "standard"
end

--- How a Ruby file is linted, following its style. ruby-lsp lints when the
--- bundle carries the tool: `linters` goes into its init_options (nil keeps
--- ruby-lsp's own detection, which finds RuboCop). Otherwise `editor` names the
--- tool nvim-lint runs instead, and `linters = {}` keeps ruby-lsp from linting
--- a Standard project with RuboCop's defaults.
---@param filename string
---@return { linters: string[]?, editor: ("standardrb"|"rubocop")? }
function M.lint_plan(filename)
    local root = M.bundle_root(filename)
    local lock = root and M.lock(root)
    if M.style(filename) == "standard" then
        if lock and lock.all.standard then
            return { linters = { "standard" } }
        end
        return { linters = {}, editor = "standardrb" }
    end
    -- Mirrors ruby-lsp's GlobalState#detect_linters.
    if lock and (depends_on_rubocop(lock) or (lock.all.rubocop and vim.uv.fs_stat(root .. "/.rubocop.yml"))) then
        return {}
    end
    return { linters = {}, editor = "rubocop" }
end

-- The project's binstub, then `bundle exec` when the lockfile has the gem, then
-- the tool on PATH. Returns command, leading args, working directory.
local function resolve(filename, executable, gem)
    local root = M.bundle_root(filename)
    if root then
        local binstub = root .. "/bin/" .. executable
        if vim.fn.executable(binstub) == 1 then
            return binstub, {}, root
        end
        local lock = M.lock(root)
        if lock and lock.all[gem] then
            return "bundle", { "exec", executable }, root
        end
    end
    return executable, {}, root or vim.fs.dirname(filename)
end

-- `rubocop --server` (conform's and nvim-lint's default) leaves a daemon per
-- project that outlives the editor. Each one started from here is stopped on
-- exit; the next run starts it again, so stopping one another editor still
-- uses only costs that editor a cold start.
local servers = {}

local function track_server(command, args, cwd)
    local argv = vim.list_extend({ command }, args)
    servers[table.concat(argv, "\0") .. "\0" .. cwd] = { argv = argv, cwd = cwd }
end

--- Daemons this session started, as { argv, cwd } (for tests).
function M.servers()
    return vim.tbl_values(servers)
end

function M.stop_servers()
    for _, server in pairs(servers) do
        local argv = vim.list_extend(vim.deepcopy(server.argv), { "--stop-server" })
        pcall(vim.system, argv, { cwd = server.cwd, detach = true })
    end
    servers = {}
end

--- conform formatter spec for a Ruby formatter resolved per buffer.
function M.formatter(executable, gem)
    return {
        command = function(_, ctx)
            local command, args, cwd = resolve(ctx.filename, executable, gem)
            if executable == "rubocop" then
                track_server(command, args, cwd)
            end
            return command
        end,
        prepend_args = function(_, ctx)
            local _, args = resolve(ctx.filename, executable, gem)
            return args
        end,
        cwd = function(_, ctx)
            local _, _, cwd = resolve(ctx.filename, executable, gem)
            return cwd
        end,
    }
end

--- conform's formatter list for a Ruby buffer.
function M.formatters(bufnr)
    return { M.style(vim.api.nvim_buf_get_name(bufnr)) == "standard" and "standardrb" or "rubocop" }
end

-- RuboCop and Standard exit 1 both when they find offenses and when they
-- fail (a broken config, a gem that will not load), so the status tells
-- nothing: nvim-lint would report "exited with code: 1" on every file with an
-- offense, and its rubocop linter ignores the status, which hides failures.
-- What tells them apart is the output: a run that worked prints the JSON
-- report. Read stdout and stderr together, pick the report line, and fail the
-- parse without one, which nvim-lint shows as an error on the first line
-- carrying the tool's own message.
local function report(output)
    for line in output:gmatch("[^\n]+") do
        if line:match('^{"metadata"') then
            return line
        end
    end
    error("no report from the linter", 0)
end

--- nvim-lint linter for `name` ("standardrb" or "rubocop"), resolved for the
--- current buffer the same way the formatter is.
function M.linter(name)
    local gem = name == "standardrb" and "standard" or name
    return function()
        local base = require("lint.linters." .. name)
        local command, prefix, cwd = resolve(vim.api.nvim_buf_get_name(0), name, gem)
        if name == "rubocop" then
            track_server(command, prefix, cwd)
        end
        return vim.tbl_extend("force", base, {
            cmd = command,
            args = vim.list_extend(vim.deepcopy(prefix), base.args),
            ignore_exitcode = true,
            stream = "both",
            -- nvim-lint's standardrb parser leaves `source` empty; label both
            -- like ruby-lsp labels its RuboCop diagnostics.
            parser = function(output, ...)
                local diagnostics = base.parser(report(output), ...)
                for _, diagnostic in ipairs(diagnostics) do
                    diagnostic.source = diagnostic.source or name
                end
                return diagnostics
            end,
        })
    end
end

-- ruby-lsp marks every test and group with "Run", "Run In Terminal" and
-- "Debug" code lenses whose commands the client implements. Their arguments
-- are { path, id, command, location, name }: `command` is the shell line that
-- runs that one test, `location` its 0-based line span.
local function lens_test(cmd)
    local args = cmd.arguments or {}
    local path = args[1]
    return {
        path = path,
        command = args[3],
        location = args[4],
        name = args[5] or args[2],
        root = path and (M.bundle_root(path) or vim.fs.dirname(path)),
    }
end

--- Runs a test lens in the same sticky terminal as `<Leader>t`.
function M.run_test_lens(cmd)
    local test = lens_test(cmd)
    if not test.command then
        vim.notify("ruby-lsp test lens without a command", vim.log.levels.ERROR)
        return
    end
    require("lenses").run_in_test_terminal(test.command, test.root)
end

--- nvim-dap configuration debugging the test a lens names (the `ruby` adapter
--- runs `command` under rdbg).
function M.debug_test_config(cmd)
    local test = lens_test(cmd)
    return {
        name = "Ruby: " .. tostring(test.name),
        type = "ruby",
        request = "attach",
        command = test.command,
        cwd = test.root,
        localfs = true,
    }
end

function M.debug_test_lens(cmd)
    require("dap").run(M.debug_test_config(cmd))
end

--- The "Debug" lens command of the innermost test or group around `row`
--- (0-based), from a textDocument/codeLens result.
function M.nearest_debug_lens(lenses, row)
    local best
    for _, lens in ipairs(lenses or {}) do
        local cmd = lens.command
        local location = cmd and cmd.command == "rubyLsp.debugTest" and lens_test(cmd).location
        if
            location
            and location.start_line <= row
            and row <= location.end_line
            and (not best or location.start_line > lens_test(best).location.start_line)
        then
            best = cmd
        end
    end
    return best
end

--- mini.pick items for ruby-lsp's `rubyLsp/workspace/dependencies` answer:
--- the bundle's gems, direct dependencies first.
function M.gem_items(gems)
    local items = {}
    for _, gem in ipairs(gems or {}) do
        items[#items + 1] = {
            text = ("%s %s%s"):format(gem.name, gem.version, gem.dependency and "" or "  (transitive)"),
            path = gem.path,
            direct = gem.dependency,
        }
    end
    table.sort(items, function(a, b)
        if a.direct ~= b.direct then
            return a.direct
        end
        return a.text < b.text
    end)
    return items
end

--- Picks one of the project's gems and opens its directory in oil.
function M.pick_gems()
    local client = vim.lsp.get_clients({ bufnr = 0, name = "ruby_lsp" })[1]
    if not client then
        vim.notify("ruby-lsp is not attached to this buffer", vim.log.levels.WARN)
        return
    end
    client:request("rubyLsp/workspace/dependencies", vim.empty_dict(), function(err, gems)
        if err then
            vim.notify("ruby-lsp dependencies: " .. err.message, vim.log.levels.ERROR)
            return
        end
        MiniPick.start({
            source = {
                name = "Gems",
                items = M.gem_items(gems),
                choose = function(item)
                    vim.schedule(function()
                        require("oil").open(item.path)
                    end)
                end,
            },
        })
    end)
end

function M.debug_nearest_test()
    local bufnr = vim.api.nvim_get_current_buf()
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = "ruby_lsp" })[1]
    if not client then
        vim.notify("ruby-lsp is not attached to this buffer", vim.log.levels.WARN)
        return
    end
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
    client:request("textDocument/codeLens", params, function(err, lenses)
        if err then
            vim.notify("ruby-lsp code lens: " .. err.message, vim.log.levels.ERROR)
            return
        end
        local cmd = M.nearest_debug_lens(lenses, row)
        if cmd then
            M.debug_test_lens(cmd)
        else
            vim.notify("No test around the cursor", vim.log.levels.WARN)
        end
    end, bufnr)
end

return M
