-- This module will manage the AI chat sidebar UI

local M = {}

-- We'll store the buffer and window IDs here to keep track of the sidebar
local state = {
  buf = nil,
  win = nil,
}

-- Closes the sidebar window
local function close_sidebar()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  -- Reset the state
  state.win = nil
  state.buf = nil
end

-- Opens the sidebar window
local function open_sidebar()
  -- Create a new scratch buffer for the chat
  state.buf = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'markdown')

  -- Open the window as a vertical split on the right
  vim.cmd('vsplit')
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- Set window options
  vim.api.nvim_win_set_width(state.win, 80)
  vim.api.nvim_win_set_option(state.win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(state.win, 'number', false)
  vim.api.nvim_win_set_option(state.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.win, 'signcolumn', 'no')
end

-- The main public function to toggle the sidebar's visibility
function M.toggle()
  --> THIS IS THE CORRECTED LOGIC
  -- The most reliable way to check if the sidebar is open is to see if our stored window ID is valid.
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    -- If the window is valid, it's open. So, close it.
    close_sidebar()
  else
    -- If the window is not valid (or is nil), it's closed. So, open it.
    open_sidebar()
  end
end

return M
