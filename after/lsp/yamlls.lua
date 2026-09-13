-- yaml-language-server: validation and completion from JSON schemas.
-- Source: https://github.com/redhat-developer/yaml-language-server
--
-- SchemaStore (on by default) covers files it knows by name: GitHub
-- workflows, Chart.yaml, kustomization.yaml, and so on. Kubernetes manifests
-- have no fixed name, so each buffer that looks like one (top-level
-- `apiVersion:` and `kind:`) is added to the server's `kubernetes` schema.
-- From there the server picks the schema per document: built-in kinds from
-- the Kubernetes schema of `kubernetesVersion`, custom resources (Argo CD,
-- Crossplane, Kyverno, CloudNativePG...) from the CRDs catalog at
-- https://github.com/datreeio/CRDs-catalog.
-- Helm templates are not handled here: helm_ls runs its own yamlls for them.

local function is_manifest(bufnr)
    local api_version, kind = false, false
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        api_version = api_version or line:match("^apiVersion:%s*%S") ~= nil
        kind = kind or line:match("^kind:%s*%S") ~= nil
        if api_version and kind then
            return true
        end
    end
    return false
end

-- Add the buffer's file to the `kubernetes` globs and push the new settings.
-- Globs are matched against the whole path, so the absolute path works as one.
local function mark_manifest(client, bufnr)
    local path = vim.api.nvim_buf_get_name(bufnr)
    local schemas = client.settings.yaml.schemas
    schemas.kubernetes = schemas.kubernetes or {}
    if path == "" or vim.list_contains(schemas.kubernetes, path) or not is_manifest(bufnr) then
        return
    end
    table.insert(schemas.kubernetes, path)
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
end

return {
    settings = {
        yaml = {
            -- Match the kind node image in the lab (cluster/kind.yaml).
            kubernetesVersion = "v1.35.0",
            schemas = {},
        },
    },
    on_attach = function(client, bufnr)
        mark_manifest(client, bufnr)
        -- A new file only gets its `apiVersion`/`kind` after it is opened.
        vim.api.nvim_create_autocmd("BufWritePost", {
            buffer = bufnr,
            group = vim.api.nvim_create_augroup("hvpaiva-yamlls-k8s-" .. bufnr, { clear = true }),
            desc = "Detect Kubernetes manifests for yamlls",
            callback = function()
                mark_manifest(client, bufnr)
            end,
        })
    end,
}
