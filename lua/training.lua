-- ============================================================================
-- Training tools
-- ============================================================================
-- Motion drills and guardrails live here so the normal editing path stays easy
-- to reason about. Flip this to `false` when the active coaching phase is over;
-- the explicit games and commands remain available under `<Leader>t`.
local training_enabled_by_default = true

require("hardtime").setup({
    enabled = training_enabled_by_default,
    max_count = 3,
    disable_mouse = true,
    hint = true,
    notification = true,
    allow_different_key = true,
})

require("precognition").setup({
    startVisible = false,
    showBlankVirtLine = true,
})

local opt_pack = vim.fn.stdpath("data") .. "/site/pack/core/opt"

local function add_runtime(plugin)
    local path = opt_pack .. "/" .. plugin
    if vim.fn.isdirectory(path) == 0 then
        vim.notify("Training plugin not installed: " .. plugin, vim.log.levels.ERROR)
        return false
    end

    if not vim.tbl_contains(vim.api.nvim_list_runtime_paths(), path) then
        vim.opt.runtimepath:append(path)
    end

    return true
end

local function patch_nvim_training()
    if not add_runtime("nvim-training") then
        return false
    end

    local user_config = require("nvim-training.user_config")

    local function safe_configure(args)
        args = args or {}

        for key, value in pairs(args) do
            if type(value) == "table" and key:find("_args") and type(user_config[key]) == "table" then
                for nested_key, nested_value in pairs(value) do
                    if user_config[key][nested_key] == nil then
                        vim.notify_once(
                            "nvim-training config key not supported: " .. key .. ":" .. nested_key,
                            vim.log.levels.WARN
                        )
                    end
                    user_config[key][nested_key] = nested_value
                end
            else
                if user_config[key] == nil then
                    vim.notify_once("nvim-training config key not supported: " .. key, vim.log.levels.WARN)
                end
                user_config[key] = value
            end
        end

        vim.fn.mkdir(user_config.logging_args.log_directory_path, "p")
        vim.fn.mkdir(user_config.event_storage_directory_path, "p")
    end

    for _, module_name in ipairs({ "nvim-training", "nvim-training.init" }) do
        local ok, module = pcall(require, module_name)
        if ok then
            module.configure = safe_configure
            module.setup = safe_configure
        end
    end

    safe_configure({})
    return true
end

local function without_empty_custom_task_noise(fn)
    local original_print = print
    print = function(...)
        local parts = vim.tbl_map(tostring, { ... })
        local msg = table.concat(parts, " ")
        if msg:match("The task collection 'Custom%-Tasks' does not contain any tasks!") then
            return
        end
        original_print(...)
    end

    local ok, result = pcall(fn)
    print = original_print

    if not ok then
        error(result)
    end

    return result
end

local function training_commands()
    if not add_runtime("nvim-training") then
        return nil
    end

    return without_empty_custom_task_noise(function()
        return require("nvim-training.commands")
    end)
end

local function create_training_command()
    vim.api.nvim_create_user_command("Training", function(opts)
        if not patch_nvim_training() then
            return
        end

        local subcommands = training_commands()
        if not subcommands then
            return
        end

        local subcommand_key = opts.fargs[1] or "Start"
        subcommand_key = subcommand_key == "Analyze" and "Analyse" or subcommand_key

        local subcommand = subcommands[subcommand_key]
        if not subcommand then
            vim.notify("Training subcommand not supported: " .. subcommand_key, vim.log.levels.ERROR)
            return
        end

        subcommand.execute(vim.list_slice(opts.fargs, 2, #opts.fargs))
    end, {
        nargs = "*",
        desc = "Train Vim muscle memory",
        force = true,
        complete = function(arg_lead, cmdline, _)
            local subcommands = training_commands()
            if not subcommands then
                return {}
            end

            local subcommand_key, subcommand_arg_lead = cmdline:match("^['<,'>]*Training[!]*%s(%S+)%s(.*)$")
            if
                subcommand_key
                and subcommand_arg_lead
                and subcommands[subcommand_key]
                and subcommands[subcommand_key].complete
            then
                return subcommands[subcommand_key].complete(subcommand_arg_lead)
            end

            if cmdline:match("^['<,'>]*Training[!]*%s+%w*$") then
                return vim.iter(vim.tbl_keys(subcommands))
                    :filter(function(key)
                        return key:find(arg_lead) ~= nil
                    end)
                    :totable()
            end
        end,
    })
end

create_training_command()
vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("hvpaiva-training-command", { clear = true }),
    desc = "Keep local :Training wrapper registered after startup",
    callback = create_training_command,
})

local function run_vim_be_better()
    if add_runtime("vim-be-better") then
        for name in pairs(package.loaded) do
            if name:match("^vim%-be%-good") then
                package.loaded[name] = nil
            end
        end

        vim.api.nvim_create_autocmd("VimResized", {
            group = vim.api.nvim_create_augroup("hvpaiva-vim-be-better", { clear = true }),
            callback = function()
                require("vim-be-better").onVimResize()
            end,
        })

        require("vim-be-better").menu()
    end
end

local function run_vim_teacher()
    if add_runtime("VimTeacher") then
        vim.schedule(function()
            require("vimteacher").start("")
        end)
    end
end

local function toggle_precognition()
    local visible = require("precognition").toggle()
    vim.notify("precognition " .. (visible and "on" or "off"))
end

local function toggle_hardtime()
    require("hardtime").toggle()
    local enabled = require("hardtime").is_plugin_enabled
    vim.notify("hardtime " .. (enabled and "on" or "off"))
end

local function nmap_leader(suffix, rhs, desc)
    vim.keymap.set("n", "<leader>" .. suffix, rhs, { desc = desc })
end

nmap_leader("tt", "<cmd>Training Start<CR>", "Training start")
nmap_leader("tS", "<cmd>Training Stop<CR>", "Training stop")
nmap_leader("ta", "<cmd>Training Analyse<CR>", "Training analyze")
nmap_leader("tb", run_vim_be_better, "VimBeBetter")
nmap_leader("tT", run_vim_teacher, "VimTeacher")
nmap_leader("th", function()
    require("precognition").peek()
end, "Precognition peek")
nmap_leader("tH", toggle_precognition, "Precognition toggle")
nmap_leader("td", toggle_hardtime, "Hardtime toggle")
nmap_leader("tr", function()
    require("hardtime.report").report()
end, "Hardtime report")
