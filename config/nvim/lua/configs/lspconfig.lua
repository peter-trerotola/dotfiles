-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

-- EXAMPLE
local servers = { "html", "bashls", "protols", "bzl" }
local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

-- Conditionally configure gopls based on CONFIG_MODE
local config_mode = os.getenv("CONFIG_MODE")
local gopls_settings = {}

-- Add Bazel-specific settings only when CONFIG_MODE is set (work environments)
if config_mode and config_mode ~= "default" then
  gopls_settings = {
    gopls = {
      env = {
        GOPACKAGESDRIVER = "/workspaces/central/tools/bazel/go/gopackagesdriver.sh",
      },
      directoryFilters = {
        "-bazel",
        "-bazel-out",
        "-bazel-bin",
        "-bazel-testlogs",
        "-bazel-logs",
      },
    },
  }
end

lspconfig["gopls"].setup {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = gopls_settings,
}
