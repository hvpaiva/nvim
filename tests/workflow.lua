vim.opt.rtp:prepend(vim.fn.getcwd())
vim.g.mapleader = " "
for _, plugin in ipairs({ "vim-test", "vim-projectionist", "nvim-dap", "hardtime.nvim", "precognition.nvim" }) do
    vim.cmd.packadd(plugin)
end
require("workflow")
require("debugging")
require("training")
vim.cmd("filetype plugin on")

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

vim.cmd([[
function! CaptureTest(command) abort
    let g:captured_test = a:command
endfunction
let g:test#custom_strategies = {'capture': function('CaptureTest')}
]])
vim.g["test#strategy"] = "capture"

local fixtures = {
    {
        name = "ruby_minitest",
        files = {
            Gemfile = 'source "https://rubygems.org"\ngem "minitest"',
            ["lib/widget.rb"] = "class Widget\nend",
            ["test/widget_test.rb"] = "require 'minitest/autorun'\nclass WidgetTest < Minitest::Test\n  def test_value\n    assert_equal 2, 1 + 1\n  end\nend",
        },
        source = "lib/widget.rb",
        test = "test/widget_test.rb",
        line = 4,
        runner = "bundle exec ruby",
        nearest = "test_value",
    },
    {
        name = "ruby_rspec",
        files = {
            Gemfile = 'source "https://rubygems.org"\ngem "rspec"',
            ["lib/widget.rb"] = "class Widget\nend",
            ["spec/widget_spec.rb"] = "RSpec.describe 'Widget' do\n  it 'works' do\n    expect(1 + 1).to eq(2)\n  end\nend",
        },
        source = "lib/widget.rb",
        test = "spec/widget_spec.rb",
        line = 3,
        runner = "bundle exec rspec",
        nearest = ":3",
    },
    {
        name = "go",
        files = {
            ["go.mod"] = "module workflow.test/widget\ngo 1.22",
            ["widget.go"] = "package widget",
            ["widget_test.go"] = 'package widget\nimport "testing"\nfunc TestValue(t *testing.T) {\n  if 1 + 1 != 2 { t.Fatal("wrong value") }\n}',
        },
        source = "widget.go",
        test = "widget_test.go",
        line = 4,
        runner = "go test",
        nearest = "TestValue",
    },
    {
        name = "rust",
        files = {
            ["Cargo.toml"] = '[package]\nname = "workflow-test"\nversion = "0.1.0"\nedition = "2021"',
            ["src/lib.rs"] = "pub fn value() -> i32 { 2 }",
            ["src/widget.rs"] = "pub fn value() -> i32 { 2 }",
            ["tests/widget.rs"] = "#[test]\nfn value() {\n    assert_eq!(1 + 1, 2);\n}",
        },
        source = "src/widget.rs",
        test = "tests/widget.rs",
        line = 3,
        runner = "cargo",
        nearest = "value",
    },
    {
        name = "javascript",
        files = {
            ["package.json"] = '{"devDependencies":{"jest":"*"}}',
            ["node_modules/.bin/jest"] = "",
            ["src/widget.js"] = "export const value = 2;",
            ["src/widget.test.js"] = "describe('Widget', () => {\n  it('works', () => {\n    expect(1 + 1).toBe(2);\n  });\n});",
        },
        source = "src/widget.js",
        test = "src/widget.test.js",
        line = 3,
        runner = "jest",
        nearest = "works",
    },
    {
        name = "typescript",
        files = {
            ["package.json"] = '{"devDependencies":{"vitest":"*"}}',
            ["node_modules/.bin/vitest"] = "",
            ["src/widget.ts"] = "export const value: number = 2;",
            ["src/widget.spec.ts"] = "import { it, expect } from 'vitest';\nit('works', () => {\n  expect(1 + 1).toBe(2);\n});",
        },
        source = "src/widget.ts",
        test = "src/widget.spec.ts",
        line = 3,
        runner = "vitest",
        nearest = "works",
    },
    {
        name = "python",
        files = {
            ["pyproject.toml"] = "[tool.pytest.ini_options]",
            ["src/widget.py"] = "value = 2",
            ["tests/test_widget.py"] = "def test_value():\n    assert 1 + 1 == 2",
        },
        source = "src/widget.py",
        test = "tests/test_widget.py",
        line = 2,
        runner = "pytest",
        nearest = "test_value",
    },
    {
        name = "haskell",
        files = {
            ["widget.cabal"] = "cabal-version: 2.4\nname: widget\nversion: 0.1.0.0\nbuild-type: Simple\ntest-suite widget-test\n  type: exitcode-stdio-1.0\n  main-is: WidgetSpec.hs\n  hs-source-dirs: test\n  build-depends: base\n  default-language: Haskell2010",
            ["cabal.project"] = "packages: .",
            ["src/Widget.hs"] = "module Widget where\nvalue = 2",
            ["test/WidgetSpec.hs"] = 'module Main where\nmain :: IO ()\nmain = if 1 + 1 == 2 then putStrLn "PASS" else error "FAIL"',
        },
        source = "src/Widget.hs",
        test = "test/WidgetSpec.hs",
        line = 3,
        runner = "cabal",
        nearest = "test",
    },
    {
        name = "lua",
        files = {
            ["lua/widget.lua"] = "return 2",
            ["tests/widget_spec.lua"] = 'describe("Widget", function()\n  it("works", function()\n    assert.are.equal(2, 1 + 1)\n  end)\nend)',
        },
        source = "lua/widget.lua",
        test = "tests/widget_spec.lua",
        line = 3,
        runner = "busted",
        nearest = "works",
    },
    {
        name = "shell",
        files = {
            ["widget.sh"] = "printf '%s\\n' 2",
            ["tests/widget.bats"] = '@test "works" {\n  [ "$((1 + 1))" -eq 2 ]\n}',
        },
        source = "widget.sh",
        test = "tests/widget.bats",
        line = 2,
        runner = "bats",
        nearest = "works",
    },
}

