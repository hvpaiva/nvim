vim.g["test#strategy"] = "neovim_sticky"
vim.g["test#neovim#start_normal"] = 1
vim.g["test#neovim#term_position"] = "botright 12"
vim.g["test#neovim_sticky#reopen_window"] = 1
vim.cmd([[
function! NvimTestInProject(command) abort
    let command = executable('mise') ? 'mise exec -- sh -c ' . shellescape(a:command) : a:command
    return 'cd ' . shellescape(getcwd()) . ' && ' . command
endfunction
let g:test#custom_transformations = {'project': function('NvimTestInProject')}
let g:test#transformation = 'project'
]])

vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("hvpaiva-haskell-test-runner", { clear = true }),
    pattern = { "*.hs", "*.lhs" },
    callback = function(ev)
        local root = vim.fs.root(ev.buf, { "stack.yaml", "cabal.project", ".git" }) or vim.fn.getcwd()
        vim.g["test#haskell#runner"] = vim.fn.filereadable(root .. "/stack.yaml") == 1 and "stacktest" or "cabaltest"
    end,
})

local projections = {
    ["lib/*.rb"] = {
        alternate = { "spec/{}_spec.rb", "test/{}_test.rb", "test/{dirname}/test_{basename}.rb" },
    },
    ["spec/*_spec.rb"] = { alternate = { "lib/{}.rb", "{}.rb" } },
    ["test/*_test.rb"] = { alternate = { "lib/{}.rb", "{}.rb" } },
    ["test/**/test_*.rb"] = { alternate = { "lib/{}.rb", "{}.rb" } },
    ["*.rb"] = { alternate = { "spec/{}_spec.rb", "test/{}_test.rb", "test/{dirname}/test_{basename}.rb" } },
    ["*.go"] = { alternate = "{}_test.go" },
    ["*_test.go"] = { alternate = "{}.go" },
    ["src/*.rs"] = { alternate = { "tests/{}.rs", "tests/{}_test.rs" } },
    ["tests/*.rs"] = { alternate = "src/{}.rs" },
    ["tests/*_test.rs"] = { alternate = "src/{}.rs" },
    ["src/*.hs"] = { alternate = { "test/{}Spec.hs", "tests/{}Spec.hs", "spec/{}Spec.hs" } },
    ["test/*Spec.hs"] = { alternate = { "src/{}.hs", "{}.hs" } },
    ["tests/*Spec.hs"] = { alternate = { "src/{}.hs", "{}.hs" } },
    ["spec/*Spec.hs"] = { alternate = { "src/{}.hs", "{}.hs" } },
    ["*.hs"] = { alternate = { "test/{}Spec.hs", "tests/{}Spec.hs", "spec/{}Spec.hs" } },
    ["lua/*.lua"] = { alternate = { "tests/{}_spec.lua", "spec/{}_spec.lua", "tests/test_{}.lua" } },
    ["tests/*_spec.lua"] = { alternate = { "lua/{}.lua", "{}.lua" } },
    ["spec/*_spec.lua"] = { alternate = { "lua/{}.lua", "{}.lua" } },
    ["tests/test_*.lua"] = { alternate = { "lua/{}.lua", "{}.lua" } },
    ["*.sh"] = { alternate = { "tests/{}.bats", "test/{}.bats", "spec/{}_spec.sh" } },
    ["tests/*.bats"] = { alternate = { "{}.sh", "scripts/{}.sh", "bin/{}" } },
    ["test/*.bats"] = { alternate = { "{}.sh", "scripts/{}.sh", "bin/{}" } },
    ["spec/*_spec.sh"] = { alternate = { "{}.sh", "scripts/{}.sh" } },
    ["src/*.py"] = { alternate = { "tests/{dirname}/test_{basename}.py", "tests/{}_test.py" } },
    ["*.py"] = { alternate = { "tests/{dirname}/test_{basename}.py", "{dirname}/test_{basename}.py", "{}_test.py" } },
    ["tests/**/test_*.py"] = { alternate = { "src/{}.py", "{}.py" } },
    ["tests/*_test.py"] = { alternate = { "src/{}.py", "{}.py" } },
    ["**/test_*.py"] = { alternate = "{}.py" },
    ["*_test.py"] = { alternate = "{}.py" },
}

for _, extension in ipairs({ "js", "jsx", "ts", "tsx" }) do
    projections["*." .. extension] = {
        alternate = {
            "{}.test." .. extension,
            "{}.spec." .. extension,
            "{dirname}/__tests__/{basename}.test." .. extension,
            "{dirname}/__tests__/{basename}." .. extension,
        },
    }
    for _, suffix in ipairs({ "test", "spec" }) do
        projections["*." .. suffix .. "." .. extension] = { alternate = "{}." .. extension }
        projections["**/__tests__/*." .. suffix .. "." .. extension] = { alternate = "{}." .. extension }
    end
    projections["**/__tests__/*." .. extension] = { alternate = "{}." .. extension }
end

vim.g.projectionist_heuristics = {
    [".git/|.git|Gemfile|gems.rb|*.gemspec|go.mod|Cargo.toml|package.json|pyproject.toml|cabal.project|stack.yaml|*.cabal|Makefile"] = projections,
}

local function map(suffix, command, desc)
    vim.keymap.set("n", "<leader>" .. suffix, "<Cmd>" .. command .. "<CR>", { desc = desc })
end

local last_root
local last_state = {}
local state_keys = { "test#last_position", "test#last_command", "test#last_strategy" }
local function test_map(suffix, command, desc)
    vim.keymap.set("n", "<leader>" .. suffix, function()
        local replay = command == "TestLast" or command == "TestVisit"
        local root = replay and last_root
            or vim.fs.root(0, {
                "Gemfile",
                "gems.rb",
                "go.mod",
                "Cargo.toml",
                "package.json",
                "pyproject.toml",
                "stack.yaml",
                "cabal.project",
                ".git",
            })
        root = root or vim.fn.getcwd()
        if not replay then
            for _, key in ipairs(state_keys) do
                vim.g[key] = (last_state[root] or {})[key]
            end
        elseif last_root then
            for _, key in ipairs(state_keys) do
                vim.g[key] = last_state[last_root][key]
            end
        end
        local cwd = vim.fn.getcwd()
        vim.cmd.lcd(root)
        local ok, err = pcall(vim.cmd, command)
        if not replay and vim.g["test#last_command"] then
            last_root = root
            last_state[root] = {}
            for _, key in ipairs(state_keys) do
                last_state[root][key] = vim.g[key]
            end
        end
        if command ~= "TestVisit" then
            vim.cmd.lcd(cwd)
        end
        if not ok then
            vim.notify(tostring(err), vim.log.levels.ERROR)
        end
    end, { desc = desc })
end

test_map("tt", "TestNearest", "Run nearest test")
test_map("tf", "TestFile", "Run test file")
test_map("ts", "TestSuite", "Run test suite")
test_map("tl", "TestLast", "Repeat last test")
test_map("tv", "TestVisit", "Visit last test")
map("ta", "A", "Alternate source/test")
map("tA", "AV", "Alternate source/test in split")
