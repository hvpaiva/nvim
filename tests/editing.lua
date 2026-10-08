-- Editing behavior shared by every language, and the language tooling setup,
-- checked against the full config. Run from the config directory (see
-- README.md, Verification). Language servers are kept from starting: this
-- covers configuration and editor behavior; servers are exercised by hand.
local new_servers = { "basedpyright", "ruff", "terraformls", "tflint", "taplo", "eslint" }
local enabled = {}
for _, name in ipairs(new_servers) do
    enabled[name] = vim.lsp.is_enabled(name)
end
vim.lsp.enable({
    "lua_ls",
    "bashls",
    "tsc",
    "eslint",
    "gopls",
    "rust_analyzer",
    "jsonls",
    "yamlls",
    "docker_language_server",
    "basedpyright",
    "ruff",
    "terraformls",
    "tflint",
    "taplo",
    "marksman",
}, false)

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

local function feed(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "x", false)
end

-- A throwaway buffer. `nofile`: with 'confirm' set, leaving a modified named-
-- less buffer would otherwise answer "Save changes?" and write ./Untitled.
local function scratch(lines, filetype)
    vim.cmd("enew!")
    vim.bo.buftype = "nofile"
    vim.bo.bufhidden = "wipe"
    if filetype then
        vim.bo.filetype = filetype
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Mappings -------------------------------------------------------------------
scratch({ "foo bar" })
vim.fn.setreg('"', "baz", "c")
vim.api.nvim_win_set_cursor(0, { 1, 4 })
feed("vep")
check(vim.deep_equal(lines(), { "foo baz" }), "visual p at the end of a line: " .. vim.inspect(lines()))
check(vim.fn.getreg('"') == "baz", "visual p keeps the register")

scratch({ "one", "two", "three" })
vim.fn.setreg('"', "NEW\n", "l")
vim.api.nvim_win_set_cursor(0, { 3, 0 })
feed("Vp")
check(vim.deep_equal(lines(), { "one", "two", "NEW" }), "visual p on the last line: " .. vim.inspect(lines()))

scratch({ 'call(arg_one, "quoted text", other)' })
local yanks = { iq = { 16, "quoted text" }, ia = { 6, "arg_one" }, ["i("] = { 7, 'arg_one, "quoted text", other' } }
for obj, case in pairs(yanks) do
    vim.fn.setreg('"', "")
    vim.api.nvim_win_set_cursor(0, { 1, case[1] })
    feed(" y" .. obj)
    check(vim.fn.getreg('"') == case[2], "<Leader>y" .. obj .. ": " .. vim.fn.getreg('"'))
    check(vim.api.nvim_win_get_cursor(0)[2] == case[1], "<Leader>y" .. obj .. " keeps the cursor")
end

scratch({ "  first", "  second", "  third", "fourth" })
vim.api.nvim_win_set_cursor(0, { 1, 4 })
feed("3J")
check(vim.deep_equal(lines(), { "  first second third", "fourth" }), "J joins its count: " .. vim.inspect(lines()))
check(vim.api.nvim_win_get_cursor(0)[2] == 4, "J keeps the cursor")
check(vim.fn.getpos("'z")[2] == 0, "J leaves mark z alone")

check(vim.fn.maparg(" oc", "n"):find("%:S", 1, true), "chmod escapes the file name")
check(vim.fn.maparg("an", "x", false, true).desc == "Select parent (outer) node", "visual an is incremental selection")
check(vim.fn.maparg("in", "x", false, true).desc == "Select child (inner) node", "visual in is incremental selection")
check(not vim.tbl_isempty(vim.fn.maparg("aN", "x", false, true)), "mini.ai next text objects on aN/iN")

check(vim.fn.maparg("<M-Space>", "i", false, true).desc == "Complete with two-stage", "<M-Space> asks for completion")
check(vim.tbl_isempty(vim.fn.maparg("<C-Space>", "i", false, true)), "<C-Space> is left to the multiplexer")
check(
    MiniPick.config.mappings.refine == "<C-y>" and MiniPick.config.mappings.choose_marked == "<C-q>",
    "picker keys clear of the multiplexer"
)

scratch({ "marked", "flagged" }, "text")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed("ma")
vim.api.nvim_win_set_cursor(0, { 2, 0 })
feed("mb")
vim.diagnostic.set(vim.api.nvim_create_namespace("signs-test"), 0, {
    { lnum = 1, col = 0, message = "hint", severity = vim.diagnostic.severity.HINT },
})
vim.wait(200)
local function shown_sign(row)
    local best
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, { row, 0 }, { row, -1 }, { details = true })) do
        local details = mark[4]
        if details.sign_text and (not best or details.priority > best.priority) then
            best = details
        end
    end
    return best and vim.trim(best.sign_text)
