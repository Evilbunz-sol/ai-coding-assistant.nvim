-- This module is responsible for parsing @-mentions and reading file content.

local M = {}

-- A helper function to read the content of a file safely.
local function read_file_content(path)
  -- Resolve the full path relative to the current working directory
  local full_path = vim.fn.fnamemodify(path, ":p")
  local file = io.open(full_path, "r")

  if not file then
    return nil, "Could not open file: " .. path
  end

  local content = file:read("*a")
  file:close()
  return content, nil
end

-- The main public function. It takes a string and returns the original
-- prompt plus a formatted block of context from any found files.
function M.parse(input_prompt)
  local context_parts = {}
  local clean_prompt = input_prompt

  -- Find all instances of @filepath in the prompt
  for path in input_prompt:gmatch("@([%w_./-]+)") do
    local content, err = read_file_content(path)

    if content then
      -- Add the file content to our context block
      table.insert(context_parts, "--- Context from: " .. path .. " ---\n")
      table.insert(context_parts, content)
      table.insert(context_parts, "\n--- End of Context from: " .. path .. " ---\n")

      -- Remove the @mention from the prompt that the user sees
      clean_prompt = clean_prompt:gsub("@" .. path, path)
    else
      vim.notify(err, vim.log.levels.WARN, { title = "AI Assistant" })
    end
  end

  if #context_parts > 0 then
    -- If we found any context, combine it all into one block
    local full_context = table.concat(context_parts, "\n")
    return clean_prompt, full_context
  end

  -- If no @-mentions were found, return nil for the context
  return clean_prompt, nil
end

return M
