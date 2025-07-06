-- This module will manage the AI chat sidebar UI

local M = {}

local state = {
  buf = nil,
  win = nil,
  conversation = {},
}

local open_sidebar
local close_sidebar
local prompt_for_input

local function render_conversation()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, state.conversation)
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
end

prompt_for_input = function()
  vim.ui.input({
    prompt = "Ask AI: ",
  }, function(input)
    if not input or input == "" then return end

    table.insert(state.conversation, "👤 **You**")
    table.insert(state.conversation, input)
    table.insert(state.conversation, "")

    local thinking_index = #state.conversation + 1
    table.insert(state.conversation, "🤖 **AI Assistant**")
    table.insert(state.conversation, "Thinking...")
    render_conversation()

    local core = require("ai-coding-assistant.core")
    core.request(input, function(response)
      state.conversation[thinking_index + 1] = response
      render_conversation()
    end)
  end)
end

close_sidebar = function()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win, state.buf, state.conversation = nil, nil, {}
end

--> THIS IS THE CORRECTED OPEN_SIDEBAR FUNCTION
open_sidebar = function()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  -- Create a new scratch buffer for the chat first
  state.buf = vim.api.nvim_create_buf(false, true)

  -- Open the window as a vertical split on the right
  vim.cmd('vsplit')
  state.win = vim.api.nvim_get_current_win()

  -- Now, place our dedicated buffer into the new window
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- Configure the buffer AFTER it's in the window
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false) -- Set to read-only

  -- Set window options
  vim.api.nvim_win_set_width(state.win, 80)
  vim.api.nvim_win_set_option(state.win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(state.win, 'number', false)
  vim.api.nvim_win_set_option(state.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.win, 'signcolumn', 'no')

  -- Set keymaps that ONLY work in this buffer
  vim.keymap.set('n', 'i', prompt_for_input, { buffer = state.buf, silent = true, desc = "Ask AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.buf, silent = true, desc = "Close Chat" })

  -- Add a welcome message and render
  state.conversation = { "# AI Chat", "Press `i` to start a new conversation or `q` to close." }
  render_conversation()
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close_sidebar()
  else
    open_sidebar()
  end
end

return M
