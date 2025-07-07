-- This module parses the unified diff format from the AI's response.

local M = {}

-- The main parsing function.
function M.parse(diff_string)
  -- First, extract just the content from the markdown code block.
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
  local original_line_num = 0

  for _, line in ipairs(lines) do
    -- Try to find the file path from the '--- a/path' or '+++ b/path' lines
    local file_match = line:match("^%-%-%- a/(.+)") or line:match("^%+%+%+ b/(.+)")
    if file_match then
      parsed_diff.file_path = file_match
    end

    -- Try to find a hunk header, e.g., @@ -1,5 +1,6 @@
    local hunk_match_start, hunk_match_end, old_start, _, new_start, _ = line:find("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    if hunk_match_start then
      original_line_num = tonumber(old_start)
      current_hunk = {
        original_start_line = original_line_num,
        changes = {},
      }
      table.insert(parsed_diff.hunks, current_hunk)
    elseif current_hunk then
      local change_type = line:sub(1, 1)
      if change_type == "+" then
        table.insert(current_hunk.changes, { type = "add", content = line:sub(2), line_num = 0 }) -- line_num is placeholder for now
      elseif change_type == "-" then
        table.insert(current_hunk.changes, { type = "delete", content = line:sub(2), line_num = original_line_num })
        original_line_num = original_line_num + 1
      elseif change_type == " " then
        -- This is a context line, it increments the line number for both old and new files.
        original_line_num = original_line_num + 1
      end
    end
  end

  if not parsed_diff.file_path then
    return nil, "Could not determine the file path from the diff."
  end

  return parsed_diff, nil
end

return M
