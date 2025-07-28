-- lua/ai-coding-assistant/sidebar.lua
local context = require("ai-coding-assistant.context")
local diff = require("ai-coding-assistant.diff")
local highlighter = require("ai-coding-assistant.highlighter")
local applier = require("ai-coding-assistant.applier")

local M = {}

local state = {
  chat_win = nil,
  chat_buf = nil,
  input_win = nil,
  input_buf = nil,
  conversation = {},
  last_active_bufnr = nil,
  autocmd_group = nil,
}

local open_sidebar, close_sidebar, submit_input, render_conversation, setup_diff_actions, update_last_active_buffer

update_last_active_buffer = function()
  local bufnr = vim.api.nvim_get_current_buf()
  if bufnr ~= state.chat_buf and bufnr ~= state.input_buf then
    state.last_active_bufnr = bufnr
  end
end

setup_diff_actions = function(parsed_diff)
  local function cleanup_diff_actions()
    pcall(vim.api.nvim_buf_del_keymap, state.chat_buf, 'n', 'a')
    pcall(vim.api.nvim_buf_del_keymap, state.chat_buf, 'n', 'x')
  end
  local function on_apply()
    cleanup_diff_actions()
    applier.apply(parsed_diff)
    table.insert(state.conversation, "*✅ Changes applied.*")
    render_conversation()
  end
  local function on_reject()
    cleanup_diff_actions()
    local target_bufnr = vim.fn.bufnr(parsed_diff.file_path, true)
    if target_bufnr ~= -1 then
      highlighter.clear(target_bufnr)
    end
    table.insert(state.conversation, "*❌ Changes rejected.*")
    render_conversation()
  end
  vim.keymap.set('n', 'a', on_apply, { buffer = state.chat_buf, silent = true, nowait = true, desc = "Apply AI Diff" })
  vim.keymap.set('n', 'x', on_reject, { buffer = state.chat_buf, silent = true, nowait = true, desc = "Reject AI Diff" })
end

render_conversation = function()
  if not state.chat_buf or not vim.api.nvim_buf_is_valid(state.chat_buf) then return end
  local lines = {}
  for _, msg in ipairs(state.conversation) do
    for _, line in ipairs(vim.split(msg, '\n')) do table.insert(lines, line) end
  end
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.chat_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_cursor(state.chat_win, { #lines, 0 })
end

submit_input = function()
  if not state.input_buf then return end
  local input = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1]
  if not input or input == "" then return end
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })

  local clean_prompt, context_block = context.parse(input, state.last_active_bufnr)

  table.insert(state.conversation, "👤 **You**\n" .. clean_prompt)
  table.insert(state.conversation, "🤖 **AI Assistant**\nThinking...")
  render_conversation()

  require("ai-coding-assistant.core").request(clean_prompt, context_block, function(response)
    -- ⭐️ THIS IS THE NEW, CORRECT LOGIC ⭐️
    -- We build the entire AI message first, then replace the "Thinking..." message in one go.
    local final_ai_message = "🤖 **AI Assistant**\n"
    local parsed_diff, err = diff.parse(response)

    if parsed_diff then
      local explanation = response:match("^(.-)```diff") or "Here are the proposed changes:"
      final_ai_message = final_ai_message .. explanation:gsub("^%s*\n*", ""):gsub("%s*$", "")
      highlighter.apply(parsed_diff)
      -- Add the action prompt to the message
      final_ai_message = final_ai_message .. "\n\n*Changes highlighted. In this window, press 'a' to apply or 'x' to reject.*"
      setup_diff_actions(parsed_diff)
    else
      -- If there's an error or no diff, just append the whole response
      final_ai_message = final_ai_message .. (err or response)
    end

    -- Now, perform a single, safe replacement of the "Thinking..." message.
    state.conversation[#state.conversation] = final_ai_message
    render_conversation()
  end)
end

close_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then vim.api.nvim_win_close(state.chat_win, true) end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then vim.api.nvim_win_close(state.input_win, true) end
  if state.autocmd_group then pcall(vim.api.nvim_del_augroup_by_id, state.autocmd_group) end
  state = { chat_win = nil, chat_buf = nil, input_win = nil, input_buf = nil, conversation = {}, last_active_bufnr = nil, autocmd_group = nil }
end

open_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_set_current_win(state.input_win)
    return
  end

  state.last_active_bufnr = vim.api.nvim_get_current_buf()
  state.autocmd_group = vim.api.nvim_create_augroup("AICompanionSidebarTracker", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", { group = state.autocmd_group, callback = update_last_active_buffer })

  local width = 60
  state.chat_buf = vim.api.nvim_create_buf(false, true)
  state.chat_win = vim.api.nvim_open_win(state.chat_buf, true, {
    relative = 'editor', col = vim.o.columns - width, width = width, height = vim.o.lines - 4, row = 0, style = 'minimal', border = 'single',
  })
  state.input_buf = vim.api.nvim_create_buf(false, true)
  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = 'editor', col = vim.o.columns - width, width = width, height = 1, row = vim.o.lines - 3, style = 'minimal', border = 'single',
  })

  vim.api.nvim_win_set_option(state.chat_win, 'wrap', true)
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.chat_buf, silent = true })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(state.input_win) end, { buffer = state.chat_buf, silent = true })
  vim.keymap.set('i', '<CR>', submit_input, { buffer = state.input_buf, silent = true })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(state.chat_win) end, { buffer = state.input_buf, silent = true })

  state.conversation = { "# AI Chat", "Type your message below and press Enter." }
  render_conversation()
  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd('startinsert')
end

M.toggle = function()
  if (state.chat_win and vim.api.nvim_win_is_valid(state.chat_win)) then close_sidebar() else open_sidebar() end
end

return M
