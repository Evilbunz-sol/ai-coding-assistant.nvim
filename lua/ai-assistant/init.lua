-- /lua/ai-coding-assistant/init.lua
local ui = require("ai-coding-assistant.ui")

local M = {}

-- This is the public setup function for our plugin
function M.setup(opts)
  -- For now, opts is not used, but it's here for future configuration.

  -- Create user commands that other people (and you) can use
  vim.api.nvim_create_user_command(
    "AISelectModel",
    ui.model_selector,
    { desc = "Select the AI model for the coding assistant" }
  )

  vim.api.nvim_create_user_command(
    "AICommand",
    ui.command_prompt,
    { desc = "Run an AI command on the current visual selection", range = true }
  )
end

return M
