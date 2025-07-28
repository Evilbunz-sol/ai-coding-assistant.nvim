-- This module parses the unified diff format from the AI's response.

-- lua/ai-coding-assistant/diff.lua
local M = {}

function M.parse(diff_string)
  local diff_content = diff_string:match("```diff\n(.-)\n```")
  if not diff_content then
    return nil, "Could not find a diff block in the AI response."
  end

  local lines = vim.split(diff_content, "\n")
  local parsed_diff = {
    file_path = nil,
    hunks = {},
  }
  local current_hunk = nil

  for _, line in ipairs(lines) do
    if not parsed_diff.file_path then
      -- Prioritize finding the file path from '--- a/path' or '+++ b/path'
      local file_match = line:match("^%-%-%- a/(.+)") or line:match("^%+%+%+ b/(.+)")
      if file_match then
        -- Trim potential trailing whitespace or metadata git sometimes adds
        parsed_diff.file_path = file_match:match("([%w%./_-]+)")
      end
    end

    local hunk_match_start, _, old_start, _, new_start = line:find("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    if hunk_match_start then
      current_hunk = {
        original_start_line = tonumber(old_start),
        changes = {},
      }
      table.insert(parsed_diff.hunks, current_hunk)
    elseif current_hunk then
      local change_type = line:sub(1, 1)
      if change_type == "+" or change_type == "-" or change_type == " " then
        table.insert(current_hunk.changes, { type = change_type, content = line:sub(2) })
      end
    end
  end

  if not parsed_diff.file_path then
    return nil, "AI response did not contain a valid file path in the diff."
  end

  return parsed_diff, nil
end

return M
