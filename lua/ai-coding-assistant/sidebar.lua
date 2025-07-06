-- This module manages the AI chat sidebar UI

local M = {}

-- We'll store the buffer, window, and conversation history here
local state = {
  buf = nil,
  win = nil,
  conversation = {}, -- A table to hold our chat messages
}

-- Forward declaration for functions that call each other
local open_sidebar
local prompt_for_input

-- Renders the current conversation history into the sidebar buffer
local function render_conversation()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  -- Make the buffer writable to update it
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
  -- Clear the entire buffer
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
  -- Add the conversation lines
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, state.conversation)
  -- Make it read-only again
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
end

-- The function that handles user input and calls the AI
prompt_for_input = function()
  vim.ui.input({
    prompt = "Ask AI: ",
  }, function(input)
    if not input or input == "" then
      return
    end

    -- Add the user's message to the history
    table.insert(state.conversation, "👤 **You**")
    table.insert(state.conversation, input)
    table.insert(state.conversation, "") -- Add a blank line for spacing

    -- Add a temporary "thinking" message
    local thinking_index = #state.conversation + 1
    table.insert(state.conversation, "🤖 **AI Assistant**")
    table.insert(state.conversation, "Thinking...")

    -- Immediately update the sidebar to show the new messages
    render_conversation()

    -- Now, make the actual API call
    local core = require("ai-coding-assistant.core")
    core.request(input, function(response)
      -- When the response comes back, replace the "Thinking..." message
      state.conversation[thinking_index + 1] = response
      -- Re-render the conversation with the final AI response
      render_conversation()
    end)
  end)
end

-- Closes the sidebar window
local function close_sidebar()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  -- Clear the state completely when closed
  state.win = nil
  state.buf = nil
  state.conversation = {}
end

-- Opens the sidebar window
open_sidebar = function()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false) -- Read-only by default

  vim.cmd('vsplit')
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- Set window options
  vim.api.nvim_win_set_width(state.win, 80)
  vim.api.nvim_win_set_option(state.win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(state.win, 'number', false)
  vim.api.nvim_win_set_option(state.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.win, 'signcolumn', 'no')

  -- --> NEW: Set a keymap that ONLY works in this buffer
  vim.keymap.set('n', 'i', prompt_for_input, { buffer = state.buf, silent = true, desc = "Ask AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.buf, silent = true, desc = "Close Chat" })

  -- Add a welcome message
  table.insert(state.conversation, "# AI Chat")
  table.insert(state.conversation, "Press `i` to start a new conversation.")
  render_conversation()
end

-- The main public function to toggle the sidebar's visibility
function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close_sidebar()
  else
    open_sidebar()
  end
end

return M
