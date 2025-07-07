local M = {}

local ns = vim.api.nvim_create_namespace("ai_assistant_diff")

-- We'll make the highlight definitions more explicit
local function setup_highlights()
  -- For deleted lines, we want a red background for the whole line
  vim.api.nvim_set_hl(0, "AIDiffDelete", { bg = "#4C383F" })

  -- For added virtual text, we want a green background
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

  -- Find the window associated with the buffer to get its width
  local target_win_id = vim.fn.bufwinid(target_bufnr)
  local win_width = vim.api.nvim_win_get_width(target_win_id)

  local current_line_in_buffer = 0
  for _, hunk in ipairs(parsed_diff.hunks) do
    current_line_in_buffer = hunk.original_start_line - 1

    for _, change in ipairs(hunk.changes) do
      if change.type == "delete" then
        --> CHANGED: Use 'line_hl_group' to highlight the entire line.
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          line_hl_group = "AIDiffDelete",
        })
        current_line_in_buffer = current_line_in_buffer + 1
      elseif change.type == "add" then
        --> CHANGED: Pad the virtual text with spaces to simulate a full-line highlight.
        local content = change.content
        local padding = win_width - #content
        local padded_content = content .. string.rep(" ", padding > 0 and padding or 0)

        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          virt_lines = { { { padded_content, "AIDiffAdd" } } },
          virt_lines_above = false,
        })
      elseif change.type == "context" then
        current_line_in_buffer = current_line_in_buffer + 1
      end
    end
  end
end

return M
