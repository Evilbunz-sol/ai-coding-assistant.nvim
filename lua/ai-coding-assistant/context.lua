-- lua/ai-coding-assistant/context.lua
local M = {}

local function read_path_content(path)
  -- This helper function remains the same as your version
  local full_path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(full_path) ~= 1 then return nil, "Path is not a readable file: " .. path end

  local file = io.open(full_path, "r")
  if not file then return nil, "Could not open file: " .. path end

  local content = file:read("*a")
  file:close()
  return content, nil
end


function M.parse(input_prompt, default_bufnr)
  local context_blocks = {}
  local paths_to_process = {}

  -- Create a mutable copy of the prompt to strip mentions from
  local clean_prompt = input_prompt

  -- Find all @-mentions and add them to the list to be processed
  for path in input_prompt:gmatch("@([%w_./-]+)") do
    table.insert(paths_to_process, path)
    -- Replace the mention in the clean prompt to avoid sending it to the AI
    clean_prompt = clean_prompt:gsub("@" .. path, "")
  end


  if #paths_to_process == 0 and default_bufnr and vim.api.nvim_buf_is_valid(default_bufnr) then
    local buf_path = vim.api.nvim_buf_get_name(default_bufnr)
    if buf_path and buf_path ~= "" then
      table.insert(paths_to_process, buf_path)
    end
  end

  -- Now, process all the paths we've collected
  for _, path in ipairs(paths_to_process) do
    local content, err = read_path_content(path)
    if content then
      -- Add a clear header so the AI knows which file the context belongs to
      table.insert(context_blocks, "--- Context from file: " .. path .. " ---\n" .. content .. "\n--- End of Context ---")
    elseif err then
      vim.notify(err, vim.log.levels.WARN, { title = "AI Assistant" })
    end
  end

  -- Trim whitespace from the final prompt
  clean_prompt = clean_prompt:gsub("^%s+", ""):gsub("%s+$", "")

  if #context_blocks > 0 then
    return clean_prompt, table.concat(context_blocks, "\n\n")
  end

  return clean_prompt, nil
end

return M
