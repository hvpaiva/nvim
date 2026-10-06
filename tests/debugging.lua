vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd.packadd("nvim-dap")
require("debugging")
local dap = require("dap")
dap.set_log_level("DEBUG")
local language = assert(vim.env.NVIM_DEBUG_TEST_LANGUAGE, "Set NVIM_DEBUG_TEST_LANGUAGE")
local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, "p")

local cases = {
    ruby = { ft = "ruby", file = "main.rb", source = "value = 40\nvalue += 2\nputs value", line = 3 },
    ruby_bundle = {
        ft = "ruby",
        file = "main.rb",
        source = "value = 40\nvalue += 2\nputs value",
        line = 3,
        bundle = true,
    },
    go = {
        ft = "go",
        file = "main.go",
        source = 'package main\nimport "fmt"\nfunc main() {\n value := 40\n value += 2\n fmt.Println(value)\n}',
        line = 6,
    },
    rust = {
        ft = "rust",
        file = "main.rs",
        source = 'fn main() {\n let mut value = 40;\n value += 2;\n println!("{value}");\n}',
        line = 4,
    },
    python = { ft = "python", file = "main.py", source = "value = 40\nvalue += 2\nprint(value)", line = 3 },
    bash = {
        ft = "sh",
        file = "main.sh",
        source = '#!/usr/bin/env bash\nvalue=40\nvalue=$((value + 2))\necho "$value"',
        line = 4,
        expression = "$value",
        expected = "'42'",
    },
    javascript = {
        ft = "javascript",
        file = "main.js",
        source = 'let value = 40;\nvalue += 2;\nconsole.log(value);\nconsole.log("done");',
        line = 3,
    },
    typescript = {
        ft = "typescript",
        file = "main.ts",
        source = 'let value: number = 40;\nvalue += 2;\nconsole.log(value);\nconsole.log("done");',
        line = 3,
    },
}
local case = assert(cases[language], "Unknown language")
local filename = temporary .. "/" .. case.file
vim.fn.writefile(vim.split(case.source, "\n", { plain = true }), filename)
vim.cmd.cd(temporary)
vim.cmd.edit(filename)
vim.bo.filetype = case.ft
vim.api.nvim_win_set_cursor(0, { case.line, 0 })
dap.toggle_breakpoint()

if case.ft == "go" then
    vim.fn.writefile({ "module workflow.test/debug", "go 1.22" }, temporary .. "/go.mod")
end
if case.bundle then
    vim.fn.writefile({ 'source "https://rubygems.org"', 'gem "debug"' }, temporary .. "/Gemfile")
    local result = vim.system({ "bundle", "lock", "--local" }, { cwd = temporary, text = true }):wait()
    assert(result.code == 0, result.stderr)
end

local config = vim.deepcopy(dap.configurations[case.ft][1])
config.cwd = temporary
config.program = filename
if case.ft == "go" then
    config.program = temporary
elseif case.ft == "rust" then
    config.program = temporary .. "/debug-test"
    local result = vim.system({ "rustc", "-g", "-C", "opt-level=0", "-o", config.program, filename }, { text = true })
        :wait()
    assert(result.code == 0, result.stderr)
end

local stopped = 0
local terminated = false
local output = {}
dap.listeners.after.event_output["workflow-test"] = function(_, body)
    output[#output + 1] = body.output
end
dap.listeners.after.event_stopped["workflow-test"] = function()
    stopped = stopped + 1
end
dap.listeners.after.event_terminated["workflow-test"] = function()
    terminated = true
end

local function request(session, command, arguments)
    local done, response, failure = false, nil, nil
    session:request(command, arguments, function(err, body)
        failure, response, done = err, body, true
    end)
    assert(
        vim.wait(10000, function()
            return done
        end, 20),
        "Timeout: " .. command
    )
    assert(not failure, vim.inspect(failure))
    return response
end

local ok, failure = xpcall(function()
    dap.run(config)
    assert(
        vim.wait(30000, function()
            return stopped > 0 or terminated
        end, 20),
        "Debugger did not stop"
    )
    assert(not terminated, "Debuggee exited before breakpoint")
    local session = assert(dap.session(), "No debug session")
    assert(
        vim.wait(10000, function()
            return session.initialized
        end, 20),
        "Session did not finish initialization"
    )
    local frame
    for _ = 1, 4 do
        local threads = request(session, "threads", vim.empty_dict())
        local trace = request(session, "stackTrace", { threadId = session.stopped_thread_id or threads.threads[1].id })
        frame = trace.stackFrames[1]
        if frame.line == case.line and frame.source and frame.source.path == filename then
            break
        end
        local previous = stopped
        dap.continue()
        assert(
            vim.wait(10000, function()
                return stopped > previous or terminated
            end, 20),
            "No next stop"
        )
        assert(not terminated, "Debuggee exited before expected breakpoint")
    end
    assert(frame.line == case.line, "Wrong breakpoint: " .. vim.inspect(frame))
    local result =
        request(session, "evaluate", { expression = case.expression or "value", frameId = frame.id, context = "hover" })
    assert(result.result == (case.expected or "42"), "Wrong value: " .. vim.inspect(result))
    local previous = stopped
    dap.step_over()
    assert(
        vim.wait(10000, function()
            return stopped > previous or terminated
        end, 20),
        "Step over timed out"
    )
    print("PASS " .. language .. ": breakpoint, evaluate value=42, step over")
end, debug.traceback)

dap.terminate()
vim.wait(5000, function()
    return dap.session() == nil
end, 20)
vim.cmd.cd(vim.fn.stdpath("config"))
vim.cmd("%bwipeout!")
vim.fn.delete(temporary, "rf")
assert(ok, tostring(failure) .. "\n" .. table.concat(output))
