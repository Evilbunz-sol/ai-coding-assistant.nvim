-- lua/ai-coding-assistant/highlighter.lua
local M = {}

local ns = vim.api.nvim_create_namespace("ai_assistant_diff")

local function setup_highlights()
  vim.api.nvim_set_hl(0, "AIDiffDelete", { bg = "#4C383F" })
  vim.api.nvim_set_hl(0, "AIDiffAdd", { bg = "#2E4842" })
end

function M.clear(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

function M.apply(parsed_diff)
  setup_highlights()

  local target_bufnr = vim.fn.bufnr(parsed_diff.file_path, true)
  if target_bufnr == -1 then
    vim.notify("Could not find open buffer for: " .. parsed_diff.file_path, vim.log.levels.WARN)
    return
  end

  M.clear(target_bufnr)

  local target_win_id = vim.fn.bufwinid(target_bufnr)
  local win_width = target_win_id ~= -1 and vim.api.nvim_win_get_width(target_win_id) or 80
  local line_count = vim.api.nvim_buf_line_count(target_bufnr)

  local line_cursor = 0
  for _, hunk in ipairs(parsed_diff.hunks) do
    line_cursor = hunk.original_start_line

    -- ⭐️ MORE PRECISE SAFETY CHECK
    -- The start line of a diff is 1-indexed. The number of lines is also 1-indexed.
    -- A hunk cannot start *after* the last line of the file.
    if line_cursor > line_count + 1 then
      vim.notify("AI returned a diff with invalid line numbers for " .. parsed_diff.file_path, vim.log.levels.WARN)
      goto continue
    end

    -- The line cursor is now 0-indexed for API calls
    line_cursor = line_cursor - 1

    for _, change in ipairs(hunk.changes) do
      if change.type == "-" then
        if line_cursor < line_count then
          vim.api.nvim_buf_set_extmark(target_bufnr, ns, line_cursor, 0, { line_hl_group = "AIDiffDelete" })
        end
        line_cursor = line_cursor + 1
      elseif change.type == "+" then
        local display_line = math.max(0, line_cursor - 1)
        local padded_content = change.content .. string.rep(" ", math.max(0, win_width - #change.content))
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, display_line, 0, {
          virt_lines = { { { padded_content, "AIDiffAdd" } } },
          virt_lines_above = false,
        })
      elseif change.type == " " then
        line_cursor = line_cursor + 1
      end
    end
    ::continue::
  end
end

return M
