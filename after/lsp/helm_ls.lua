-- helm_ls runs its own yaml-language-server for templates. Keep its defaults
-- (`config` replaces them as a whole) and validate templates against the same
-- Kubernetes version as standalone manifests (after/lsp/yamlls.lua), read when
-- the server starts so the editor does not resolve yamlls' config at startup.

return {
    settings = {
        ["helm-ls"] = {
            yamlls = {
                config = {
                    schemas = { kubernetes = "templates/**" },
                    completion = true,
                    hover = true,
                },
            },
        },
    },
    before_init = function(_, config)
        config.settings["helm-ls"].yamlls.config.kubernetesVersion =
            vim.lsp.config.yamlls.settings.yaml.kubernetesVersion
    end,
}
