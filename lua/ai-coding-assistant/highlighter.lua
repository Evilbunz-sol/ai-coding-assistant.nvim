-- lua/ai-coding-assistant/highlighter.lua
local M = {}
local ns = vim.api.nvim_create_namespace("ai_assistant_diff")

function M.clear(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

function M.apply(target_bufnr, hunks)
  vim.api.nvim_set_hl(0, "AIDiffDelete", { bg = "#4C383F" })
  vim.api.nvim_set_hl(0, "AIDiffAdd", { bg = "#2E4842" })

  M.clear(target_bufnr)

  local win_id = vim.fn.bufwinid(target_bufnr)
  local win_width = win_id ~= -1 and vim.api.nvim_win_get_width(win_id) or 80
  local line_count = vim.api.nvim_buf_line_count(target_bufnr)

  for _, hunk in ipairs(hunks) do
    local line_cursor = hunk.original_start_line
    if line_cursor > line_count + 1 then goto continue end
    line_cursor = line_cursor - 1

    for _, change in ipairs(hunk.changes) do
      if change.type == "-" then
        if line_cursor < line_count then
          vim.api.nvim_buf_set_extmark(target_bufnr, ns, line_cursor, 0, { line_hl_group = "AIDiffDelete" })
        end
        line_cursor = line_cursor + 1
      elseif change.type == "+" then
        local padded = change.content .. string.rep(" ", math.max(0, win_width - #change.content))
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, math.max(0, line_cursor - 1), 0, {
          virt_lines = { { { padded, "AIDiffAdd" } } }, virt_lines_above = false,
        })
      elseif change.type == " " then
        line_cursor = line_cursor + 1
      end
    end
    ::continue::
  end
end

return M
