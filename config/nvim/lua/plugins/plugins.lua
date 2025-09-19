local plugins = {
  {
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "go", "gomod", "gowork", "gosum" },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      }
    end,
  },
  {
    "ray-x/go.nvim",
    config = function()
      require("go").setup()
    end,
  },
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "zbirenbaum/copilot-cmp",
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
    opts = {
      sources = {
        { name = "nvim_lsp", group_index = 2 },
        { name = "copilot", group_index = 2 },
        { name = "luasnip", group_index = 2 },
        { name = "buffer", group_index = 2 },
        { name = "nvim_lua", group_index = 2 },
        { name = "path", group_index = 2 },
        { name = "bazel", group_index = 2 },
      },
    },
  },
  {
    "alexander-born/bazel.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
    },
    targets = { "go_test", "go_test_coverage", "go_run", "go_build", "go_binary" },
    mappings = {
      { "n", "<Leader>bt", "go_test" },
      { "n", "<Leader>btc", "go_test_coverage" },
      { "n", "<Leader>br", "go_run" },
      { "n", "<Leader>bb", "go_build" },
      { "n", "<Leader>bbi", "go_binary" },
    },
  },
}

return plugins
