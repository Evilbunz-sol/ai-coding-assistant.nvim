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

-- The new, smarter parse function
function M.parse(input_prompt)
  local context_parts = {}
  local prompt_words = vim.split(input_prompt, "%s+")
  local final_prompt_words = {}
  local paths_to_process = {}
  local paths_processed = {} -- To avoid duplicates

  local path_word_count = 0
  -- First, check for leading file paths
  for i, word in ipairs(prompt_words) do
    if vim.fn.filereadable(word) == 1 or vim.fn.isdirectory(word) == 1 then
      table.insert(paths_to_process, word)
      path_word_count = i
    else
      break -- Stop as soon as we hit a non-path word
    end
  end

  -- The rest of the words form the main prompt
  for i = path_word_count + 1, #prompt_words do
    table.insert(final_prompt_words, prompt_words[i])
  end

  local clean_prompt = table.concat(final_prompt_words, " ")

  -- Second, find any @-mentions in the remaining prompt
  for path in clean_prompt:gmatch("@([%w_./-]+)") do
    table.insert(paths_to_process, path)
    -- Remove the @-mention from the final prompt text
    clean_prompt = clean_prompt:gsub("@" .. path, path)
  end

  -- Process all collected paths
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

  if #context_parts > 0 then
    return clean_prompt, table.concat(context_parts, "\n")
  end

  return clean_prompt, nil
end

return M
