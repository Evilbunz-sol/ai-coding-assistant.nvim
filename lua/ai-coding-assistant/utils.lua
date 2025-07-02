local M = {}

-- Returns the start and end line numbers and the content as a string.
function M.get_visual_selection()
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return start_line, end_line, table.concat(lines, "\n")
end

-- Replaces a range of lines in the current buffer with new content.
function M.replace_lines(start_line, end_line, new_content)
  local content_lines = vim.split(new_content, "\n")
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, content_lines)
end

return M
