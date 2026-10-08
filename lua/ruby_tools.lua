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
-- the tool on PATH, under the Ruby the project selects (`mise x` from its
-- directory, as for ruby-lsp). Returns command, leading args, working
-- directory.
local function resolve(filename, executable, gem)
    local root = M.bundle_root(filename)
    local argv = { executable }
    if root then
        local binstub = root .. "/bin/" .. executable
        if vim.fn.executable(binstub) == 1 then
            argv = { binstub }
        else
            local lock = M.lock(root)
            if lock and lock.all[gem] then
                argv = { "bundle", "exec", executable }
            end
        end
    end
    if vim.fn.executable("mise") == 1 then
        argv = vim.list_extend({ "mise", "x", "--" }, argv)
    end
    return argv[1], vim.list_slice(argv, 2), root or vim.fs.dirname(filename)
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
--- `--fix-layout` limits it to the Layout cops: formatting changes whitespace
--- and line breaks, never the code (`$stderr.puts` to `warn`, a dropped
--- `return`); those corrections stay diagnostics.
function M.formatter(executable, gem)
    local layout_args = { "--fix-layout", "-f", "quiet", "--stderr", "--stdin", "$FILENAME" }
    if executable == "rubocop" then
        table.insert(layout_args, 1, "--server")
    end
    return {
        args = layout_args,
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

-- ruby-lsp's severities for RuboCop offenses, so a cop reads the same with or
-- without a bundle.
local severities = {
    info = vim.diagnostic.severity.HINT,
    refactor = vim.diagnostic.severity.INFO,
    convention = vim.diagnostic.severity.INFO,
    warning = vim.diagnostic.severity.WARN,
    error = vim.diagnostic.severity.ERROR,
    fatal = vim.diagnostic.severity.ERROR,
}

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
        local changedtick = vim.b.changedtick
        return vim.tbl_extend("force", base, {
            cmd = command,
            args = vim.list_extend(vim.deepcopy(prefix), base.args),
            ignore_exitcode = true,
            stream = "both",
            -- nvim-lint's standardrb parser leaves `source` empty; label both
            -- like ruby-lsp labels its RuboCop diagnostics. Each diagnostic
            -- also keeps `correctable` and the buffer's changedtick when it
            -- was linted, for the code actions below (both parsers keep the
            -- report's offense order).
            parser = function(output, ...)
                local json = report(output)
                local offenses = vim.tbl_get(vim.json.decode(json), "files", 1, "offenses") or {}
                local diagnostics = base.parser(json, ...)
                for i, diagnostic in ipairs(diagnostics) do
                    local offense = offenses[i] or {}
                    diagnostic.source = diagnostic.source or name
                    diagnostic.severity = severities[offense.severity] or diagnostic.severity
                    diagnostic.user_data = vim.tbl_extend("force", diagnostic.user_data or {}, {
                        correctable = offense.correctable or false,
                        changedtick = changedtick,
                    })
                end
                return diagnostics
            end,
        })
    end
end

-- ruby-lsp offers "Autocorrect" and "Disable for this line" on its own
-- diagnostics only. Files nvim-lint lints get the same actions from an
-- in-process server reading nvim-lint's diagnostics: a correction runs the
-- tool with `--only <cop>` on the buffer and keeps the changed hunks that
-- touch the offense, since neither tool can correct a single line.
local fix_tools = {
    standardrb = { gem = "standard", fix = { "--fix" }, directive = "standard" },
    rubocop = { gem = "rubocop", fix = { "--server", "-a" }, directive = "rubocop" },
}

local function text(lines)
    return #lines > 0 and table.concat(lines, "\n") .. "\n" or ""
end

-- The diff joins corrections on adjacent rows into one hunk. A hunk that
-- keeps its row count is split into one hunk per row, so correcting one
-- offense leaves its neighbors alone.
local function hunks(old, new)
    local split = {}
    for _, hunk in ipairs(vim.text.diff(text(old), text(new), { result_type = "indices" })) do
        local start_a, count_a, start_b, count_b = unpack(hunk)
        if count_a == count_b then
            for i = 0, count_a - 1 do
                split[#split + 1] = { start_a + i, 1, start_b + i, 1 }
            end
        else
            split[#split + 1] = hunk
        end
    end
    return split
end

--- LSP TextEdits turning the lines `old` into `new`. With `first` and `last`
--- (0-based rows) only the hunks touching those rows are kept.
---@param old string[]
---@param new string[]
---@param first integer?
---@param last integer?
---@return lsp.TextEdit[]
function M.hunk_edits(old, new, first, last)
    local edits = {}
    for _, hunk in ipairs(hunks(old, new)) do
        local start_a, count_a, start_b, count_b = unpack(hunk)
        -- start_a is 1-based, or the row a pure insertion goes after.
        local row = count_a == 0 and start_a or start_a - 1
        local touches = not first
            or (count_a == 0 and row >= first and row <= last + 1)
            or (count_a > 0 and row <= last and row + count_a - 1 >= first)
        local lines = vim.list_slice(new, start_b, start_b + count_b - 1)
        if touches and count_a == 0 and row == #old and row > 0 then
            -- Neovim reads an insertion past the last row as whole lines, so
            -- its trailing newline would leave an empty row: append to the
            -- last row instead (byte columns, see the server's encoding).
            local eol = { line = row - 1, character = #old[row] }
            edits[#edits + 1] = { range = { start = eol, ["end"] = eol }, newText = "\n" .. table.concat(lines, "\n") }
        elseif touches then
            edits[#edits + 1] = {
                range = { start = { line = row, character = 0 }, ["end"] = { line = row + count_a, character = 0 } },
                newText = text(lines),
            }
        end
    end
    return edits
end

--- The edit appending a `tool:disable cop` directive to `line` (row `row`),
--- or extending the directive already there.
---@param line string
---@param row integer
---@param tool "standardrb"|"rubocop"
---@param cop string
---@return lsp.TextEdit
function M.disable_edit(line, row, tool, cop)
    local directive = fix_tools[tool].directive .. ":disable"
    local extends = line:find("#%s*" .. directive .. "%s+[%w/_, ]+$")
    local position = { line = row, character = #line }
    return {
        range = { start = position, ["end"] = position },
        newText = extends and ", " .. cop or " # " .. directive .. " " .. cop,
    }
end

-- A comment appended to a row that ends inside a heredoc, or inside a literal
-- that goes on past the row, would become part of its text (or break the
-- heredoc's terminator).
local multiline_literals = { string = true, string_array = true, symbol_array = true, regex = true, subshell = true }

local function ends_in_literal(bufnr, row, line)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "ruby")
    if not ok or not parser then
        return false
    end
    parser:parse()
    local node =
        vim.treesitter.get_node({ bufnr = bufnr, pos = { row, math.max(#line - 1, 0) }, ignore_injections = true })
    while node do
        local kind = node:type()
        local _, _, end_row = node:range()
        if kind == "heredoc_body" or (multiline_literals[kind] and end_row > row) then
            return true
        end
        node = node:parent()
    end
    return false
end

local function lint_diagnostics(bufnr)
    local lint = require("lint")
    local diagnostics = {}
    for tool in pairs(fix_tools) do
        vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = lint.get_namespace("ruby_" .. tool) }))
    end
    return diagnostics
end

--- Code actions for the nvim-lint diagnostics of `bufnr` between rows
--- `first` and `last`: per offense linted from the current text, autocorrect
--- its cop (resolved later, it runs the tool) and disable it on its line;
--- then autocorrect everything.
---@return lsp.CodeAction[]
function M.code_actions(bufnr, first, last)
    local tool = M.lint_plan(vim.api.nvim_buf_get_name(bufnr)).editor
    if not tool then
        return {}
    end
    local uri = vim.uri_from_bufnr(bufnr)
    local actions, seen, correctable = {}, {}, false
    for _, diagnostic in ipairs(lint_diagnostics(bufnr)) do
        local cop = diagnostic.code
        local fixable = vim.tbl_get(diagnostic, "user_data", "correctable")
        local current = vim.tbl_get(diagnostic, "user_data", "changedtick") == vim.b[bufnr].changedtick
        correctable = correctable or fixable
        local key = ("%s:%d"):format(cop, diagnostic.lnum)
        if cop and current and not seen[key] and diagnostic.lnum <= last and diagnostic.end_lnum >= first then
            seen[key] = true
            if fixable then
                actions[#actions + 1] = {
                    title = "Autocorrect " .. cop,
                    kind = "quickfix",
                    data = { uri = uri, tool = tool, cop = cop, first = diagnostic.lnum, last = diagnostic.end_lnum },
                }
            end
            local line = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1] or ""
            if not ends_in_literal(bufnr, diagnostic.lnum, line) then
                actions[#actions + 1] = {
                    title = ("Disable %s for this line"):format(cop),
                    kind = "quickfix",
                    edit = { changes = { [uri] = { M.disable_edit(line, diagnostic.lnum, tool, cop) } } },
                }
            end
        end
    end
    if correctable then
        actions[#actions + 1] = {
            title = "Autocorrect all offenses",
            kind = "source.fixAll",
            data = { uri = uri, tool = tool },
        }
    end
    return actions
end

--- Fills in the edit of an action from `code_actions` by running its tool on
--- the buffer; `callback(err, action)` runs on the main loop.
function M.resolve_action(action, callback)
    local data = action.data
    if not data then
        callback(nil, action)
        return
    end
    local bufnr = vim.uri_to_bufnr(data.uri)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local spec = fix_tools[data.tool]
    local command, prefix, cwd = resolve(filename, data.tool, spec.gem)
    if data.tool == "rubocop" then
        track_server(command, prefix, cwd)
    end
    local argv = vim.list_extend({ command }, prefix)
    vim.list_extend(argv, spec.fix)
    if data.cop then
        vim.list_extend(argv, { "--only", data.cop })
    end
    vim.list_extend(argv, { "-f", "quiet", "--stderr", "--stdin", filename })
    local old = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    vim.system(argv, { cwd = cwd, stdin = text(old), text = true }, function(result)
        vim.schedule(function()
            if result.code > 1 or result.stdout == "" then
                local message = vim.trim(result.stderr ~= "" and result.stderr or "no output")
                callback({ code = -32603, message = data.tool .. ": " .. message })
                return
            end
            local new = vim.split(result.stdout, "\n", { plain = true })
            if new[#new] == "" then
                new[#new] = nil
            end
            local edits = M.hunk_edits(old, new, data.first, data.last)
            if #edits == 0 then
                vim.notify(("%s: no safe autocorrection here"):format(data.cop or data.tool), vim.log.levels.WARN)
            end
            callback(nil, vim.tbl_extend("force", action, { edit = { changes = { [data.uri] = edits } } }))
        end)
    end)
end

local function fixes_server(dispatchers)
    local closing, request_id = false, 0
    return {
        request = function(method, params, callback, notify_reply_callback)
            request_id = request_id + 1
            local id = request_id
            if method == "initialize" then
                callback(nil, {
                    capabilities = { positionEncoding = "utf-8", codeActionProvider = { resolveProvider = true } },
                })
            elseif method == "textDocument/codeAction" then
                local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
                callback(nil, M.code_actions(bufnr, params.range.start.line, params.range["end"].line))
            elseif method == "codeAction/resolve" then
                M.resolve_action(params, callback)
            elseif method == "shutdown" then
                callback(nil, nil)
            else
                callback({ code = -32601, message = "Method not found: " .. method })
            end
            if notify_reply_callback then
                vim.schedule(function()
                    notify_reply_callback(id)
                end)
            end
            return true, id
        end,
        notify = function(method)
            if method == "exit" then
                dispatchers.on_exit(0, 15)
            end
            return true
        end,
        is_closing = function()
            return closing
        end,
        terminate = function()
            closing = true
        end,
    }
end

--- Attaches the code action server to a buffer nvim-lint lints.
function M.attach_fixes(bufnr)
    vim.lsp.start({
        name = "ruby_fixes",
        cmd = fixes_server,
        reuse_client = function(client, config)
            return client.name == config.name
        end,
    }, { bufnr = bufnr })
end

-- ruby-lsp's full test discovery marks every Minitest and test-unit test and
-- group under test/ or spec/ with "Run", "Run in terminal" and "Debug" lenses,
-- in a bundle or not. A lens carries { path, id }: the test tree comes from
-- `rubyLsp/discoverTests` and the shell line that runs a test from
-- `rubyLsp/resolveTestCommands`, which also loads the reporters VS Code's
-- test explorer reads (left out here).

--- The test or group `id` in a `rubyLsp/discoverTests` tree.
function M.find_test(items, id)
    for _, item in ipairs(items or {}) do
        local found = item.id == id and item or M.find_test(item.children, id)
        if found then
            return found
        end
    end
end

--- The innermost test or group around `row` (0-based) in that tree.
function M.test_at(items, row)
    for _, item in ipairs(items or {}) do
        if item.range.start.line <= row and row <= item.range["end"].line then
            return M.test_at(item.children, row) or item
        end
    end
end

--- The command of a `rubyLsp/resolveTestCommands` answer, without reporters.
function M.test_command(commands)
    local command = commands and commands[1]
    return command and (command:gsub("%s%-r%S+/test_reporters/%S+%.rb", ""))
end

-- Asks `client` for the test `pick` chooses in the tree of `path`, then for
-- its command, and calls `run` with { name, command, root }.
local function with_test(client, path, pick, run)
    local bufnr = vim.fn.bufadd(path)
    local params = { textDocument = { uri = vim.uri_from_fname(path) } }
    client:request("rubyLsp/discoverTests", params, function(err, items)
        local item = not err and pick(items)
        if not item then
            vim.notify(err and "ruby-lsp tests: " .. err.message or "No test around the cursor", vim.log.levels.WARN)
            return
        end
        client:request("rubyLsp/resolveTestCommands", { items = { item } }, function(cmd_err, result)
            local command = not cmd_err and M.test_command(result and result.commands)
            if not command then
                vim.notify("ruby-lsp has no command for " .. item.id, vim.log.levels.WARN)
                return
            end
            local root = client.root_dir or M.bundle_root(path) or vim.fs.dirname(path)
            run({ name = item.label or item.id, command = command, root = root })
        end, bufnr)
    end, bufnr)
end

local function lens_test(cmd, ctx, run)
    local path, id = unpack(cmd.arguments or {})
    with_test(assert(vim.lsp.get_client_by_id(ctx.client_id)), path, function(items)
        return M.find_test(items, id)
    end, run)
end

--- Runs a test lens in the same sticky terminal as `<Leader>t`.
function M.run_test_lens(cmd, ctx)
    lens_test(cmd, ctx, function(test)
        require("lenses").run_in_test_terminal(test.command, test.root)
    end)
end

--- nvim-dap configuration debugging `test` (the `ruby` adapter runs its
--- command under rdbg).
function M.debug_test_config(test)
    return {
        name = "Ruby: " .. test.name,
        type = "ruby",
        request = "attach",
        command = test.command,
        cwd = test.root,
        localfs = true,
    }
end

function M.debug_test_lens(cmd, ctx)
    lens_test(cmd, ctx, function(test)
        require("dap").run(M.debug_test_config(test))
    end)
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
    with_test(client, vim.api.nvim_buf_get_name(bufnr), function(items)
        return M.test_at(items, row)
    end, function(test)
        require("dap").run(M.debug_test_config(test))
    end)
end

-- ruby-lsp's on-type formatting: `end` after an opening line, a heredoc's
-- terminator, the closing block pipe, and a body reindented when its `end` is
-- typed. It runs in every Insert submode, `ic` included (mini.completion holds
-- it while waiting for items, and vim.lsp.on_type_formatting skips it). `{` is
-- left to mini.pairs and comment leaders to 'formatoptions' `r`.
local on_type_keys = { ["\r"] = "\n", ["|"] = "|", d = "d" }

--- The trigger character ruby-lsp acts on for the key `typed`, given the
--- cursor's line once the key is in; nil when the server would do nothing.
---@param typed string
---@param line string
---@return string?
function M.on_type_trigger(typed, line)
    local ch = on_type_keys[typed]
    if ch == "|" and not (line:find("do%s+|") or line:find("{%s+|")) then
        return nil
    end
    if ch == "d" and vim.trim(line) ~= "end" then
        return nil
    end
    return ch
end

--- Applies ruby-lsp's on-type edits for `ch`, just typed at the cursor of
--- `bufnr`, unless the buffer changes before they arrive.
function M.format_on_type(bufnr, ch)
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = "ruby_lsp" })[1]
    if not client then
        return
    end
    local version = vim.lsp.util.buf_versions[bufnr]
    local params = vim.tbl_extend(
        "keep",
        vim.lsp.util.make_formatting_params(),
        vim.lsp.util.make_position_params(0, client.offset_encoding),
        { ch = ch }
    )
    client:request("textDocument/onTypeFormatting", params, function(err, edits)
        if err or not edits or not vim.api.nvim_buf_is_loaded(bufnr) or vim.lsp.util.buf_versions[bufnr] ~= version then
            return
        end
        edits = vim.tbl_filter(function(edit)
            return not edit.newText:match("^#%s*$")
        end, edits)
        vim.lsp.util.apply_text_edits(edits, bufnr, client.offset_encoding)
    end, bufnr)
end

local on_type_ns = vim.api.nvim_create_namespace("hvpaiva.ruby_on_type")

--- Formats Ruby buffers as their trigger keys are typed.
function M.enable_on_type()
    vim.on_key(function(_, typed)
        if not on_type_keys[typed] then
            return
        end
        local mode = vim.api.nvim_get_mode()
        local bufnr = vim.api.nvim_get_current_buf()
        if mode.blocking or mode.mode:sub(1, 1) ~= "i" or vim.bo[bufnr].filetype ~= "ruby" then
            return
        end
        vim.schedule(function()
            local ch = vim.api.nvim_get_current_buf() == bufnr
                and M.on_type_trigger(typed, vim.api.nvim_get_current_line())
            if ch then
                M.format_on_type(bufnr, ch)
            end
        end)
    end, on_type_ns)
end

-- Language servers ----------------------------------------------------------

local scratch_workspace = vim.fn.stdpath("cache") .. "/ruby-lsp-scratch"

--- `root_dir` for ruby-lsp and Solargraph: the project (Gemfile or
--- repository), else the file's own directory. Without a root a server takes
--- Neovim's cwd as its workspace and indexes everything below it. A file right
--- in $HOME gets an empty workspace.
function M.lsp_root(bufnr, on_dir)
    local path = vim.api.nvim_buf_get_name(bufnr)
    if path == "" then
        return
    end
    local root = vim.fs.root(bufnr, { "Gemfile", "gems.rb", ".git" }) or vim.fs.dirname(path)
    if root == vim.env.HOME or root == "/" then
        vim.fn.mkdir(scratch_workspace, "p")
        root = scratch_workspace
    end
    on_dir(root)
end

--- `cmd` that starts `launcher` (scripts/) under the project's Ruby. Neovim's
--- PATH holds the Ruby it was started with; Bundler refuses to run a project
--- whose Gemfile pins another one, and C extensions only load in the Ruby they
--- were built for. `mise x` resolves the Ruby from the project directory, and
--- the launcher installs its gem into it when missing.
function M.lsp_cmd(launcher)
    local path = vim.fn.stdpath("config") .. "/scripts/" .. launcher
    return function(dispatchers, config)
        local cwd = config.cmd_cwd or config.root_dir
        local argv = vim.fn.executable("mise") == 1 and { "mise", "x", "--", path } or { path }
        return vim.lsp.rpc.start(argv, dispatchers, cwd and { cwd = cwd } or nil)
    end
end

-- Solargraph runs next to ruby-lsp. It infers the types of locals and method
-- returns and indexes methods defined outside classes, which ruby-lsp does
-- not; ruby-lsp parses past syntax errors, follows `require` and renames a
-- constant's file with it, where Solargraph does not. Requests both serve go
-- to ruby-lsp, which asks Solargraph too and keeps the answer `merged` names:
-- one server's when it has one, else the other's, or both lists. Completion
-- comes from both (deduplicated in mini.lua) and type definition from
-- Solargraph alone; the rest is ruby-lsp's.
local merged = {
    ["textDocument/hover"] = "solargraph",
    ["textDocument/definition"] = "solargraph",
    ["textDocument/signatureHelp"] = "solargraph",
    ["textDocument/prepareRename"] = "ruby_lsp",
    ["textDocument/rename"] = "ruby_lsp",
    ["textDocument/references"] = "both",
    ["workspace/symbol"] = "both",
}

-- How long an answer from ruby-lsp waits for Solargraph's.
M.solargraph_wait_ms = 1500

-- Solargraph's other requests, which ruby-lsp and conform serve.
local not_solargraph = {
    ["textDocument/formatting"] = true,
    ["textDocument/documentHighlight"] = true,
    ["textDocument/documentSymbol"] = true,
    ["textDocument/foldingRange"] = true,
}

--- Keeps Neovim from sending Solargraph the requests in `merged`, which reach
--- it through ruby-lsp, and the ones in `not_solargraph`. Solargraph offers
--- some of them whatever its settings say.
function M.limit_solargraph(client)
    local supports_method = client.supports_method
    client.supports_method = function(self, method, ...)
        if merged[method] or not_solargraph[method] then
            return false
        end
        return supports_method(self, method, ...)
    end
end

--- Gives mini.completion the columns of Solargraph's completion edits in
--- bytes, the unit it reads them in whatever the server's encoding; their
--- `additionalTextEdits` it reads right, and they are left alone.
function M.complete_in_bytes(client)
    local request = client.request
    client.request = function(self, method, params, handler, bufnr)
        if handler and (method == "textDocument/completion" or method == "completionItem/resolve") then
            local inner = handler
            handler = function(err, result, ctx)
                local target = vim._resolve_bufnr(bufnr)
                local function convert(r)
                    for _, pos in ipairs(r and { r.start, r["end"] } or {}) do
                        local line = vim.api.nvim_buf_get_lines(target, pos.line, pos.line + 1, false)[1]
                        if line then
                            pos.character = M.recode_column(line, pos.character, self.offset_encoding, "utf-8")
                        end
                    end
                end
                local items = type(result) == "table"
                    and (result.items or (vim.islist(result) and result or { result }))
                for _, item in ipairs(items or {}) do
                    local edit = item.textEdit
                    if edit then
                        convert(edit.range)
                        convert(edit.insert)
                        convert(edit.replace)
                    end
                end
                local defaults = type(result) == "table" and result.itemDefaults and result.itemDefaults.editRange
                if defaults then
                    convert(defaults.start and defaults or defaults.insert)
                    convert(defaults.replace)
                end
                return inner(err, result, ctx)
            end
        end
        return request(self, method, params, handler, bufnr)
    end
end

local function empty(method, result)
    if result == nil then
        return true
    elseif method == "textDocument/hover" then
        local contents = result.contents
        return contents == nil
            or contents == ""
            or (type(contents) == "table" and (contents.value or contents[1] or "") == "")
    elseif method == "textDocument/signatureHelp" then
        return not result.signatures or #result.signatures == 0
    elseif method == "textDocument/rename" then
        return vim.tbl_isempty(result.changes or {}) and vim.tbl_isempty(result.documentChanges or {})
    end
    return vim.islist(result) and #result == 0
end

--- `character` of `line` (a column in the `from` position encoding) in the
--- `to` encoding.
---@param line string
---@param character integer
---@param from string
---@param to string
---@return integer
function M.recode_column(line, character, from, to)
    if from == to or not line:find("[\128-\255]") then
        return character
    end
    return vim.str_utfindex(line, to, vim.str_byteindex(line, from, character, false), false)
end

--- A copy of `result`, the answer to `method`, with its columns converted from
--- the `from` position encoding to `to`. `line_at(uri, row)` gives the text of
--- a line; a nil uri is the requested document.
---@param method string
---@param result any
---@param from string
---@param to string
---@param line_at fun(uri: string?, row: integer): string?
function M.recode(method, result, from, to, line_at)
    if from == to or type(result) ~= "table" then
        return result
    end
    result = vim.deepcopy(result)
    local function range(uri, r)
        for _, pos in ipairs(r and { r.start, r["end"] } or {}) do
            local line = line_at(uri, pos.line)
            if line then
                pos.character = M.recode_column(line, pos.character, from, to)
            end
        end
    end
    local function edits(uri, list)
        for _, edit in ipairs(list or {}) do
            range(uri, edit.range)
        end
    end
    if method == "textDocument/hover" then
        range(nil, result.range)
    elseif method == "textDocument/prepareRename" then
        range(nil, result.start and result or result.range)
    elseif method == "textDocument/rename" then
        for uri, list in pairs(result.changes or {}) do
            edits(uri, list)
        end
        for _, change in ipairs(result.documentChanges or {}) do
            if change.textDocument then
                edits(change.textDocument.uri, change.edits)
            end
        end
    elseif method ~= "textDocument/signatureHelp" then
        for _, item in ipairs(vim.islist(result) and result or { result }) do
            local location = item.location or item
            local uri = location.uri or location.targetUri
            range(uri, location.range)
            range(uri, location.targetRange)
            range(uri, location.targetSelectionRange)
            range(nil, location.originSelectionRange)
        end
    end
    return result
end

-- Locations (or symbols) once each.
local function unique(lists)
    local result, seen = {}, {}
    for _, list in ipairs(lists) do
        for _, item in ipairs(vim.islist(list) and list or { list }) do
            local location = item.location or item
            local start = (location.targetSelectionRange or location.range or {}).start or {}
            local key = ("%s:%s:%s"):format(location.uri or location.targetUri, start.line, start.character)
            if not seen[key] then
                seen[key] = true
                result[#result + 1] = item
            end
        end
    end
    return result
end

--- The answer to `method` from ruby-lsp's and Solargraph's (in ruby-lsp's
--- encoding), as `merged` says.
function M.merge(method, ruby_lsp, solargraph)
    local how = merged[method]
    if how == "both" then
        return unique({ ruby_lsp or {}, solargraph or {} })
    end
    local first, second = solargraph, ruby_lsp
    if how == "ruby_lsp" then
        first, second = ruby_lsp, solargraph
    end
    local result = empty(method, first) and second or first
    if method == "textDocument/definition" and type(result) == "table" then
        return unique({ result })
    end
    return result
end

--- The identifier at `character` (a column in `encoding`) of `line`, sigils
--- left out.
---@return string?
function M.name_at(line, character, encoding)
    local byte = vim.str_byteindex(line, encoding, character, false) + 1
    for first, name, last in line:gmatch("()([%w_\128-\255]+[?!]?)()") do
        if byte >= first and byte < last then
            return name
        end
    end
end

--- The `locations` (columns in `encoding`) whose text has `name` in it.
--- ruby-lsp answers references on a call's receiver with the method's.
function M.naming(locations, name, encoding, line_at)
    return vim.tbl_filter(function(location)
        local r = location.range
        local line = line_at(location.uri, r.start.line) or ""
        local first = vim.str_byteindex(line, encoding, r.start.character, false)
        local last = r["end"].line == r.start.line and vim.str_byteindex(line, encoding, r["end"].character, false)
            or #line
        return line:sub(first + 1, last):find(name, 1, true) ~= nil
    end, locations)
end

-- line_at for M.recode, reading files that have no buffer.
local function line_reader(bufnr)
    local files = {}
    return function(uri, row)
        local target = uri and vim.fn.bufnr(vim.uri_to_fname(uri)) or bufnr
        if target ~= -1 and vim.api.nvim_buf_is_loaded(target) then
            return vim.api.nvim_buf_get_lines(target, row, row + 1, false)[1]
        end
        local path = vim.uri_to_fname(uri)
        files[path] = files[path] or (vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {})
        return files[path][row + 1]
    end
end

--- Makes ruby-lsp's `client` answer the requests in `merged` together with
--- the Solargraph attached to the same buffer.
function M.merge_solargraph(client)
    local request, cancel_request = client.request, client.cancel_request
    local pending = {}
    client.request = function(self, method, params, handler, bufnr)
        bufnr = vim._resolve_bufnr(bufnr)
        local how = merged[method]
        local solargraph = how and handler and vim.lsp.get_clients({ bufnr = bufnr, name = "solargraph" })[1]
        if not solargraph or not solargraph.initialized then
            return request(self, method, params, handler, bufnr)
        end
        local version = vim.lsp.util.buf_versions[bufnr]
        local line_at = line_reader(bufnr)
        local from, to = self.offset_encoding, solargraph.offset_encoding
        local answers, done, ruby_id = {}, false, nil
        local function finish()
            if done then
                return
            end
            done = true
            if ruby_id then
                pending[ruby_id] = nil
            end
            local ruby_lsp, other = answers.ruby_lsp or {}, answers.solargraph or {}
            local ruby_result = ruby_lsp.result
            if method == "textDocument/references" and type(ruby_result) == "table" then
                local name = M.name_at(line_at(nil, params.position.line) or "", params.position.character, from)
                ruby_result = name and M.naming(ruby_result, name, from, line_at) or ruby_result
            end
            local result = M.merge(method, ruby_result, M.recode(method, other.result, to, from, line_at))
            handler(result == nil and ruby_lsp.err or nil, result, {
                method = method,
                client_id = self.id,
                request_id = ruby_id,
                bufnr = bufnr,
                params = params,
                version = version,
            })
        end
        -- Answers as soon as the preferred server has something, else once
        -- both did, giving up on Solargraph after solargraph_wait_ms.
        local function settle()
            local ruby_lsp, other = answers.ruby_lsp, answers.solargraph
            local preferred = how == "ruby_lsp" and ruby_lsp or how == "solargraph" and other
            if (ruby_lsp and other) or (preferred and not empty(method, preferred.result)) then
                finish()
            elseif ruby_lsp then
                vim.defer_fn(finish, M.solargraph_wait_ms)
            end
        end
        local ok
        ok, ruby_id = request(self, method, params, function(err, result)
            answers.ruby_lsp = { err = err, result = result }
            settle()
        end, bufnr)
        if not ok or done then
            return ok, ruby_id
        end
        local recoded = vim.deepcopy(params)
        if recoded.position then
            local line = vim.api.nvim_buf_get_lines(bufnr, recoded.position.line, recoded.position.line + 1, false)[1]
            recoded.position.character = M.recode_column(line or "", recoded.position.character, from, to)
        end
        local sent, solargraph_id = solargraph:request(method, recoded, function(err, result)
            answers.solargraph = { result = not err and result or nil }
            settle()
        end, bufnr)
        if not sent then
            answers.solargraph = {}
            settle()
        end
        if not done then
            pending[ruby_id] = function()
                done = true
                solargraph:cancel_request(solargraph_id)
            end
        end
        return ok, ruby_id
    end
    client.cancel_request = function(self, id)
        if pending[id] then
            pending[id]()
            pending[id] = nil
        end
        return cancel_request(self, id)
    end
end

return M
