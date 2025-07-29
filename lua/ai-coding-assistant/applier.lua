-- lua/ai-coding-assistant/applier.lua
local M = {}

function M.apply(target_bufnr, hunks)
  local highlighter = require("ai-coding-assistant.highlighter")

  for i = #hunks, 1, -1 do
    local hunk = hunks[i]
    local new_lines, delete_count, context_count = {}, 0, 0

    for _, change in ipairs(hunk.changes) do
      if change.type == '+' then table.insert(new_lines, change.content)
      elseif change.type == '-' then delete_count = delete_count + 1
      elseif change.type == ' ' then
        table.insert(new_lines, change.content)
        context_count = context_count + 1
      end
    end

    local start_line = hunk.original_start_line - 1
    local end_line = start_line + delete_count + context_count
    vim.api.nvim_buf_set_lines(target_bufnr, start_line, end_line, true, new_lines)
  end

  highlighter.clear(target_bufnr)
  vim.notify("AI changes applied.", vim.log.levels.INFO, { title = "AI Assistant" })
end

return M
