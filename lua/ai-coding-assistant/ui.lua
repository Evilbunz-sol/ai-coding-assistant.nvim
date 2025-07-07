-- /lua/ai-coding-assistant/ui.lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local conf = require("telescope.config").values

local core = require("ai-coding-assistant.core")

local M = {}

function M.model_selector()
  --> Get the config at runtime.
  local config = require("ai-coding-assistant.config").get()

  pickers.new({
    prompt_title = "Select AI Model",
    finder = finders.new_table({
      --> The list of models is now read from the config, not hardcoded.
      results = config.models,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display }
      end,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = require("telescope.actions.state").get_selected_entry()
        actions.close(prompt_bufnr)
        core.state.current = { provider = selection.value.provider, model = selection.value.model }
        vim.notify("AI model set to: " .. selection.value.display, vim.log.levels.INFO, { title = "AI Assistant" })
      end)
      return true
    end,
  }):find()
end

return M
