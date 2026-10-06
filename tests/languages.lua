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
-- versions that do not exist: keep ruby-lsp and bashls from starting.
vim.lsp.enable({ "ruby_lsp", "bashls" }, false)

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
vim.cmd.edit(vim.fn.fnameescape(bundled .. "/lib/widget.rb"))
local linter = ruby.linter("rubocop")()
check(linter.cmd == "bundle" and linter.args[1] == "exec" and linter.args[2] == "rubocop", "lint with the bundle")
check(vim.list_contains(linter.args, "--server"), "linter keeps nvim-lint's arguments")
ruby.linter("rubocop")()
local servers = ruby.servers()
check(#servers == 1 and servers[1].cwd == bundled, "one daemon tracked per project and command")
check(vim.deep_equal(servers[1].argv, { "bundle", "exec", "rubocop" }), "daemon stopped through the same command")
local standalone = ruby.linter("standardrb")
vim.cmd.edit(vim.fn.fnameescape(temporary .. "/standalone/script.rb"))
check(standalone().cmd == "standardrb", "standalone lint with the global tool")

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
check(params.initializationOptions.linters == nil, "ruby-lsp detects RuboCop itself")

-- Test code lenses -------------------------------------------------------------
local test_file = bundled .. "/test/widget_test.rb"
local function lens(command, start_line, end_line, name)
    return {
        command = {
            command = command,
            arguments = {
                test_file,
                name,
                "bundle exec ruby -Itest " .. test_file .. ' --name "/' .. name .. '/"',
                { start_line = start_line, start_column = 0, end_line = end_line, end_column = 3 },
                name,
            },
        },
    }
end
local lenses = {
    lens("rubyLsp.runTest", 5, 12, "WidgetTest"),
    lens("rubyLsp.debugTest", 5, 12, "WidgetTest"),
    lens("rubyLsp.debugTest", 6, 8, "test_value"),
    lens("rubyLsp.debugTest", 9, 11, "test_other"),
}
check(ruby.nearest_debug_lens(lenses, 7).arguments[2] == "test_value", "innermost test around the cursor")
check(ruby.nearest_debug_lens(lenses, 12).arguments[2] == "WidgetTest", "group when outside every test")
check(ruby.nearest_debug_lens(lenses, 2) == nil, "nothing before the first test")

local debug = ruby.debug_test_config(lenses[3].command)
check(debug.type == "ruby" and debug.request == "attach" and debug.cwd == bundled, "debug lens configuration")
check(debug.command == lenses[3].command.arguments[3], "debug lens runs the lens command")

vim.cmd([[
function! LanguagesCapture(command) abort
    let g:languages_captured = a:command
endfunction
let g:test#custom_strategies = {'languages': function('LanguagesCapture')}
]])
local strategy = vim.g["test#strategy"]
vim.g["test#strategy"] = "languages"
local cwd = vim.fn.getcwd()
ruby.run_test_lens(lenses[3].command)
vim.g["test#strategy"] = strategy
check(vim.g.languages_captured:find("cd '" .. bundled .. "'", 1, true), "run lens from the project root")
check(vim.g.languages_captured:find('--name "/test_value/"', 1, true), "run lens keeps the test filter")
check(vim.fn.getcwd() == cwd, "run lens restores the working directory")

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

-- mini.snippets' in-process server speaks byte offsets ------------------------
local snippet_client = vim.lsp.get_clients({ name = "mini.snippets" })[1]
check(snippet_client and snippet_client.offset_encoding == "utf-8", "snippet server encoding")

vim.cmd("silent! %bwipeout!")
vim.fn.delete(temporary, "rf")
print(string.format("PASS %d language checks", checks))
vim.cmd("qa!")
