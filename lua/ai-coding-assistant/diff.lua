-- This module will parse and eventually apply diffs from the AI

local M = {}

-- Parses a raw diff string into a structured table
function M.parse(diff_string)
  local parsed_diff = {}
  -- First, extract the content from the markdown code block
  local diff_content = diff_string:match("```diff\n(.-)\n```") or diff_string

  for line in diff_content:gmatch("([^\n]*)") do
    if line:sub(1, 1) == "+" then
      table.insert(parsed_diff, { type = "add", content = line })
    elseif line:sub(1, 1) == "-" then
      table.insert(parsed_diff, { type = "delete", content = line })
    else
      table.insert(parsed_diff, { type = "context", content = line })
    end
  end
  return parsed_diff
end

-- We will build this function in the next step
function M.apply(parsed_diff)
  vim.notify("Apply functionality not yet implemented.", vim.log.levels.INFO)
end

return M
