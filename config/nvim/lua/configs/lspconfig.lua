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

lspconfig["gopls"].setup {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
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
  },
}
