local dap = require("dap")

local function root()
    return vim.fs.root(0, {
        "Gemfile",
        "gems.rb",
        "go.mod",
        "Cargo.toml",
        "package.json",
        "pyproject.toml",
        "cabal.project",
        ".git",
    }) or vim.fn.getcwd()
end

-- rdbg comes from the project's Ruby (`mise x` resolves it from the working
-- directory, as for ruby-lsp): the debug gem it injects is a C extension tied
-- to that Ruby's ABI. A `command` (from ruby-lsp's "Debug" test lens) runs as
-- given; otherwise the file runs with Ruby or RSpec, under Bundler when the
-- project has a Gemfile.
dap.adapters.ruby = function(callback, config)
    local args = { "--open", "--host", "127.0.0.1", "--port", "${port}", "-c", "--" }
    if config.command then
        vim.list_extend(args, { "sh", "-c", config.command })
    else
        if require("ruby_tools").bundle_root(config.program) then
            vim.list_extend(args, { "bundle", "exec" })
        end
        vim.list_extend(args, config.runner == "rspec" and { "rspec" } or { "ruby", "-Ilib", "-Itest" })
        args[#args + 1] = config.program
        vim.list_extend(args, config.args or {})
    end
    local command = "rdbg"
    if vim.fn.executable("mise") == 1 then
        command, args = "mise", vim.list_extend({ "x", "--", "rdbg" }, args)
    end
    callback({
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = { command = command, args = args, cwd = config.cwd },
    })
end

dap.configurations.ruby = {
    {
        name = "Ruby: current file / Minitest",
        type = "ruby",
        request = "attach",
        program = "${file}",
        cwd = root,
        localfs = true,
    },
    {
        name = "Ruby: RSpec file",
        type = "ruby",
        request = "attach",
        runner = "rspec",
        program = "${file}",
        cwd = root,
        localfs = true,
    },
}

dap.adapters.go = {
    type = "server",
    port = "${port}",
    executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
}
dap.configurations.go = {
    {
        name = "Go: current package",
        type = "go",
        request = "launch",
        mode = "debug",
        buildFlags = "-buildvcs=false",
        program = "${fileDirname}",
        cwd = root,
    },
    {
        name = "Go: package tests",
        type = "go",
        request = "launch",
        mode = "test",
        buildFlags = "-buildvcs=false",
        program = "${fileDirname}",
        cwd = root,
    },
}

dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = { command = "codelldb", args = { "--port", "${port}" } },
}
for _, ft in ipairs({ "c", "cpp", "rust" }) do
    dap.configurations[ft] = {
        {
            name = "Debug executable",
            type = "codelldb",
            request = "launch",
            program = function()
                local program = vim.fn.input("Executable: ", root() .. "/", "file")
                return program ~= "" and vim.fn.fnamemodify(program, ":p") or dap.ABORT
            end,
            cwd = root,
            stopOnEntry = true,
        },
    }
end

dap.adapters.python = { type = "executable", command = "debugpy-adapter" }
dap.configurations.python = {
    {
        name = "Python: current file",
        type = "python",
        request = "launch",
        program = "${file}",
        cwd = root,
        console = "integratedTerminal",
        pythonPath = function()
            local venv = root() .. "/.venv/bin/python"
            return vim.fn.executable(venv) == 1 and venv or vim.fn.exepath("python3")
        end,
    },
}

dap.adapters["pwa-node"] = function(callback)
    local result = vim.system({ "mise", "where", "github:microsoft/vscode-js-debug" }, { text = true }):wait()
    local server = vim.trim(result.stdout or "") .. "/src/dapDebugServer.js"
    if result.code ~= 0 or vim.fn.filereadable(server) ~= 1 then
        vim.notify("JavaScript debugger missing. Run scripts/nvim-debug-install.", vim.log.levels.ERROR)
        return
    end
    callback({
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = { command = "node", args = { server, "${port}", "127.0.0.1" } },
    })
end
dap.adapters.node = dap.adapters["pwa-node"]
for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
    dap.configurations[ft] = {
        {
            name = "Node: current file",
            type = "pwa-node",
            request = "launch",
            program = "${file}",
            cwd = root,
            sourceMaps = true,
            console = "integratedTerminal",
        },
        {
            name = "Node: attach to process",
            type = "pwa-node",
            request = "attach",
            processId = require("dap.utils").pick_process,
            cwd = root,
            sourceMaps = true,
        },
    }
end

local function debug_nearest_test()
    if vim.bo.filetype == "ruby" then
        require("ruby_tools").debug_nearest_test()
    else
        vim.notify("Debug nearest test is not set up for " .. vim.bo.filetype, vim.log.levels.WARN)
    end
end

local function map(suffix, action, desc)
    vim.keymap.set("n", "<leader>r" .. suffix, action, { desc = desc })
end

map("r", dap.continue, "Debug: start / continue")
map("b", dap.toggle_breakpoint, "Toggle breakpoint")
map("B", function()
    vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
        if condition and condition ~= "" then
            dap.set_breakpoint(condition)
        end
    end)
end, "Conditional breakpoint")
map("n", dap.step_over, "Step over")
map("i", dap.step_into, "Step into")
map("o", dap.step_out, "Step out")
map("q", dap.terminate, "Stop debugging")
map("l", dap.run_last, "Repeat debug session")
map("t", debug_nearest_test, "Debug nearest test")
map("c", dap.repl.toggle, "Debug console")
map("s", function()
    local widgets = require("dap.ui.widgets")
    widgets.centered_float(widgets.scopes)
end, "Inspect scopes")
vim.keymap.set({ "n", "x" }, "<leader>re", require("dap.ui.widgets").hover, { desc = "Inspect value" })
