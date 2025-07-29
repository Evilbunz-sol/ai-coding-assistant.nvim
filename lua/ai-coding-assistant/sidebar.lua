-- lua/ai-coding-assistant/sidebar.lua
local context_parser = require("ai-coding-assistant.context")
local diff_parser = require("ai-coding-assistant.diff")
local highlighter = require("ai-coding-assistant.highlighter")
local applier = require("ai-coding-assistant.applier")

local M = {}

local state = {
  win_ids = {},
  autocmd_group = nil,
  last_active_bufnr = nil,
  conversation = {},
}

local close_sidebar, update_last_active_buffer

-- ⭐️ THIS IS THE CORRECTED FUNCTION ⭐️
-- It now correctly checks if the window being entered is part of the chat UI.
update_last_active_buffer = function()
  local current_win_id = vim.api.nvim_get_current_win()
  -- Only update the active buffer if the new window is NOT our chat or input window.
  if current_win_id ~= state.win_ids.chat_win and current_win_id ~= state.win_ids.input_win then
    state.last_active_bufnr = vim.api.nvim_win_get_buf(current_win_id)
  end
end

local function handle_input_change()
  local line = vim.api.nvim_buf_get_lines(state.win_ids.input_buf, 0, -1, false)[1] or ""
  if line:match "@$" then
    vim.cmd.stopinsert()
    vim.schedule(function()
      require("telescope.builtin").find_files({
        prompt_title = "Select Context File",
        cwd = vim.fn.getcwd(),
        attach_mappings = function(prompt_bufnr, map)
          map("i", "<CR>", function(p_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()
            require("telescope.actions").close(p_bufnr)
            local current_line = vim.api.nvim_buf_get_lines(state.win_ids.input_buf, 0, -1, false)[1] or ""
            local new_line = current_line:gsub("@$", "@" .. selection.value .. " ")
            vim.api.nvim_buf_set_lines(state.win_ids.input_buf, 0, -1, false, { new_line })
            vim.api.nvim_set_current_win(state.win_ids.input_win)
            vim.cmd.startinsert()
          end)
          return true
        end,
      })
    end)
  end
end

local function run_ai_job(prompt)
  local job = {} -- This is our new Job Object
  local clean_prompt, explicit_path = context_parser.get_explicit_path(prompt)
  job.prompt = clean_prompt

  if explicit_path then
    job.target_bufnr = vim.fn.bufnr(explicit_path, true)
    if job.target_bufnr == -1 then
      vim.notify("Explicitly targeted file is not open: " .. explicit_path, vim.log.levels.ERROR)
      return
    end
  else
    job.target_bufnr = state.last_active_bufnr
  end

  if not job.target_bufnr or not vim.api.nvim_buf_is_valid(job.target_bufnr) then
    vim.notify("No valid code buffer to act on.", vim.log.levels.ERROR)
    return
  end
  job.target_path = vim.api.nvim_buf_get_name(job.target_bufnr)

  local buffer_content = table.concat(vim.api.nvim_buf_get_lines(job.target_bufnr, 0, -1, false), "\n")
  local context_block = "--- Context from file: " .. job.target_path .. " ---\n" .. buffer_content .. "\n--- End of Context ---"

  table.insert(state.conversation, "👤 " .. job.prompt)
  table.insert(state.conversation, "🤖 Thinking...")
  M.render()

  require("ai-coding-assistant.core").request(job.prompt, context_block, function(response)
    local hunks, err = diff_parser.parse_hunks(response)
    state.conversation[#state.conversation] = "🤖 " .. (response:match("^(.-)```diff") or "AI Response:")

    if hunks then
      highlighter.apply(job.target_bufnr, hunks)
      table.insert(state.conversation, "*Changes highlighted. Press 'a' to apply or 'x' to reject.*")

      local function cleanup()
        pcall(vim.api.nvim_buf_del_keymap, state.win_ids.chat_buf, 'n', 'a')
        pcall(vim.api.nvim_buf_del_keymap, state.win_ids.chat_buf, 'n', 'x')
      end
      vim.keymap.set('n', 'a', function() cleanup(); applier.apply(job.target_bufnr, hunks) end, { buffer = state.win_ids.chat_buf, silent = true })
      vim.keymap.set('n', 'x', function() cleanup(); highlighter.clear(job.target_bufnr) end, { buffer = state.win_ids.chat_buf, silent = true })
    else
      table.insert(state.conversation, "⚠️ " .. (err or "Could not apply changes."))
    end
    M.render()
  end)
end

function M.render()
  if not state.win_ids.chat_buf or not vim.api.nvim_buf_is_valid(state.win_ids.chat_buf) then return end
  local lines = {}
  for _, msg in ipairs(state.conversation) do
    for _, line in ipairs(vim.split(msg, '\n')) do table.insert(lines, line) end
  end
  vim.api.nvim_buf_set_option(state.win_ids.chat_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.win_ids.chat_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.win_ids.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_cursor(state.win_ids.chat_win, { #lines, 0 })
end

close_sidebar = function()
    -- Use pcall for safety in case a window is already closed
    pcall(vim.api.nvim_win_close, state.win_ids.chat_win, true)
    pcall(vim.api.nvim_win_close, state.win_ids.input_win, true)
    if state.autocmd_group then pcall(vim.api.nvim_del_augroup_by_id, state.autocmd_group) end
    -- Reset the state
    state = { win_ids = {}, autocmd_group = nil, last_active_bufnr = nil, conversation = {} }
end

function M.toggle()
  if state.win_ids.chat_win and vim.api.nvim_win_is_valid(state.win_ids.chat_win) then
    close_sidebar()
    return
  end

  state.last_active_bufnr = vim.api.nvim_get_current_buf()
  state.autocmd_group = vim.api.nvim_create_augroup("AICompanionSidebarTracker", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", { group = state.autocmd_group, callback = update_last_active_buffer })

  local width = 60
  local chat_buf = vim.api.nvim_create_buf(false, true)
  local chat_win = vim.api.nvim_open_win(chat_buf, true, {
    relative = 'editor', width = width, height = vim.o.lines - 3, row = 0,
    col = vim.o.columns - width, style = 'minimal', border = 'single',
  })
  local input_buf = vim.api.nvim_create_buf(false, true)
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = 'editor', width = width, height = 1, row = vim.o.lines - 2,
    col = vim.o.columns - width, style = 'minimal', border = 'single', noautocmd = true,
  })

  state.win_ids = { chat_win = chat_win, chat_buf = chat_buf, input_win = input_win, input_buf = input_buf }

  vim.api.nvim_win_set_option(chat_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Normal')
  vim.api.nvim_win_set_option(input_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_set_hl(0, "AICodeBlock", { bg = "#2E3440" })
  vim.api.nvim_buf_set_option(chat_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_option(chat_win, 'wrap', true)

  vim.keymap.set('n', 'q', close_sidebar, { buffer = chat_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(input_win) vim.cmd('startinsert') end, { buffer = chat_buf, silent = true, desc = "Focus Input" })
  vim.keymap.set('i', '<CR>', function() run_ai_job(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)[1]); vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""}) end, { buffer = input_buf, silent = true, desc = "Submit to AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = input_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(chat_win) end, { buffer = input_buf, silent = true, desc = "Focus Chat" })
  vim.api.nvim_create_autocmd("TextChangedI", { buffer = input_buf, callback = handle_input_change })

  state.conversation = { "# AI Chat", "Type your message below and press Enter." }
  M.render()
  vim.api.nvim_set_current_win(input_win)
  vim.cmd('startinsert')
end

return M