end
check(shown_sign(0) == "a", "a mark shows its letter: " .. tostring(shown_sign(0)))
check(shown_sign(1) == "●", "a diagnostic outranks a mark: " .. tostring(shown_sign(1)))
if vim.g.colors_name then
    vim.cmd.colorscheme(vim.g.colors_name)
end
local cyan = (vim.g.terminal_color_6 or "#5AD4E6"):lower()
for _, group in ipairs({ "GutterMarksLocal", "GutterMarksGlobal" }) do
    local fg = vim.api.nvim_get_hl(0, { name = group }).fg
    local shown = fg and string.format("#%06x", fg)
    check(shown == cyan, group .. " is cyan after a colorscheme load: " .. tostring(shown) .. " vs " .. cyan)
end

-- gq: code formats, prose and comments wrap ----------------------------------
local long = string.rep("word ", 30)
local dir = temporary .. "/format"
write(dir .. "/a.lua", "-- " .. long .. "\nlocal x={a=1}")
write(dir .. "/notes.txt", long)
write(dir .. "/readme.md", long)
for _, case in ipairs({
    { "a.lua", 1, "comment" },
    { "notes.txt", 1, "text" },
    { "readme.md", 1, "markdown" },
}) do
    vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. case[1]))
    vim.bo.textwidth = 40
    local before = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { case[2], 0 })
    feed("gqq")
    check(vim.api.nvim_buf_line_count(0) > before, case[3] .. ": gq wraps")
    for _, line in ipairs(lines()) do
        check(#line <= 40 or not line:match("word"), case[3] .. ": wrapped at textwidth")
    end
    vim.bo.modified = false
end
vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.lua"))
vim.cmd("edit!")
vim.api.nvim_win_set_cursor(0, { 2, 0 })
feed("gqq")
check(lines()[2] == "local x = { a = 1 }", "code: gq formats with stylua: " .. tostring(lines()[2]))
vim.bo.modified = false
check(require("formatexpr").only_comments(1, 1), "a comment-only range")

-- Folds without a parser -------------------------------------------------------
write(dir .. "/indented.txt", "top\n  inner\n    deeper\n  inner\nend")
vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.lua"))
check(vim.wo.foldexpr == "v:lua.vim.treesitter.foldexpr()", "tree-sitter folds where a parser exists")
vim.cmd.edit(vim.fn.fnameescape(dir .. "/indented.txt"))
check(vim.wo.foldmethod == "indent" and vim.fn.foldlevel(3) == 2, "indent folds without a parser")

-- Scripts become executable on their first save -------------------------------
local script = dir .. "/run me.sh"
vim.cmd.edit(vim.fn.fnameescape(script))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "#!/usr/bin/env bash", "echo hi" })
vim.cmd("silent write")
check(vim.fn.executable(script) == 1, "a shebang file is executable after :write")
local plain = dir .. "/data.sh"
vim.cmd.edit(vim.fn.fnameescape(plain))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "echo sourced" })
vim.cmd("silent write")
check(vim.fn.executable(plain) == 0, "a file without a shebang stays as it is")

-- Spell: generated word lists build themselves ---------------------------------
check(vim.g.loaded_spellfile_plugin == true, "Neovim's spellfile download handler is replaced")
vim.cmd.edit(vim.fn.fnameescape(dir .. "/readme.md"))
check(vim.fn.spellbadword("Neovim")[1] == "", "programming word list in use")
check(vim.fn.spellbadword("autogroup")[1] == "", "custom word list in use (spell/custom.words)")

-- hardtime leaves browsing buffers alone ---------------------------------------
-- hardtime.setup() applies its config on a 500 ms timer.
vim.wait(3000, function()
    return require("hardtime.config").config.disabled_filetypes.git
end, 50)
local hardtime = require("hardtime.config").config.disabled_filetypes
for _, ft in ipairs({ "git", "fugitiveblame", "dap-float", "dap-repl", "fugitive", "qf", "oil" }) do
    check(hardtime[ft], "hardtime disabled in " .. ft)
end
scratch(vim.split(string.rep("abc1234 2026-10-06 │ commit\n", 20), "\n"), "git")
vim.api.nvim_win_set_cursor(0, { 1, 0 })
for _ = 1, 8 do
    vim.api.nvim_feedkeys("j", "xt", false)
