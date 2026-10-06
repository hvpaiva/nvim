-- Ruby project tooling shared by formatting (conform), linting (ruby-lsp or
-- nvim-lint) and debugging.
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

--- conform formatter spec for a Ruby formatter resolved per buffer.
function M.formatter(executable, gem)
    return {
        command = function(_, ctx)
            local command = resolve(ctx.filename, executable, gem)
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

--- nvim-lint linter for `name` ("standardrb" or "rubocop"), resolved for the
--- current buffer the same way the formatter is.
function M.linter(name)
    local gem = name == "standardrb" and "standard" or name
    return function()
        local base = require("lint.linters." .. name)
        local command, prefix = resolve(vim.api.nvim_buf_get_name(0), name, gem)
        return vim.tbl_extend("force", base, {
            cmd = command,
            args = vim.list_extend(vim.deepcopy(prefix), base.args),
            -- nvim-lint's standardrb parser leaves `source` empty; label both
            -- like ruby-lsp labels its RuboCop diagnostics.
            parser = function(...)
                local diagnostics = base.parser(...)
                for _, diagnostic in ipairs(diagnostics) do
                    diagnostic.source = diagnostic.source or name
                end
                return diagnostics
            end,
        })
    end
end

return M
