-- lua/ai-coding-assistant/diff.lua
local M = {}

--- Parses only the diff hunks from an AI response.
function M.parse_hunks(diff_string)
  local diff_content = diff_string:match("```diff\n(.-)\n```")
  if not diff_content then
    return nil, "Could not find a diff block in the AI response."
  end

  local lines = vim.split(diff_content, "\n")
  local hunks = {}
  local current_hunk = nil

  for _, line in ipairs(lines) do
    local hunk_match_start, _, old_start = line:find("^@@ %-(%d+),?%d* %+%d+,?%d* @@")
    if hunk_match_start then
      current_hunk = {
        original_start_line = tonumber(old_start),
        changes = {},
      }
      table.insert(hunks, current_hunk)
    elseif current_hunk then
      local change_type = line:sub(1, 1)
      if change_type == "+" or change_type == "-" or change_type == " " then
        table.insert(current_hunk.changes, { type = change_type, content = line:sub(2) })
      end
    end
  end

  if #hunks == 0 then
    return nil, "AI response did not contain any valid diff hunks."
  end

  return hunks, nil
end

return M
