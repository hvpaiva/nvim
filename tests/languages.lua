-- Ruby and shell editing checks against the full config. Run from the config
-- directory (see README.md, Verification). Fixtures live in a temporary
-- directory; no project command runs, and no test or debugger starts.
local temporary = vim.fn.tempname()
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end

local function write(path, text)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end

local function project(name, files)
    local dir = temporary .. "/" .. name
    vim.fn.mkdir(dir .. "/.git", "p")
    for path, text in pairs(files) do
        write(dir .. "/" .. path, text)
    end
    return dir
end

local function lockfile(specs, dependencies)
    local lines = { "GEM", "  remote: https://rubygems.org/", "  specs:" }
    for _, spec in ipairs(specs) do
        lines[#lines + 1] = "    " .. spec .. " (1.0.0)"
    end
    vim.list_extend(lines, { "", "PLATFORMS", "  x86_64-linux", "", "DEPENDENCIES" })
    for _, dependency in ipairs(dependencies) do
        lines[#lines + 1] = "  " .. dependency
    end
    return table.concat(lines, "\n")
end

-- No language server is needed here, and the fixture lockfiles name gem
-- versions that do not exist: keep ruby-lsp, Solargraph and bashls from
-- starting.
vim.lsp.enable({ "ruby_lsp", "solargraph", "bashls" }, false)

local ruby = require("ruby_tools")

-- Style and lint ownership ---------------------------------------------------
local cases = {
    {
        name = "standalone",
        files = { ["script.rb"] = "puts 1" },
        style = "standard",
        plan = { linters = {}, editor = "standardrb" },
    },
    {
        name = "standard bundle",
        files = {
            Gemfile = 'gem "standard"',
            ["Gemfile.lock"] = lockfile({ "standard", "rubocop" }, { "standard" }),
            ["script.rb"] = "puts 1",
        },
        style = "standard",
        plan = { linters = { "standard" } },
    },
    {
        name = "rubocop bundle without config",
        files = {
            Gemfile = 'gem "rubocop"',
            ["Gemfile.lock"] = lockfile({ "rubocop" }, { "rubocop (~> 1.0)" }),
            ["script.rb"] = "puts 1",
        },
        style = "rubocop",
        plan = {},
    },
    {
        name = "bundle without a linter",
        files = {
            Gemfile = 'gem "minitest"',
            ["Gemfile.lock"] = lockfile({ "minitest" }, { "minitest" }),
            ["script.rb"] = "puts 1",
        },
        style = "standard",
        plan = { linters = {}, editor = "standardrb" },
    },
    {
        name = "rubocop config outside the bundle",
        files = { [".rubocop.yml"] = "AllCops: {}", ["script.rb"] = "puts 1" },
        style = "rubocop",
        plan = { linters = {}, editor = "rubocop" },
    },
    {
        name = "rubocop config over a transitive rubocop",
        files = {
            Gemfile = 'gem "standard"',
            [".rubocop.yml"] = "require: standard",
            ["Gemfile.lock"] = lockfile({ "standard", "rubocop" }, { "standard!" }),
            ["script.rb"] = "puts 1",
        },
        style = "rubocop",
        plan = {},
    },
}
for _, case in ipairs(cases) do
    local file = project(case.name, case.files) .. "/script.rb"
    check(ruby.style(file) == case.style, case.name .. ": style " .. ruby.style(file))
    check(vim.deep_equal(ruby.lint_plan(file), case.plan), case.name .. ": " .. vim.inspect(ruby.lint_plan(file)))
    local buf = vim.fn.bufadd(file)
    local formatter = case.style == "standard" and "standardrb" or "rubocop"
    check(ruby.formatters(buf)[1] == formatter, case.name .. ": formatter")
end

local lock = ruby.lock(temporary .. "/rubocop config over a transitive rubocop")
check(lock.direct.standard and not lock.direct.rubocop and lock.all.rubocop, "lockfile direct and resolved gems")

-- Linter resolution and RuboCop daemons ---------------------------------------
local bundled = project("bundled rubocop", {
    Gemfile = 'gem "rubocop"',
    ["Gemfile.lock"] = lockfile({ "rubocop" }, { "rubocop" }),
    ["lib/widget.rb"] = "value = 1",
})
local under_mise = vim.fn.executable("mise") == 1 and { "mise", "x", "--" } or {}
local function argv_of(spec, count)
    return vim.list_slice(vim.list_extend({ spec.cmd }, spec.args), 1, #under_mise + count)
end
vim.cmd.edit(vim.fn.fnameescape(bundled .. "/lib/widget.rb"))
local linter = ruby.linter("rubocop")()
local bundle_exec = vim.list_extend(vim.deepcopy(under_mise), { "bundle", "exec", "rubocop" })
check(vim.deep_equal(argv_of(linter, 3), bundle_exec), "lint with the bundle under the project's Ruby")
check(vim.list_contains(linter.args, "--server"), "linter keeps nvim-lint's arguments")
ruby.linter("rubocop")()
local servers = ruby.servers()
check(#servers == 1 and servers[1].cwd == bundled, "one daemon tracked per project and command")
check(vim.deep_equal(servers[1].argv, bundle_exec), "daemon stopped through the same command")
local standalone = ruby.linter("standardrb")
vim.cmd.edit(vim.fn.fnameescape(temporary .. "/standalone/script.rb"))
check(
    vim.deep_equal(argv_of(standalone(), 1), vim.list_extend(vim.deepcopy(under_mise), { "standardrb" })),
    "standalone lint with the global tool"
)

-- nvim-lint on Ruby: offenses are not failures, failures are not silent -----
local lint_dir = project("lint", {
    ["offense.rb"] = "def f(x)\n  return x\nend",
    ["broken/a.rb"] = "def f(x)\n  return x\nend",
    ["broken/.standard.yml"] = "ruby_version: [not valid",
})
local notified = {}
local notify = vim.notify
vim.notify = function(msg)
    notified[#notified + 1] = msg
end
local function linted(file)
    vim.cmd.edit(vim.fn.fnameescape(lint_dir .. "/" .. file))
    vim.wait(15000, function()
        return #vim.diagnostic.get(0) > 0
    end, 100)
    return vim.diagnostic.get(0)
end
local offense = linted("offense.rb")
check(offense[1] and offense[1].source == "standardrb", "standardrb reports the offense")
check(offense[1].severity == vim.diagnostic.severity.INFO, "a convention cop is INFO, as ruby-lsp reports it")
local failure = linted("broken/a.rb")
check(failure[1] and failure[1].severity == vim.diagnostic.severity.ERROR, "a failing linter shows an error")
check(failure[1] and failure[1].message:find("Output from linter", 1, true), "with the linter's own output")
vim.wait(500)
vim.notify = notify
check(#notified == 0, "no exit-code notifications: " .. table.concat(notified, " | "))

-- Formatting changes layout only ---------------------------------------------
local format_dir = project("format", { ["script.rb"] = "def f(x)\n    $stderr.puts x\n  return x\nend" })
vim.cmd.edit(vim.fn.fnameescape(format_dir .. "/script.rb"))
require("conform").format({ async = false, timeout_ms = 15000 })
check(
    vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "def f(x)", "  $stderr.puts x", "  return x", "end" }),
    "formatting fixes indentation and keeps the code: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
)

-- Code actions on the files nvim-lint lints -----------------------------------
local before, after = { "a", "b", "c", "d" }, { "a", "B", "C", "d", "e" }
local edits = ruby.hunk_edits(before, after, 2, 2)
check(#edits == 1 and edits[1].range.start.line == 2 and edits[1].newText == "C\n", "a fix keeps its own row only")
edits = ruby.hunk_edits(before, after, 3, 3)
check(#edits == 1 and edits[1].newText == "\ne", "an insertion touches the row above")
local function rebuilt(old, new)
    local scratch = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, old)
    vim.lsp.util.apply_text_edits(ruby.hunk_edits(old, new), scratch, "utf-8")
    local lines = vim.api.nvim_buf_get_lines(scratch, 0, -1, false)
    vim.api.nvim_buf_delete(scratch, { force = true })
    return vim.deep_equal(lines, new), lines
end
for _, case in ipairs({
    { before, after },
    { { "a", "b" }, { "x", "a", "b" } },
    { { "a", "b", "c" }, { "a" } },
    { { "a", "b", "c" }, { "a", "c" } },
    { { "a", "b" }, { "a", "b", "c", "d" } },
    { { "a", "b", "c" }, { "z" } },
}) do
    local ok, lines = rebuilt(case[1], case[2])
    check(ok, "hunks rebuild " .. vim.inspect(case[2]) .. ", got " .. vim.inspect(lines))
end
check(
    ruby.disable_edit("x = 1", 4, "standardrb", "Style/A").newText == " # standard:disable Style/A",
    "disable directive"
)
local extended = ruby.disable_edit("x = 1 # rubocop:disable Style/A", 4, "rubocop", "Style/B")
check(extended.newText == ", Style/B" and extended.range.start.character == 31, "disable extends the directive")

local fixes_dir = project("fixes", {
    ["script.rb"] = "def f(x)\n  $stderr.puts x\n  $stderr.puts x\n  return x\nend",
    ["literals.rb"] = 'x = "abc"\nputs <<~TEXT\n  body\nTEXT\ny = %w[\n  a\n]',
})
vim.cmd.edit(vim.fn.fnameescape(fixes_dir .. "/script.rb"))
vim.wait(15000, function()
    return #vim.diagnostic.get(0) >= 3
end, 100)
local fixes = vim.lsp.get_clients({ bufnr = 0, name = "ruby_fixes" })[1]
check(fixes and fixes.offset_encoding == "utf-8", "code action server on a linted script")
local function actions_at(bufnr, row)
    local position = { line = row, character = 0 }
    local params = {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        range = { start = position, ["end"] = position },
        context = { diagnostics = {} },
    }
    return fixes:request_sync("textDocument/codeAction", params, 5000, bufnr).result
end
local function titles(actions)
    return vim.tbl_map(function(action)
        return action.title
    end, actions)
end
local function apply(action)
    if not action.edit then
        action = fixes:request_sync("codeAction/resolve", action, 15000, 0).result
    end
    vim.lsp.util.apply_workspace_edit(action.edit, fixes.offset_encoding)
end
local offense_actions = actions_at(0, 1)
check(
    vim.deep_equal(
        titles(offense_actions),
        { "Autocorrect Style/StderrPuts", "Disable Style/StderrPuts for this line", "Autocorrect all offenses" }
    ),
    "actions on an offense: " .. vim.inspect(titles(offense_actions))
)
local function relinted()
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
    vim.wait(15000, function()
        local diagnostics = vim.diagnostic.get(0)
        return #diagnostics > 0
            and vim.iter(diagnostics):all(function(diagnostic)
                return vim.tbl_get(diagnostic, "user_data", "changedtick") == vim.b.changedtick
            end)
    end, 50)
end
apply(offense_actions[1])
check(vim.api.nvim_buf_get_lines(0, 1, 3, false)[2] == "  $stderr.puts x", "autocorrect leaves the next offense alone")
check(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "  warn x", "autocorrect fixes its offense")
check(
    vim.deep_equal(titles(actions_at(0, 2)), { "Autocorrect all offenses" }),
    "no per-offense action from an older text"
)
relinted()
apply(actions_at(0, 2)[2])
relinted()
local return_actions = actions_at(0, 3)
apply(return_actions[#return_actions])
check(
    vim.deep_equal(
        vim.api.nvim_buf_get_lines(0, 0, -1, false),
        { "def f(x)", "  warn x", "  $stderr.puts x # standard:disable Style/StderrPuts", "  x", "end" }
    ),
    "disable, then autocorrect the rest: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
)
vim.bo.modified = false

-- No directive where it would land inside a heredoc or a multi-line literal.
local literals = vim.fn.bufadd(fixes_dir .. "/literals.rb")
vim.fn.bufload(literals)
vim.bo[literals].filetype = "ruby"
local offenses = {}
for row = 0, 6 do
    offenses[#offenses + 1] = {
        lnum = row,
        col = 0,
        message = "offense",
        code = "Style/Test",
        user_data = { changedtick = vim.b[literals].changedtick },
    }
end
vim.diagnostic.set(require("lint").get_namespace("ruby_standardrb"), literals, offenses)
local disabled = {}
for row = 0, 6 do
    disabled[#disabled + 1] = #actions_at(literals, row) > 0
end
check(
    vim.deep_equal(disabled, { true, true, false, false, false, false, true }),
    "disable only outside literals: " .. vim.inspect(disabled)
)

-- ruby-lsp on-type formatting ---------------------------------------------------
check(ruby.on_type_trigger("\r", "  ") == "\n", "Enter is a trigger")
check(ruby.on_type_trigger("|", "arr.map { |}") == "|", "a pipe after a block opener is a trigger")
check(ruby.on_type_trigger("|", "a || b") == nil, "other pipes are not")
check(ruby.on_type_trigger("d", "  end") == "d" and ruby.on_type_trigger("d", "def") == nil, "`d` only ending `end`")
check(ruby.on_type_trigger("{", "x = {}") == nil, "braces are left to mini.pairs")

-- Stand-in ruby-lsp servers (or `name` ones with `capabilities`):
-- `answer(method, params, reply)` replies to every request but the lifecycle
-- ones, the way the real server would; `notified(method, params)` sees the
-- notifications.
local function stand_in(answer, root, name, capabilities, notified)
    return vim.lsp.start({
        name = name or "ruby_lsp",
        root_dir = root,
        cmd = function(dispatchers)
            local id = 0
            return {
                request = function(method, params, callback)
                    id = id + 1
                    local function reply(result)
                        callback(nil, result)
                    end
                    if method == "initialize" then
                        reply({ capabilities = capabilities or {} })
                    elseif method == "shutdown" then
                        reply(nil)
                    else
                        answer(method, params, reply)
                    end
                    return true, id
                end,
                notify = function(method, params)
                    if notified then
                        notified(method, params)
                    end
                    if method == "exit" then
                        dispatchers.on_exit(0, 15)
                    end
                    return true
                end,
                is_closing = function()
                    return false
                end,
                terminate = function() end,
            }
        end,
    })
end

vim.cmd.edit(vim.fn.fnameescape(project("typing", { ["script.rb"] = "" }) .. "/script.rb"))
local requests, edits_for, deferred = {}, {}, false
local fake_lsp = stand_in(function(method, params, reply)
    requests[#requests + 1] = method == "textDocument/onTypeFormatting" and params.ch or method
    local result = method == "textDocument/onTypeFormatting" and edits_for[params.ch] or {}
    if deferred and method == "textDocument/onTypeFormatting" then
        vim.defer_fn(function()
            reply(result)
        end, 100)
    else
        reply(result)
    end
end)
check(fake_lsp and vim.lsp.get_clients({ bufnr = 0, name = "ruby_lsp" })[1], "stand-in ruby-lsp attached")
local function insert(row, col, text)
    local position = { line = row, character = col }
    return { range = { start = position, ["end"] = position }, newText = text }
end
edits_for["\n"] = { insert(1, 2, "\n"), insert(1, 2, "end") }
local function on_type(lines, ch)
    requests = {}
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    ruby.format_on_type(vim.api.nvim_get_current_buf(), ch)
    vim.wait(500, function()
        return #requests >= 1
    end, 10)
    vim.wait(deferred and 300 or 50)
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local typed = on_type({ "def foo", "  " }, "\n")
check(vim.deep_equal(requests, { "\n" }), "the typed trigger goes to ruby-lsp")
check(vim.deep_equal(typed, { "def foo", "  ", "end" }), "on-type edits applied: " .. vim.inspect(typed))
edits_for["\n"] = { insert(1, 2, "# ") }
typed = on_type({ "# hello", "# " }, "\n")
check(vim.deep_equal(typed, { "# hello", "# " }), "comment leaders left to 'formatoptions': " .. vim.inspect(typed))
edits_for["\n"], deferred = { insert(1, 2, "\n"), insert(1, 2, "end") }, true
requests = {}
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "def foo", "  " })
vim.api.nvim_win_set_cursor(0, { 2, 2 })
ruby.format_on_type(vim.api.nvim_get_current_buf(), "\n")
vim.api.nvim_buf_set_lines(0, 1, 2, false, { "  bar" })
vim.wait(300)
check(
    vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "def foo", "  bar" }),
    "edits for an older text are dropped"
)
local operator = { label = "==", kind = 2, client_id = fake_lsp, textEdit = { newText = "= = ", range = {} } }
MiniCompletion.config.lsp_completion.process_items({ operator }, "")
check(operator.textEdit.newText == "==", "ruby-lsp operators complete as written")
vim.lsp.get_client_by_id(fake_lsp):stop(true)
vim.bo.modified = false

-- ruby-lsp client configuration ----------------------------------------------
local ruby_lsp = vim.lsp.config.ruby_lsp
check(ruby_lsp.init_options.formatter == "none", "ruby-lsp leaves formatting to conform")
check(ruby_lsp.init_options.featuresConfiguration.inlayHint.implicitRescue, "ruby-lsp inlay hints configured")
for _, command in ipairs({ "rubyLsp.runTest", "rubyLsp.runTestInTerminal", "rubyLsp.debugTest" }) do
    check(type(ruby_lsp.commands[command]) == "function", "client command " .. command)
end
local params = { initializationOptions = vim.deepcopy(ruby_lsp.init_options) }
ruby_lsp.before_init(params, { root_dir = temporary .. "/standard bundle" })
check(vim.deep_equal(params.initializationOptions.linters, { "standard" }), "Standard add-on for Standard bundles")
params = { initializationOptions = vim.deepcopy(ruby_lsp.init_options) }
ruby_lsp.before_init(params, { root_dir = temporary .. "/rubocop bundle without config" })
local function root_of(path)
    local root
    ruby_lsp.root_dir(vim.fn.bufadd(path), function(dir)
        root = dir
    end)
    return root
end
write(temporary .. "/loose/script.rb", "puts 1")
check(root_of(temporary .. "/loose/script.rb") == temporary .. "/loose", "a loose script is its own workspace")
check(root_of(bundled .. "/lib/widget.rb") == bundled, "a project is the workspace")
check(root_of(vim.env.HOME .. "/script.rb"):match("/ruby%-lsp%-scratch$"), "a script in $HOME gets an empty workspace")

-- The launcher's patch: ruby-lsp reparses a request's document in its worker,
-- after the changes queued before the request.
local patch = vim.fn.stdpath("config") .. "/ruby/ruby_lsp_fresh_parse.rb"
local server = vim.system({
    "ruby",
    "-r" .. patch,
    "-ruri",
    "-e",
    table.concat({
        "module RubyLsp",
        "  class Store",
        "    class NonExistingDocumentError < StandardError; end",
        "    def initialize(log); @log = log; end",
        "    def get(_uri); log = @log; Object.new.tap { |d| d.define_singleton_method(:parse!) { log << :parse } }; end",
        "  end",
        "  class Server",
        "    attr_reader :log",
        "    def initialize; @log = []; @global_state = Mutex.new; @store = Store.new(@log); end",
        "    def process_message(message); @log << message[:method]; end",
        "  end",
        "end",
        "server = RubyLsp::Server.new",
        'document = { textDocument: { uri: URI("file:///x.rb") } }',
        'server.process_message({ method: "textDocument/didChange", params: document })',
        'server.process_message({ method: "textDocument/completion", params: document })',
        'server.process_message({ method: "initialized", params: {} })',
        'puts server.log.join(" ")',
    }, "\n"),
}, { text = true }):wait()
check(
    vim.trim(server.stdout) == "textDocument/didChange parse textDocument/completion initialized",
    "requests reparse first, notifications do not: " .. server.stdout .. server.stderr
)
check(vim.list_contains(ruby_lsp.init_options.indexing.excludedPatterns, "{}/**/*.rb"), "top-level files indexed once")
check(params.initializationOptions.linters == nil, "ruby-lsp detects RuboCop itself")

-- Solargraph next to ruby-lsp --------------------------------------------------
local solargraph = vim.lsp.config.solargraph
check(solargraph.root_dir == ruby_lsp.root_dir, "Solargraph shares ruby-lsp's workspace")
check(
    solargraph.init_options.diagnostics == false and solargraph.settings.solargraph.diagnostics == false,
    "Solargraph publishes no diagnostics, at startup or from settings"
)
check(
    solargraph.init_options.completion and not solargraph.init_options.formatting,
    "Solargraph completes, never formats"
)

-- Columns: ruby-lsp counts bytes, Solargraph code points.
check(ruby.recode_column('s = "ção".up', 12, "utf-8", "utf-32") == 10, "byte column to code points")
check(ruby.recode_column('s = "ção".up', 10, "utf-32", "utf-8") == 12, "code points to byte column")
check(ruby.recode_column("plain", 3, "utf-8", "utf-32") == 3, "ASCII lines keep their columns")
local function at(uri, line, first, last)
    return {
        uri = uri,
        range = { start = { line = line, character = first }, ["end"] = { line = line, character = last } },
    }
end
write(temporary .. "/recode/other.rb", 'x = "é"; def slug; end')
local other_uri = vim.uri_from_fname(temporary .. "/recode/other.rb")
local recoded = ruby.recode(
    "textDocument/definition",
    { at(other_uri, 0, 13, 17) },
    "utf-32",
    "utf-8",
    function(uri, row)
        return uri and vim.fn.readfile(vim.uri_to_fname(uri))[row + 1]
    end
)
check(recoded[1].range.start.character == 14, "locations in unopened files converted: " .. vim.inspect(recoded))
local rename_edit = {
    changes = { [other_uri] = { { range = at(other_uri, 0, 13, 17).range, newText = "s" } } },
}
recoded = ruby.recode("textDocument/rename", rename_edit, "utf-32", "utf-8", function(uri, row)
    return vim.fn.readfile(vim.uri_to_fname(uri))[row + 1]
end)
check(recoded.changes[other_uri][1].range["end"].character == 18, "rename edits converted")

-- What each server's answer becomes.
local hover = { contents = { kind = "markdown", value = "Array<String>" } }
local ruby_hover = { contents = { kind = "markdown", value = "Point" } }
check(ruby.merge("textDocument/hover", ruby_hover, hover) == hover, "Solargraph's hover first")
check(ruby.merge("textDocument/hover", ruby_hover, nil) == ruby_hover, "ruby-lsp's hover when Solargraph has none")
check(
    ruby.merge("textDocument/hover", ruby_hover, { contents = { kind = "markdown", value = "" } }) == ruby_hover,
    "an empty hover counts as none"
)
local file_uri = vim.uri_from_fname(temporary .. "/app.rb")
local definitions = ruby.merge(
    "textDocument/definition",
    { at(file_uri, 9, 0, 3) },
    { at(file_uri, 1, 4, 9), at(file_uri, 1, 4, 9) }
)
check(#definitions == 1 and definitions[1].range.start.line == 1, "Solargraph's definition, once")
check(
    #ruby.merge("textDocument/definition", { at(file_uri, 9, 0, 3), at(file_uri, 12, 0, 3) }, {}) == 2,
    "ruby-lsp's candidates when Solargraph finds none"
)
local constant_rename = { documentChanges = { { kind = "rename", oldUri = file_uri, newUri = file_uri .. "x" } } }
check(
    ruby.merge("textDocument/rename", constant_rename, rename_edit) == constant_rename,
    "ruby-lsp renames what it can"
)
check(ruby.merge("textDocument/rename", nil, rename_edit) == rename_edit, "Solargraph renames the rest")
local references = ruby.merge(
    "textDocument/references",
    { at(file_uri, 1, 4, 9), at(file_uri, 5, 0, 5) },
    { at(file_uri, 5, 0, 5), at(file_uri, 7, 2, 7) }
)
check(#references == 3, "references from both, once each")
check(ruby.name_at("total = lines.map(&:strip)", 9, "utf-8") == "lines", "the name under the cursor")
check(ruby.name_at("@ação.empty?", 11, "utf-8") == "empty?", "names keep `?` and non-ASCII letters")
check(ruby.name_at("a == b", 2, "utf-8") == nil, "operators are no name")
local naming = ruby.naming({ at(file_uri, 0, 8, 13), at(file_uri, 0, 14, 17) }, "lines", "utf-8", function()
    return "total = lines.map(&:strip)"
end)
check(#naming == 1 and naming[1].range.start.character == 8, "references must name the symbol")

-- End to end: one answer per request, from ruby-lsp, built from both servers.
vim.cmd.edit(vim.fn.fnameescape(project("merged", { ["app.rb"] = 'word = "ação"\nword.upcase' }) .. "/app.rb"))
local merged_root = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
local asked, cancelled, silent = {}, {}, false
local sg_client = stand_in(
    function(method, params, reply)
        asked[method] = params
        if silent then
            return
        end
        if method == "textDocument/hover" then
            reply({ contents = { kind = "markdown", value = "String#upcase" } })
        elseif method == "textDocument/completion" then
            local r = { start = { line = 0, character = 12 }, ["end"] = { line = 0, character = 13 } }
            reply({
                isIncomplete = false,
                items = { { label = "upcase", textEdit = { newText = "upcase", range = r } } },
            })
        elseif method == "textDocument/references" then
            reply({ at(params.textDocument.uri, 1, 0, 4) })
        else
            reply(nil)
        end
    end,
    merged_root,
    "solargraph",
    {
        positionEncoding = "utf-32",
        completionProvider = { triggerCharacters = { "." } },
        hoverProvider = true,
        referencesProvider = true,
        signatureHelpProvider = {},
        workspaceSymbolProvider = true,
    },
    function(method, params)
        if method == "$/cancelRequest" then
            cancelled[#cancelled + 1] = params.id
        end
    end
)
local rl_client = stand_in(function(method, params, reply)
    if method == "textDocument/hover" then
        reply({ contents = { kind = "markdown", value = "ruby-lsp" } })
    elseif method == "textDocument/references" then
        -- `upcase`: references asked on a receiver answered with its method's.
        reply({
            at(params.textDocument.uri, 0, 0, 4),
            at(params.textDocument.uri, 1, 0, 4),
            at(params.textDocument.uri, 1, 5, 11),
        })
    else
        reply(nil)
    end
end, merged_root, "ruby_lsp", { positionEncoding = "utf-8", hoverProvider = true, referencesProvider = true })
local sg, rl = vim.lsp.get_client_by_id(sg_client), vim.lsp.get_client_by_id(rl_client)
ruby.limit_solargraph(sg)
ruby.complete_in_bytes(sg)
ruby.merge_solargraph(rl)
check(sg.offset_encoding == "utf-32" and rl.offset_encoding == "utf-8", "the servers count columns differently")
check(not sg:supports_method("textDocument/hover"), "Neovim leaves hover to ruby-lsp")
check(not sg:supports_method("workspace/symbol"), "and workspace symbols")
check(not sg:supports_method("textDocument/documentHighlight"), "and highlights")
check(sg:supports_method("textDocument/completion"), "Solargraph still completes")
local function ask(method, extra, col)
    local answers
    vim.api.nvim_win_set_cursor(0, { 1, col or 13 })
    vim.lsp.buf_request_all(0, method, function(client)
        return vim.tbl_extend("force", vim.lsp.util.make_position_params(0, client.offset_encoding), extra or {})
    end, function(results)
        answers = results
    end)
    vim.wait(3000, function()
        return answers ~= nil
    end, 10)
    return answers or {}
end
ruby.solargraph_wait_ms = 100
local answers = ask("textDocument/hover")
check(
    vim.tbl_count(answers) == 1 and answers[rl_client].result.contents.value == "String#upcase",
    "hover answered once, by Solargraph: " .. vim.inspect(answers)
)
check(asked["textDocument/hover"].position.character == 11, "Solargraph is asked in code points")
answers = ask("textDocument/references", { context = { includeDeclaration = true } }, 0)
check(
    #answers[rl_client].result == 2,
    "references from both servers, once each, naming the symbol: " .. vim.inspect(answers[rl_client].result)
)
silent = true
answers = ask("textDocument/hover")
check(answers[rl_client].result.contents.value == "ruby-lsp", "a silent Solargraph leaves ruby-lsp's answer")
ruby.solargraph_wait_ms = 10000
local _, id = rl:request("textDocument/references", vim.lsp.util.make_position_params(0, "utf-8"), function() end, 0)
rl:cancel_request(id)
check(#cancelled == 1, "cancelling the request cancels Solargraph's too")
ruby.solargraph_wait_ms = 1500
silent = false
local completion = sg:request_sync("textDocument/completion", vim.lsp.util.make_position_params(0, "utf-32"), 1000, 0)
local edit_range = completion.result.items[1].textEdit.range
check(
    edit_range.start.character == 14 and edit_range["end"].character == 15,
    "mini.completion gets Solargraph's edit columns in bytes: " .. vim.inspect(edit_range)
)
local item = function(label, client_id)
    return { label = label, kind = 2, client_id = client_id }
end
local completed = MiniCompletion.config.lsp_completion.process_items(
    { item("upcase", rl_client), item("upcase", sg_client), item("upto", sg_client) },
    ""
)
check(
    #completed == 2 and completed[1].client_id == rl_client,
    "Solargraph's completion adds only names ruby-lsp lacks: " .. vim.inspect(completed)
)
sg:stop(true)
rl:stop(true)
vim.bo.modified = false

-- Test code lenses -------------------------------------------------------------
local test_file = bundled .. "/test/widget_test.rb"
local function test_item(id, first, last, children)
    return {
        id = id,
        label = id:match("[^#]+$"),
        range = { start = { line = first, character = 2 }, ["end"] = { line = last, character = 5 } },
        children = children or {},
        tags = { "framework:minitest" },
    }
end
local tests = {
    test_item("WidgetTest", 5, 12, {
        test_item("WidgetTest#test_value", 6, 8),
        test_item("WidgetTest#test_other", 9, 11),
    }),
}
check(ruby.test_at(tests, 7).id == "WidgetTest#test_value", "innermost test around the cursor")
check(ruby.test_at(tests, 12).id == "WidgetTest", "group when outside every test")
check(ruby.test_at(tests, 2) == nil, "nothing before the first test")
check(ruby.find_test(tests, "WidgetTest#test_other").label == "test_other", "a lens's test by id")
local reporters =
    " -r/g/ruby_lsp/test_reporters/minitest_reporter.rb -r/g/ruby_lsp/test_reporters/test_unit_reporter.rb"
local value_command = "bundle exec ruby" .. reporters .. " -Itest " .. test_file .. ' --name "/test_value/"'
check(
    ruby.test_command({ value_command }) == "bundle exec ruby -Itest " .. test_file .. ' --name "/test_value/"',
    "test commands leave VS Code's reporters out"
)

local debug = ruby.debug_test_config({ name = "test_value", command = "ruby -Itest t.rb", root = bundled })
check(debug.type == "ruby" and debug.request == "attach" and debug.cwd == bundled, "debug lens configuration")
check(debug.command == "ruby -Itest t.rb", "debug lens runs the test's command")

local resolved = {}
local tests_lsp = stand_in(function(method, params, reply)
    if method == "rubyLsp/discoverTests" then
        reply(tests)
    elseif method == "rubyLsp/resolveTestCommands" then
        resolved[#resolved + 1] = params.items[1].id
        reply({ commands = { value_command } })
    else
        reply({})
    end
end, bundled)

vim.cmd([[
function! LanguagesCapture(command) abort
    let g:languages_captured = a:command
endfunction
let g:test#custom_strategies = {'languages': function('LanguagesCapture')}
]])
local strategy = vim.g["test#strategy"]
vim.g["test#strategy"] = "languages"
local cwd = vim.fn.getcwd()
ruby.run_test_lens({ arguments = { test_file, "WidgetTest#test_value" } }, { client_id = tests_lsp })
vim.wait(1000, function()
    return vim.g.languages_captured ~= nil
end, 10)
vim.g["test#strategy"] = strategy
check(vim.deep_equal(resolved, { "WidgetTest#test_value" }), "the lens's test is resolved")
check(vim.g.languages_captured:find("cd '" .. bundled .. "'", 1, true), "run lens from the workspace root")
check(vim.g.languages_captured:find('--name "/test_value/"', 1, true), "run lens keeps the test filter")
check(not vim.g.languages_captured:find("test_reporters", 1, true), "run lens without VS Code's reporters")
check(vim.fn.getcwd() == cwd, "run lens restores the working directory")
vim.lsp.get_client_by_id(tests_lsp):stop(true)

local executable
require("dap").adapters.ruby(function(adapter)
    executable = adapter.executable
end, { command = "bundle exec rspec spec/a_spec.rb:3", cwd = bundled })
check(executable.cwd == bundled, "rdbg starts in the project")
check(
    vim.deep_equal(
        vim.list_slice(executable.args, #executable.args - 2),
        { "sh", "-c", "bundle exec rspec spec/a_spec.rb:3" }
    ),
    "rdbg runs the lens command"
)
if vim.fn.executable("mise") == 1 then
    check(executable.command == "mise" and executable.args[3] == "rdbg", "rdbg from the project's Ruby")
end

-- Shell ------------------------------------------------------------------------
local bash = require("dap").configurations.sh
check(bash and bash[1].type == "bashdb" and bash[1].terminalKind == "integrated", "bash debug configuration")

local bashls = vim.lsp.config.bashls
local settings = vim.deepcopy(bashls.settings)
bashls.before_init({}, { root_dir = temporary .. "/scripts", settings = settings })
check(settings.bashIde.globPattern == "**/*@(.sh|.inc|.bash|.command)", "bashls indexes a project recursively")
settings = vim.deepcopy(bashls.settings)
bashls.before_init({}, { root_dir = vim.uv.os_homedir(), settings = settings })
check(settings.bashIde.globPattern == bashls.settings.bashIde.globPattern, "bashls stays shallow in $HOME")

local scripts = project("scripts", { ["deploy.sh"] = "#!/usr/bin/env bash\necho hi" })
vim.cmd.edit(vim.fn.fnameescape(scripts .. "/deploy.sh"))
local shfmt = require("conform").get_formatter_config("shfmt", 0)
local ctx = { buf = 0, dirname = scripts, shiftwidth = 2 }
vim.bo.expandtab = true
check(
    vim.deep_equal(shfmt.args(shfmt, ctx), { "-filename", "$FILENAME", "-i", "2", "-ci", "-bn" }),
    "shfmt Google style"
)
write(scripts .. "/.editorconfig", "root = true")
check(vim.deep_equal(shfmt.args(shfmt, ctx), { "-filename", "$FILENAME" }), "shfmt follows .editorconfig")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
local snippets = MiniSnippets.default_prepare(MiniSnippets.config.snippets)
local prefixes = vim.tbl_map(function(s)
    return s.prefix
end, snippets)
check(vim.list_contains(prefixes, "for_in"), "friendly-snippets shell snippets in a shell buffer")
check(vim.list_contains(prefixes, "cdate"), "personal global snippets in a shell buffer")

-- Indentation keeps string and heredoc bodies --------------------------------
local heredocs = {
    ["heredoc.rb"] = table.concat({
        "class Q",
        "  def sql",
        "    query = <<-SQL",
        "SELECT *",
        "  FROM t",
        "    SQL",
        '    msg = "first line',
        'second line"',
        "    query + msg",
        "  end",
        "end",
    }, "\n"),
    ["heredoc.sh"] = table.concat({
        "#!/usr/bin/env bash",
        "main() {",
        "  cat <<EOF",
        "line one",
        "  indented two",
        "EOF",
        "}",
    }, "\n"),
}
local indent_dir = project("indent", heredocs)
for name in pairs(heredocs) do
    vim.cmd.edit(vim.fn.fnameescape(indent_dir .. "/" .. name))
    local buf = vim.api.nvim_get_current_buf()
    check(vim.treesitter.highlighter.active[buf] ~= nil, name .. ": tree-sitter highlights")
    check(vim.bo.syntax == "ON", name .. ": regex syntax kept for the indent script")
    local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.cmd("silent normal! gg=G")
    check(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), before), name .. ": = keeps string bodies")
    vim.bo.modified = false
end

-- Ruby and shell editing helpers ---------------------------------------------
local helpers = project("helpers", {
    ["widget.rb"] = table.concat({
        "class Widget",
        "  def items",
        "    [1, 2].map { |i| i * 2 }",
        "  end",
        "",
        "  def each_twice",
        "    [1, 2].each do |i|",
        "      puts i",
        "    end",
        "  end",
        "end",
    }, "\n"),
    ["pipe.sh"] = table.concat({
        "#!/usr/bin/env bash",
        "if true; then",
        "  jq -r '.items[] | .name' data.json",
        "  awk -F: '{ print $1 }' /etc/passwd",
        "fi",
    }, "\n"),
})

local function yank(keys, row, col)
    vim.api.nvim_win_set_cursor(0, { row, col })
    vim.fn.setreg('"', "")
    vim.api.nvim_feedkeys(keys, "x", false)
    return vim.fn.getreg('"')
end

vim.cmd.edit(vim.fn.fnameescape(helpers .. "/widget.rb"))
check(yank("yao", 8, 6):match("^%[1, 2%]%.each do |i|") == nil, "ao on the block, not the line")
check(vim.startswith(vim.trim(yank("yao", 8, 6)), "do |i|"), "ao selects the do block around the cursor")
check(vim.startswith(yank("yac", 8, 6), "class Widget"), "ac selects the class")
check(vim.fn.maparg("gS", "n", false, true).buffer == 1, "Ruby buffers split/join with treesj")
check(vim.fn.maparg(" fp", "n", false, true).desc == "Project gems (ruby-lsp)", "gems picker in Ruby buffers")
vim.api.nvim_win_set_cursor(0, { 3, 18 })
vim.api.nvim_feedkeys("gS", "x", false)
local split = vim.api.nvim_buf_get_lines(0, 2, 5, false)
check(
    vim.trim(split[1]) == "[1, 2].map do |i|" and vim.trim(split[3]) == "end",
    "gS turns a brace block into do...end: " .. vim.inspect(split)
)
vim.api.nvim_win_set_cursor(0, { 3, (split[1]:find(" do ")) })
vim.api.nvim_feedkeys("gS", "x", false)
check(vim.trim(vim.api.nvim_buf_get_lines(0, 2, 3, false)[1]) == "[1, 2].map { |i| i * 2 }", "and back")
vim.bo.modified = false

write(
    helpers .. "/logic.rb",
    table.concat({
        "def check(value)",
        "  if value > 1",
        '    puts "big"',
        "  else",
        '    puts "small"',
        "  end",
        "end",
        "",
        "def total = items.sum",
        "",
        "h = { a: 1, b: 2 }",
    }, "\n")
)
vim.cmd.edit(vim.fn.fnameescape(helpers .. "/logic.rb"))
check(vim.startswith(yank("yao", 3, 4), "if value > 1"), "ao selects the if around the cursor")
check(vim.trim(yank("yio", 3, 4)) == 'puts "big"', "io selects its branch")
check(yank("yiF", 9, 16) == "items.sum", "iF selects an endless def's body")
vim.api.nvim_win_set_cursor(0, { 11, 5 })
vim.api.nvim_feedkeys("gS", "x", false)
check(
    vim.deep_equal(vim.api.nvim_buf_get_lines(0, 10, -1, false), { "h = {", "  a: 1,", "  b: 2", "}" }),
    "split hashes end without a comma: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 10, -1, false))
)
vim.bo.modified = false
check(vim.fn.maparg("<C-]>", "n") == "", "<C-]> jumps to ruby-lsp's definition")
check(vim.fn.maparg("aM", "o", false, true).rhs == "ac", "aM selects the tree-sitter class")
check(vim.g.ruby_indent_assignment_style == "variable" and vim.g.ruby_indent_hanging_elements == 0, "Standard indent")
local ruby_prefixes = vim.tbl_map(function(s)
    return s.prefix
end, MiniSnippets.default_prepare(MiniSnippets.config.snippets))
check(
    vim.list_contains(ruby_prefixes, "class")
        and not vim.list_contains(ruby_prefixes, "des")
        and not vim.list_contains(ruby_prefixes, "@param"),
    "Ruby snippets, without RSpec's or YARD's"
)
write(helpers .. "/widget_spec.rb", "")
vim.cmd.edit(vim.fn.fnameescape(helpers .. "/widget_spec.rb"))
local spec_prefixes = vim.tbl_map(function(s)
    return s.prefix
end, MiniSnippets.default_prepare(MiniSnippets.config.snippets))
check(vim.list_contains(spec_prefixes, "des"), "RSpec snippets in spec files")
vim.cmd.edit(vim.fn.fnameescape(bundled .. "/lib/widget.rb"))
check(vim.g.ruby_indent_assignment_style == "hanging" and vim.g.ruby_indent_hanging_elements == 1, "RuboCop indent")

vim.cmd.edit(vim.fn.fnameescape(helpers .. "/pipe.sh"))
check(vim.trim(yank("yao", 3, 4)):match("^if true; then"), "ao selects the shell if")
local parser = vim.treesitter.get_parser(0)
parser:parse(true)
local injected = parser:children()
check(injected.jq and injected.awk, "jq and awk programs are parsed as their languages")

local gems = ruby.gem_items({
    { name = "rake", version = "13.0", dependency = false, path = "/g/rake" },
    { name = "minitest", version = "6.0", dependency = true, path = "/g/minitest" },
})
check(gems[1].text == "minitest 6.0" and gems[2].text == "rake 13.0  (transitive)", "gems: direct first, marked")

local repl = require("repl")
vim.cmd.edit(vim.fn.fnameescape(helpers .. "/widget.rb"))
local cmd, cwd = repl.target()
check(cmd[#cmd] == "irb" and cwd == helpers, "Ruby REPL is irb from the project root")
vim.cmd.edit(vim.fn.fnameescape(bundled .. "/lib/widget.rb"))
cmd, cwd = repl.target()
check(
    vim.deep_equal(vim.list_slice(cmd, #cmd - 1), { "irb", "-rbundler/setup" }) and cwd == bundled,
    "the Ruby REPL loads the bundle"
)
vim.cmd.edit(vim.fn.fnameescape(helpers .. "/pipe.sh"))
vim.api.nvim_buf_set_lines(0, 5, 5, false, { "", "echo repl_$((40 + 2))", "echo second" })
check(#repl.paragraph(7) == 2, "paragraph around the cursor")
repl.send(repl.paragraph(7))
local terminal
vim.wait(10000, function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == "terminal" then
            local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
            if text:find("repl_42", 1, true) and text:find("\nsecond", 1, true) then
                terminal = buf
                return true
            end
        end
    end
end, 100)
check(terminal, "the shell REPL runs what is sent")
vim.fn.jobstop(vim.bo[terminal].channel)
vim.bo.modified = false

-- mini.snippets' in-process server speaks byte offsets ------------------------
local snippet_client = vim.lsp.get_clients({ name = "mini.snippets" })[1]
check(snippet_client and snippet_client.offset_encoding == "utf-8", "snippet server encoding")

vim.cmd("silent! %bwipeout!")
vim.fn.delete(temporary, "rf")
print(string.format("PASS %d language checks", checks))
vim.cmd("qa!")