end
check(vim.api.nvim_win_get_cursor(0)[1] == 9, "j moves freely in fugitive's git buffers")

-- Plugins nothing added are pruned, so the versioned lockfile follows the config.
check(#vim.api.nvim_get_autocmds({ group = "hvpaiva-pack-prune", event = "VimEnter" }) == 1, "unused plugins pruned")
for _, plugin in ipairs(vim.pack.get()) do
    check(plugin.active, plugin.spec.name .. " is added by the config")
end

-- Filetypes --------------------------------------------------------------------
for name, ft in pairs({
    ["compose.yaml"] = "yaml.docker-compose",
    ["compose.override.yml"] = "yaml.docker-compose",
    ["docker-compose.prod.yml"] = "yaml.docker-compose",
    ["composer.yaml"] = "yaml",
    ["docker-bake.hcl"] = "hcl.docker-bake",
    ["docker-bake.override.hcl"] = "hcl.docker-bake",
    ["main.tf"] = "terraform",
    ["prod.tfvars"] = "terraform-vars",
}) do
    check(vim.filetype.match({ filename = dir .. "/" .. name }) == ft, name .. " is " .. ft)
end
check(vim.treesitter.language.get_lang("yaml.docker-compose") == "yaml", "compose files parse as YAML")
check(vim.treesitter.language.get_lang("hcl.docker-bake") == "hcl", "bake files parse as HCL")

-- Language servers -------------------------------------------------------------
for _, name in ipairs(new_servers) do
    check(enabled[name], name .. " enabled")
end

-- Settings a server receives after its before_init ran.
local function started(name, root)
    local config = vim.deepcopy(vim.lsp.config[name])
    if config.before_init then
        config.root_dir = root
        config.before_init({}, config)
    end
    return config.settings
end

check(#vim.lsp.config.jsonls.settings.json.schemas == 0, "SchemaStore stays out of startup")
local json = started("jsonls").json
check(#json.schemas > 100 and json.validate.enable, "jsonls validates against SchemaStore")

local yaml = started("yamlls").yaml
check(yaml.schemaStore.enable == false, "yamlls' built-in store is off")
check(yaml.schemas["https://www.schemastore.org/github-workflow.json"] == nil, "workflows are left to gh_actions_ls")
check(yaml.schemas["https://www.schemastore.org/github-action.json"] ~= nil, "action.yml still validates")
check(yaml.schemas["https://www.schemastore.org/chart.json"] ~= nil, "yamlls keeps the other schemas")

local helm = started("helm_ls")["helm-ls"].yamlls.config
check(helm.kubernetesVersion == yaml.kubernetesVersion, "Helm templates validate like manifests")
check(helm.schemas.kubernetes == "templates/**", "helm_ls keeps its template schema")

check(vim.lsp.config.hls.settings.haskell.plugin.semanticTokens.globalOn, "HLS semantic tokens on")

local gopls = vim.lsp.config.gopls.settings.gopls
check(gopls.gofumpt and gopls.staticcheck and gopls.hints.parameterNames, "gopls formatting, analysis and hints")

local python = temporary .. "/py"
write(python .. "/pyproject.toml", "[project]\nname = 'x'")
vim.fn.mkdir(python .. "/.venv/bin", "p")
write(python .. "/.venv/bin/python", "#!/bin/sh")
vim.fn.setfperm(python .. "/.venv/bin/python", "rwxr-xr-x")
local basedpyright = vim.lsp.config.basedpyright
local settings = vim.deepcopy(basedpyright.settings)
basedpyright.before_init({}, { root_dir = python, settings = settings })
check(settings.python.pythonPath == python .. "/.venv/bin/python", "basedpyright resolves the project venv")
check(settings.basedpyright.disableOrganizeImports, "ruff organizes Python imports")
local overrides = settings.basedpyright.analysis.diagnosticSeverityOverrides
check(overrides.reportUnusedImport == "none" and overrides.reportUnusedVariable == "none", "unused names reported once")

local toml = started("taplo").evenBetterToml.schema
local cargo
for regex, url in pairs(toml.associations) do
    if regex == "(^|/)Cargo\\.toml$" then
        cargo = url
    end
end
check(toml.enabled and cargo and cargo:find("cargo", 1, true), "taplo validates Cargo.toml: " .. tostring(cargo))
local ruff = { server_capabilities = { hoverProvider = true } }
vim.lsp.config.ruff.on_attach(ruff, 0)
check(ruff.server_capabilities.hoverProvider == false, "hover comes from basedpyright")

local commands = vim.lsp.config.rust_analyzer.commands
for _, name in ipairs({ "rust-analyzer.runSingle", "rust-analyzer.debugSingle", "rust-analyzer.showReferences" }) do
    check(type(commands[name]) == "function", "rust-analyzer handles " .. name)
end
check(type(vim.lsp.config.terraformls.commands["client.showReferences"]) == "function", "terraform-ls references")
check(vim.lsp.config.bashls.settings.bashIde.includeAllWorkspaceSymbols, "bashls sees every indexed script")

-- Formatters ---------------------------------------------------------------------
local conform = require("conform")
local by_ft = {
    { "x.py", "python", { "ruff_organize_imports", "ruff_format" } },
    { "main.tf", "terraform", { "terraform_fmt" } },
    { "Cargo.toml", "toml", { "taplo" } },
    { "main.go", "go", { "goimports" } },
}
for _, case in ipairs(by_ft) do
    vim.cmd.edit(vim.fn.fnameescape(dir .. "/" .. case[1]))
    local names = vim.tbl_map(function(f)
        return f.name
    end, conform.list_formatters_to_run(0))
    check(vim.deep_equal(names, case[3]), case[2] .. " formatters: " .. vim.inspect(names))
end
local web = temporary .. "/web"
write(web .. "/src/app.ts", "export const a=1")
vim.cmd.edit(vim.fn.fnameescape(web .. "/src/app.ts"))
check(#conform.list_formatters_to_run(0) == 0, "no prettier without a project config")
write(web .. "/.prettierrc", "{}")
check(conform.list_formatters_to_run(0)[1].name == "prettier_project", "prettier with a project config")

-- Code lens commands -------------------------------------------------------------
local rust = require("rust_tools")
local runnable = {
    command = "rust-analyzer.runSingle",
    arguments = {
        {
            label = "test tests::adds",
            kind = "cargo",
            args = {
                overrideCargo = vim.NIL,
                workspaceRoot = "/w",
                cargoArgs = { "test", "--package", "lens", "--lib" },
                cwd = "/w",
                executableArgs = { "tests::adds", "--exact", "--nocapture" },
                environment = { RUSTC_TOOLCHAIN = "/toolchains/stable" },
            },
        },
    },
}
check(
    rust.command_line(runnable)
        == "RUSTC_TOOLCHAIN='/toolchains/stable' 'cargo' 'test' '--package' 'lens' '--lib' '--' 'tests::adds' '--exact' '--nocapture'",
    "rust run lens command: " .. rust.command_line(runnable)
)
check(
    vim.deep_equal(
        rust.build_argv(runnable),
        { "cargo", "test", "--no-run", "--package", "lens", "--lib", "--message-format=json" }
    ),
    "rust debug lens builds without running"
)
local artifacts = table.concat({
    vim.json.encode({ reason = "compiler-artifact", executable = vim.NIL }),
    vim.json.encode({ reason = "compiler-artifact", executable = "/w/target/debug/deps/lens-abc" }),
    vim.json.encode({ reason = "build-finished", success = true }),
}, "\n")
check(rust.executable(artifacts) == "/w/target/debug/deps/lens-abc", "rust debug lens finds the test binary")

local refs = dir .. "/refs.lua"
write(refs, "local a = 1\nprint(a)\nprint(a)")
vim.cmd.edit(vim.fn.fnameescape(refs))
local uri = vim.uri_from_fname(refs)
local function location(line)
    return { uri = uri, range = { start = { line = line, character = 6 }, ["end"] = { line = line, character = 7 } } }
end
vim.fn.setqflist({}, "r")
require("lenses").show_references({ arguments = { uri, { line = 0, character = 6 }, { location(1), location(2) } } }, {
    client_id = vim.lsp.get_clients({ name = "mini.snippets" })[1].id,
    bufnr = 0,
})
check(#vim.fn.getqflist() == 2, "references lens fills the quickfix")
local qf = vim.fn.getqflist({ winid = true }).winid
check(qf ~= 0 and vim.bo[vim.fn.winbufnr(qf)].modifiable, "quicker makes the quickfix editable")
vim.cmd("cclose")

vim.cmd("silent! %bwipeout!")
vim.fn.delete(temporary, "rf")
print(string.format("PASS %d editing checks", checks))
vim.cmd("qa!")
