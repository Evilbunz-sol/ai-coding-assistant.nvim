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
  state.win = nil
  state.buf = nil
end

-- Opens the sidebar window
local function open_sidebar()
  -- If it's already open, just focus it
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  -- Create a new scratch buffer for the chat
  state.buf = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'markdown')

  -- Open the window as a vertical split on the right
  vim.cmd('vsplit')
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)

  -- Set window options
  vim.api.nvim_win_set_width(state.win, 80) -- Set a fixed width
  vim.api.nvim_win_set_option(state.win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(state.win, 'number', false)
  vim.api.nvim_win_set_option(state.win, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.win, 'signcolumn', 'no')
end

-- The main public function to toggle the sidebar's visibility
function M.toggle()
  -- Find if a window for our buffer already exists
  local win_id = vim.fn.bufwinid(state.buf)

  if win_id ~= -1 and vim.api.nvim_win_is_valid(win_id) then
    -- If the window exists, close it
    close_sidebar()
  else
    -- If it doesn't exist, open it
    open_sidebar()
  end
end

return M
