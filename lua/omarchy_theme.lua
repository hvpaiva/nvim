-- ============================================================================
-- Follow the Omarchy desktop theme
-- ============================================================================
-- omarchy-theme-set renders ~/.local/state/omarchy/current/theme/neovim.lua for
-- each theme. That file is a LazyVim plugin spec: colorscheme plugins (with
-- optional `dependencies` and `opts`), none for a scheme built into Neovim, plus
-- a LazyVim entry whose `opts.colorscheme` names the scheme to load. This module reads it, installs
-- the colorscheme plugins with vim.pack and applies the scheme. It returns true
-- when a theme was applied, false when there is nothing to follow, so theme.lua
-- can fall back to the personal monokai-pro setup.
--
-- Themes that ship no neovim.lua (or whose plugin fails) leave the editor on
-- the fallback. Re-apply with :OmarchyTheme after switching themes.

local M = {}

local theme_file = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")

-- LazyVim-only entries that are not colorschemes.
local skip = {
    ["LazyVim/LazyVim"] = true,
    ["nvim-lualine/lualine.nvim"] = true,
    ["folke/snacks.nvim"] = true,
    ["nvim-tree/nvim-web-devicons"] = true,
    ["rktjmp/lush.nvim"] = false, -- a real dependency of some schemes
}

local function repo_url(repo)
    if repo:match("^https?://") then
        return repo
    end
    return "https://github.com/" .. repo
end

local function collect(spec, plugins)
    if type(spec) ~= "table" then
        return
    end
    local repo = spec[1]
    if type(repo) == "string" and not skip[repo] then
        if type(spec.dependencies) == "table" then
            for _, dep in ipairs(spec.dependencies) do
                if type(dep) == "string" then
                    plugins[#plugins + 1] = { repo = dep }
                else
                    collect(dep, plugins)
                end
            end
        elseif type(spec.dependencies) == "string" then
            plugins[#plugins + 1] = { repo = spec.dependencies }
        end
        plugins[#plugins + 1] = { repo = repo, opts = spec.opts, config = spec.config }
    end
end

function M.load()
    local ok, specs = pcall(dofile, theme_file)
    if not ok or type(specs) ~= "table" then
        return false
    end

    local colorscheme
    local plugins = {}
    for _, spec in ipairs(specs) do
        if type(spec) == "table" and spec[1] == "LazyVim/LazyVim" then
            colorscheme = type(spec.opts) == "table" and spec.opts.colorscheme or nil
        else
            collect(spec, plugins)
        end
    end
    if not colorscheme then
        return false
    end

    -- A scheme that ships with Neovim (vim, default...) has no plugin to install.
    if #plugins > 0 then
        local urls = {}
        for _, p in ipairs(plugins) do
            urls[#urls + 1] = repo_url(p.repo)
        end
        local added = pcall(vim.pack.add, urls)
        if not added then
            return false
        end
    end

    -- Colorscheme plugins usually expose `setup(opts)` under the plugin's module
    -- name (catppuccin, tokyonight, rose-pine, kanagawa...). Best effort only.
    for _, p in ipairs(plugins) do
        local mod = p.repo:match("([^/]+)$"):gsub("%.nvim$", ""):gsub("%-nvim$", "")
        if type(p.opts) == "table" then
            local mok, m = pcall(require, mod)
            if mok and type(m) == "table" and type(m.setup) == "function" then
                pcall(m.setup, p.opts)
            end
        end
        if type(p.config) == "function" then
            pcall(p.config)
        end
    end

    local applied = pcall(vim.cmd.colorscheme, colorscheme)
    if applied then
        vim.g.omarchy_colorscheme = colorscheme
    end
    return applied
end

vim.api.nvim_create_user_command("OmarchyTheme", function()
    if not M.load() then
        vim.notify("No Omarchy neovim theme to apply (or it failed); keeping the current scheme", vim.log.levels.WARN)
    end
end, { desc = "Re-apply the current Omarchy desktop theme" })

return M
