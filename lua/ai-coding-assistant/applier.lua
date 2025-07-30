-- lua/ai-coding-assistant/applier.lua
local M = {}

function M.apply(target_bufnr, hunks)
  local highlighter = require("ai-coding-assistant.highlighter")

  -- Iterate backwards to not invalidate line numbers
  for i = #hunks, 1, -1 do
    local hunk = hunks[i]
    local lines_to_add = {}
    local delete_start_line = -1
    local delete_count = 0

    -- First, figure out what to delete and what to add
    for _, change in ipairs(hunk.changes) do
      if change.type == "+" then
        table.insert(lines_to_add, change.content)
      elseif change.type == "-" then
        if delete_start_line == -1 then
          delete_start_line = hunk.original_start_line + delete_count
        end
        delete_count = delete_count + 1
      elseif change.type == " " then
        -- If we were in a block of deletions, stop counting
        if delete_start_line ~= -1 and delete_count > 0 then
          vim.api.nvim_buf_set_lines(target_bufnr, delete_start_line - 1, delete_start_line - 1 + delete_count, true, {})
          delete_start_line = -1
          delete_count = 0
        end
      end
    end

    -- Handle any remaining deletions at the end of the hunk
    if delete_start_line ~= -1 and delete_count > 0 then
      vim.api.nvim_buf_set_lines(target_bufnr, delete_start_line - 1, delete_start_line - 1 + delete_count, true, {})
    end

    -- Now, add the new lines
    if #lines_to_add > 0 then
      local insert_line = hunk.original_start_line - 1
      vim.api.nvim_buf_set_lines(target_bufnr, insert_line, insert_line, true, lines_to_add)
    end
  end

  highlighter.clear(target_bufnr)
  -- Clear all signs from the buffer
  vim.fn.sign_unplace("AIDiff", { buffer = target_bufnr })
  vim.notify("AI changes applied.", vim.log.levels.INFO, { title = "AI Assistant" })
end

return M
