local M = {}

local ns = vim.api.nvim_create_namespace("ai_assistant_diff")

local function setup_highlights()
  vim.api.nvim_set_hl(0, "AIDiffDelete", { bg = "#4C383F" })
  vim.api.nvim_set_hl(0, "AIDiffAdd", { bg = "#2E4842" })
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

function M.apply(parsed_diff)
  setup_highlights()

  local target_bufnr = vim.fn.bufnr(parsed_diff.file_path, true)
  if target_bufnr == -1 then
    vim.notify("Could not find open buffer for: " .. parsed_diff.file_path, vim.log.levels.WARN)
    return
  end

  M.clear(target_bufnr)

  -- Fix: Handle if buffer not visible in any window
  local target_win_id = vim.fn.bufwinid(target_bufnr)
  local win_width
  if target_win_id == -1 then
    win_width = vim.o.columns  -- Fallback to editor width
  else
    win_width = vim.api.nvim_win_get_width(target_win_id)
  end

  local buf_line_count = vim.api.nvim_buf_line_count(target_bufnr)

  local current_line_in_buffer = 0
  for _, hunk in ipairs(parsed_diff.hunks) do
    current_line_in_buffer = hunk.original_start_line - 1
    -- Fix: Clamp to valid range
    current_line_in_buffer = math.max(0, math.min(current_line_in_buffer, buf_line_count - 1))

    for _, change in ipairs(hunk.changes) do
      if change.type == "delete" then
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          line_hl_group = "AIDiffDelete",
        })
        current_line_in_buffer = current_line_in_buffer + 1
        -- Clamp again if needed
        current_line_in_buffer = math.min(current_line_in_buffer, buf_line_count - 1)
      elseif change.type == "add" then
        local content = change.content
        local padding = win_width - #content
        local padded_content = content .. string.rep(" ", padding > 0 and padding or 0)

        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          virt_lines = { { { padded_content, "AIDiffAdd" } } },
          virt_lines_above = false,
        })
        -- Don't increment for adds (virtual), but if next change is add, it stacks on same line—consider incrementing if multiple adds
      elseif change.type == "context" then
        current_line_in_buffer = current_line_in_buffer + 1
        current_line_in_buffer = math.min(current_line_in_buffer, buf_line_count - 1)
      end
    end
  end
end

return M