for _, fixture in ipairs(fixtures) do
    local dir = project(fixture.name, fixture.files)
    vim.cmd.cd(dir)
    vim.cmd.edit(dir .. "/" .. fixture.source)
    vim.cmd.A()
    check(vim.api.nvim_buf_get_name(0) == dir .. "/" .. fixture.test, fixture.name .. ": source -> test")
    vim.cmd.A()
    check(vim.api.nvim_buf_get_name(0) == dir .. "/" .. fixture.source, fixture.name .. ": test -> source")
    vim.cmd.TestFile()
    check(
        (vim.g.captured_test or ""):find(fixture.runner, 1, true),
        fixture.name .. ": test from source: " .. tostring(vim.g.captured_test)
    )
    vim.cmd.edit(dir .. "/" .. fixture.test)
    vim.api.nvim_win_set_cursor(0, { fixture.line, 0 })
    vim.cmd.normal({ args = { " tt" }, bang = false })
    local nearest = vim.g.captured_test or ""
    check(nearest:find(fixture.runner, 1, true), fixture.name .. ": runner: " .. nearest)
    check(nearest:find(fixture.nearest, 1, true), fixture.name .. ": nearest: " .. nearest)
    vim.cmd.normal({ args = { " tl" }, bang = false })
    check(vim.g.captured_test == nearest, fixture.name .. ": repeat last test")
    vim.cmd.normal({ args = { " tf" }, bang = false })
    check(vim.g.captured_test:find(fixture.runner, 1, true), fixture.name .. ": file")
    vim.cmd.normal({ args = { " ts" }, bang = false })
    check(vim.g.captured_test:find(fixture.runner, 1, true), fixture.name .. ": suite")
    print("PASS " .. fixture.name .. " " .. nearest)
end

local last_command = vim.g.captured_test
vim.cmd.edit(temporary .. "/ruby_minitest/lib/widget.rb")
vim.cmd.normal({ args = { " tl" }, bang = false })
check(vim.g.captured_test == last_command, "repeat last test keeps its original project")
vim.cmd.normal({ args = { " tf" }, bang = false })
check(vim.g.captured_test:find("ruby_minitest", 1, true), "switching project selects its own tests")

local stack = project("haskell_stack", {
    ["stack.yaml"] = "resolver: lts-24.0",
    ["src/Widget.hs"] = "module Widget where",
    ["test/WidgetSpec.hs"] = 'module Main where\nmain = putStrLn "PASS"',
})
vim.cmd.cd(stack)
vim.cmd.edit(stack .. "/test/WidgetSpec.hs")
vim.cmd.normal({ args = { " tf" }, bang = false })
check(vim.g.captured_test:find("stack test", 1, true), "Stack runner follows stack.yaml")

local ruby = require("ruby_tools")
local formatter = ruby.formatter("rubocop", "rubocop")
local dir = project("format ruby with spaces", {
    Gemfile = 'gem "rubocop"',
    ["Gemfile.lock"] = "GEM\n  specs:\n    rubocop (1.84.2)",
    ["lib/widget.rb"] = "value=2",
})
local ctx = { filename = dir .. "/lib/widget.rb" }
check(formatter.command(nil, ctx) == "bundle", "format with project's bundle")
check(vim.deep_equal(formatter.prepend_args(nil, ctx), { "exec", "rubocop" }), "bundle exec arguments")
check(formatter.cwd(nil, ctx) == dir, "formatter cwd follows buffer, not editor cwd")
write(dir .. "/bin/rubocop", "#!/bin/sh\nexit 0")
vim.fn.setfperm(dir .. "/bin/rubocop", "rwxr-xr-x")
check(formatter.command(nil, ctx) == dir .. "/bin/rubocop", "prefer executable project binstub")
check(#formatter.prepend_args(nil, ctx) == 0, "binstub has no bundle prefix")
local standalone = project("standalone", { ["widget.rb"] = "value=2" })
check(formatter.command(nil, { filename = standalone .. "/widget.rb" }) == "rubocop", "standalone global formatter")
local no_formatter = project(
    "without formatter",
    { Gemfile = 'gem "minitest"', ["Gemfile.lock"] = "GEM\n  specs:\n    minitest (6.0.6)" }
)
check(
    formatter.command(nil, { filename = no_formatter .. "/widget.rb" }) == "rubocop",
    "fallback when bundle lacks formatter"
)

check(vim.fn.maparg(" pp", "n"):find("Training Start", 1, true), "training moved to p")
check(vim.fn.maparg(" tt", "n", false, true).desc == "Run nearest test", "tests own t")
for _, suffix in ipairs({ "pS", "pa", "pb", "pT", "ph", "pH", "pd", "pr" }) do
    check(not vim.tbl_isempty(vim.fn.maparg(" " .. suffix, "n", false, true)), "training map " .. suffix)
end
for _, ft in ipairs({
    "ruby",
    "go",
    "rust",
    "c",
    "cpp",
    "python",
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
}) do
    check(#require("dap").configurations[ft] > 0, "debug configuration for " .. ft)
end
check(vim.fn.maparg(" rr", "n", false, true).callback == require("dap").continue, "language-independent debug binding")
check(vim.fn.maparg(" d", "n") == "", "workflow does not claim the delete prefix")

vim.cmd.cd(vim.fn.stdpath("config"))
vim.cmd("%bwipeout!")
vim.fn.delete(temporary, "rf")
print(string.format("PASS %d workflow checks", checks))
