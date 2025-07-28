local M = {}

-- Helper function to read file/directory content safely
local function read_path_content(path)
  local full_path = vim.fn.fnamemodify(path, ":p")
  local content = {}
  local err = nil

  if vim.fn.filereadable(full_path) == 1 then
    local file = io.open(full_path, "r")
    if not file then
      return nil, "Could not open file: " .. path
    end
    local file_content = file:read("*a")
    file:close()
    table.insert(content, file_content)
  elseif vim.fn.isdirectory(full_path) == 1 then
    -- For directories, list the contents
    local files = vim.fn.readdir(full_path)
    table.insert(content, "Directory listing for " .. path .. ":\n")
    for _, file in ipairs(files) do
      if file ~= "." and file ~= ".." then
        table.insert(content, "- " .. file)
      end
    end
  else
    err = "Path not found: " .. path
  end

  if #content > 0 then
    return table.concat(content, "\n"), nil
  else
    return nil, err
  end
end

-- The parse function
function M.parse(input_prompt, default_bufnr) -- Note the new 'default_bufnr' argument
  local context_parts = {}
  local prompt_words = vim.split(input_prompt, "%s+")
  local final_prompt_words = {}
  local paths_to_process = {}
  local paths_processed = {}

  -- (The first part of the function parsing @-mentions and paths remains exactly the same)
  local path_word_count = 0
  for i, word in ipairs(prompt_words) do
    if vim.fn.filereadable(word) == 1 or vim.fn.isdirectory(word) == 1 then
      table.insert(paths_to_process, word)
      path_word_count = i
    else
      break
    end
  end
  for i = path_word_count + 1, #prompt_words do
    table.insert(final_prompt_words, prompt_words[i])
  end
  local clean_prompt = table.concat(final_prompt_words, " ")
  for path in clean_prompt:gmatch("@([%w_./-]+)") do
    table.insert(paths_to_process, path)
    clean_prompt = clean_prompt:gsub("@" .. path, "")
  end
  for _, path in ipairs(paths_to_process) do
    if not paths_processed[path] then
      local content, err = read_path_content(path)
      if content then
        table.insert(context_parts, "--- Context from: " .. path .. " ---\n")
        table.insert(context_parts, content)
        table.insert(context_parts, "\n--- End of Context ---\n")
      else
        vim.notify(err, vim.log.levels.WARN, { title = "AI Assistant" })
      end
      paths_processed[path] = true
    end
  end

  -- If no explicit paths were found, use the default buffer passed from the sidebar.
  if #context_parts == 0 and default_bufnr then
    local buf_path = vim.api.nvim_buf_get_name(default_bufnr)
    if buf_path and buf_path ~= "" then
      local content, err = read_path_content(buf_path)
      if content then
        table.insert(context_parts, "--- Context from: " .. buf_path .. " ---\n")
        table.insert(context_parts, content)
        table.insert(context_parts, "\n--- End of Context ---\n")
      elseif err then
        vim.notify(err, vim.log.levels.WARN, { title = "AI Assistant" })
      end
    end
  end

  if #context_parts > 0 then
    return clean_prompt, table.concat(context_parts, "\n")
  end

  return clean_prompt, nil
end

return M



