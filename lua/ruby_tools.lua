local M = {}

function M.bundle_root(filename)
    return vim.fs.root(filename, { "Gemfile", "gems.rb" })
end

local function resolve(filename, executable, gem)
    local root = M.bundle_root(filename)
    if root then
        local binstub = root .. "/bin/" .. executable
        if vim.fn.executable(binstub) == 1 then
            return binstub, {}, root
        end

        local lockfile = root .. (vim.fn.filereadable(root .. "/Gemfile") == 1 and "/Gemfile.lock" or "/gems.locked")
        if vim.fn.filereadable(lockfile) == 1 then
            for _, line in ipairs(vim.fn.readfile(lockfile)) do
                if line:match("^    " .. vim.pesc(gem) .. " %(") then
                    return "bundle", { "exec", executable }, root
                end
            end
        end
    end
    return executable, {}, root or vim.fs.dirname(filename)
end

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

return M
