-- lua/ai-coding-assistant/context.lua
local M = {}

--- Parses the user input to find an explicit file path mention.
-- Returns the clean prompt and the path if found.
function M.get_explicit_path(input_prompt)
  local clean_prompt = input_prompt
  local found_path = nil

  -- Look for an @-mention
  local mention_path = input_prompt:match("@([%w_./-]+)")
  if mention_path then
    found_path = mention_path
    clean_prompt = clean_prompt:gsub("@" .. mention_path, "")
  else
    -- Look for a leading file path
    local leading_path = input_prompt:match("^([%w_./-]+)%s")
    if leading_path and vim.fn.filereadable(leading_path) == 1 then
      found_path = leading_path
      clean_prompt = clean_prompt:gsub(leading_path, "")
    end
  end

  return clean_prompt:gsub("^%s*", ""):gsub("%s*$", ""), found_path
end

return M
