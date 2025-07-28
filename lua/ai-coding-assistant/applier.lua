-- lua/ai-coding-assistant/applier.lua

-- lua/ai-coding-assistant/applier.lua
local M = {}

function M.apply(parsed_diff)
  local target_bufnr = vim.fn.bufnr(parsed_diff.file_path, true)
  if target_bufnr == -1 then
    vim.notify("Target buffer for diff not open: " .. parsed_diff.file_path, vim.log.levels.ERROR)
    return
  end

  -- Iterate through hunks in REVERSE to avoid line shifts
  for i = #parsed_diff.hunks, 1, -1 do
    local hunk = parsed_diff.hunks[i]
    local new_lines = {}
    local delete_count = 0
    local context_count = 0

    for _, change in ipairs(hunk.changes) do
      if change.type == '+' then
        table.insert(new_lines, change.content)
      elseif change.type == '-' then
        delete_count = delete_count + 1
      elseif change.type == ' ' then
        table.insert(new_lines, change.content)
        context_count = context_count + 1
      end
    end

    local start_line = hunk.original_start_line - 1
    local end_line = start_line + delete_count + context_count

    vim.api.nvim_buf_set_lines(target_bufnr, start_line, end_line, true, new_lines)
  end

  require("ai-coding-assistant.highlighter").clear(target_bufnr)
  vim.notify("AI changes applied successfully to " .. parsed_diff.file_path, vim.log.levels.INFO, { title = "AI Assistant" })
end

return M
