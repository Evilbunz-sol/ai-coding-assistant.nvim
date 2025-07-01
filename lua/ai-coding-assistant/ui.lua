-- /lua/ai-coding-assistant/ui.lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local conf = require("telescope.config").values

-- IMPORTANT: Note the new require paths
local core = require("ai-coding-assistant.core")
local utils = require("ai-coding-assistant.utils")

local M = {}

function M.model_selector()
  local models = {
    { provider = "openai", model = "gpt-4o", display = "🤖 OpenAI: GPT-4o" },
    { provider = "openai", model = "gpt-3.5-turbo", display = "🤖 OpenAI: GPT-3.5 Turbo" },
    { provider = "anthropic", model = "claude-3-opus-20240229", display = "🌶️ Anthropic: Claude 3 Opus" },
    { provider = "anthropic", model = "claude-3-sonnet-20240229", display = "🌶️ Anthropic: Claude 3 Sonnet" },
    { provider = "anthropic", model = "claude-3-haiku-20240307", display = "🌶️ Anthropic: Claude 3 Haiku" },
    { provider = "gemini", model = "gemini-1.5-pro-latest", display = "✨ Gemini: 1.5 Pro" },
    { provider = "gemini", model = "gemini-1.5-flash-latest", display = "⚡ Gemini: 1.5 Flash" },
  }

  pickers.new({
    prompt_title = "Select AI Model",
    finder = finders.new_table({
      results = models,
      entry_maker = function(entry)
        return { value = entry, display = entry.display, ordinal = entry.display }
      end,
    }),
    sorter = conf.generic_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = require("telescope.actions.state").get_selected_entry()
        actions.close(prompt_bufnr)
        core.config.current = { provider = selection.value.provider, model = selection.value.model }
        vim.notify("AI model set to: " .. selection.value.display, vim.log.levels.INFO, { title = "AI Assistant" })
      end)
      return true
    end,
  }):find()
end

function M.command_prompt()
  vim.ui.input({
    prompt = "Enter AI Command...",
  }, function(prompt)
    if not prompt or prompt == "" then
      return
    end

    vim.cmd('redraw')
    local start_line, end_line, selection = utils.get_visual_selection()

    if selection == "" then
      vim.notify("No visual selection found.", vim.log.levels.WARN, { title = "AI Assistant" })
      return
    end

    local full_prompt = "Instruction: " .. prompt .. "\n\n" .. "Code:\n```\n" .. selection .. "\n```"
    vim.notify("Sending request to AI...", vim.log.levels.INFO, { title = "AI Assistant" })

    core.request(full_prompt, function(ai_response)
      utils.replace_lines(start_line, end_line, ai_response)
      vim.notify("AI code replacement complete.", vim.log.levels.INFO, { title = "AI Assistant" })
    end)
  end)
end

return M
