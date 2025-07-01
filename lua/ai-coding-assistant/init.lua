-- /lua/ai-coding-assistant/init.lua
local M = {}

function M.setup(opts)
  --> 1. Pass the user's options to the config module to be processed.
  local config = require("ai-coding-assistant.config")
  config.setup(opts)

  --> 2. Set up commands (this part is the same).
  local ui = require("ai-coding-assistant.ui")
  vim.api.nvim_create_user_command("AISelectModel", ui.model_selector, { desc = "Select AI model" })
  vim.api.nvim_create_user_command("AICommand", ui.command_prompt, { desc = "Run AI command", range = true })

  --> 3. Set up keymaps based on the user's config.
  local merged_opts = config.get() -- Get the final merged options
  if merged_opts.keymaps then
    vim.keymap.set("n", merged_opts.keymaps.select_model, "<cmd>AISelectModel<CR>", { desc = "Select AI Model" })
    vim.keymap.set("v", merged_opts.keymaps.run_command, ":AICommand<CR>", { desc = "Run AI Command" })
  end
end

return M
