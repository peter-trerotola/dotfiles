require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Map "H" in normal mode to show LSP diagnostics
map("n", "<leader>r", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "<leader>i", vim.lsp.buf.implementation, { desc = "Go to implementation" })
map("n", "H", function()
  vim.diagnostic.open_float()
end, { desc = "Show LSP diagnostics" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
