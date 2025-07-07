-- This module applies virtual highlights to code buffers based on a parsed diff.

local M = {}

-- Define a namespace for our highlights so we can clear them later.
local ns = vim.api.nvim_create_namespace("ai_assistant_diff")

-- We define the highlight groups here.
local function setup_highlights()
  vim.api.nvim_set_hl(0, "AIDiffDelete", { bg = "#4C383F" }) -- Dark red background
  vim.api.nvim_set_hl(0, "AIDiffAdd", { bg = "#2E4842" }) -- Dark green background
end

-- Clears all highlights from a given buffer.
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Applies the highlights for a parsed diff to the correct file.
function M.apply(parsed_diff)
  setup_highlights()

  -- Find the buffer for the file we need to modify.
  local target_bufnr = vim.fn.bufnr(parsed_diff.file_path, true)
  if target_bufnr == -1 then
    vim.notify("Could not find open buffer for: " .. parsed_diff.file_path, vim.log.levels.WARN)
    return
  end

  -- Clear any previous highlights in this buffer.
  M.clear(target_bufnr)

  local current_line_in_buffer = 0
  for _, hunk in ipairs(parsed_diff.hunks) do
    current_line_in_buffer = hunk.original_start_line - 1

    for _, change in ipairs(hunk.changes) do
      if change.type == "delete" then
        -- For deletions, highlight the existing line in red.
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          end_line = current_line_in_buffer + 1,
          hl_group = "AIDiffDelete",
        })
        current_line_in_buffer = current_line_in_buffer + 1
      elseif change.type == "add" then
        -- For additions, add a "virtual" line of text in green.
        -- It appears on screen but isn't actually in the file.
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, current_line_in_buffer, 0, {
          virt_lines = { { { change.content, "AIDiffAdd" } } },
          virt_lines_above = false, -- Place the virtual line below the current line
        })
      elseif change.type == "context" then
        -- Context lines just advance our position in the buffer.
        current_line_in_buffer = current_line_in_buffer + 1
      end
    end
  end
end

return M
