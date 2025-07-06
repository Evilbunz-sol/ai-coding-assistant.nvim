local M = {}

-- State now tracks the main window/buffer AND the input window/buffer
local state = {
  chat_win = nil,
  chat_buf = nil,
  input_win = nil,
  input_buf = nil,
  conversation = {},
}

local open_sidebar
local close_sidebar

-- Renders the conversation history into the main chat pane
local function render_conversation()
  if not state.chat_buf or not vim.api.nvim_buf_is_valid(state.chat_buf) then return end
  local lines_to_render = {}
  for _, content in ipairs(state.conversation) do
    for _, s_line in ipairs(vim.split(content, "\n")) do
      table.insert(lines_to_render, s_line)
    end
  end
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.chat_buf, 0, -1, false, lines_to_render)
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  -- Move cursor to the end of the buffer
  vim.api.nvim_win_set_cursor(state.chat_win, { #lines_to_render, 0 })
end

-- This function is called when you press Enter in the input box
local function submit_input()
  if not state.input_buf then return end

  -- Get the text from the single-line input buffer
  local input = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1]
  if not input or input == "" then return end

  -- Clear the input buffer for the next message
  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })

  -- Update conversation history
  table.insert(state.conversation, "👤 **You**")
  table.insert(state.conversation, input)
  table.insert(state.conversation, "")
  table.insert(state.conversation, "🤖 **AI Assistant**")
  table.insert(state.conversation, "Thinking...")
  render_conversation()

  -- Make the API call
  local core = require("ai-coding-assistant.core")
  core.request(input, function(response)
    table.remove(state.conversation) -- Remove "Thinking..."
    table.insert(state.conversation, response)
    render_conversation()
  end)
end

close_sidebar = function()
  -- Close both windows
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_win_close(state.chat_win, true)
  end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  -- Reset the entire state
  state = { buf = nil, win = nil, input_buf = nil, input_win = nil, conversation = {} }
end

open_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_set_current_win(state.input_win or state.chat_win)
    return
  end

  local bottom_padding = 2
  local sidebar_height = vim.o.lines - bottom_padding

  -- 1. Create the main chat history buffer and window
  state.chat_buf = vim.api.nvim_create_buf(false, true)
  local width = 60
  local chat_win_opts = {
    relative = 'editor',
    width = width,
    height = sidebar_height - 3,
    row = 0,
    col = vim.o.columns - width,
    style = 'minimal',
    border = 'single',
    -- 'winhighlight' key removed from here
  }
  state.chat_win = vim.api.nvim_open_win(state.chat_buf, true, chat_win_opts)

  -- 2. Create the input buffer and window
  state.input_buf = vim.api.nvim_create_buf(false, true)
  local input_win_opts = {
    relative = 'editor',
    width = width,
    height = 1,
    row = sidebar_height - 2,
    col = vim.o.columns - width,
    style = 'minimal',
    border = 'single',
    noautocmd = true,
    -- 'winhighlight' key removed from here
  }
  state.input_win = vim.api.nvim_open_win(state.input_buf, true, input_win_opts)

  -- 3. Set buffer/window options
  vim.api.nvim_buf_set_option(state.chat_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_option(state.chat_win, 'wrap', true)

  --> NEW: Set window highlights AFTER creating the windows
  vim.api.nvim_win_set_option(
    state.chat_win,
    'winhighlight',
    'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Normal'
  )
  vim.api.nvim_win_set_option(
    state.input_win,
    'winhighlight',
    'Normal:Normal,FloatBorder:FloatBorder'
  )

  -- 4. Set keymaps
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.chat_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(state.input_win) vim.cmd('startinsert') end, { buffer = state.chat_buf, silent = true, desc = "Focus Input" })
  vim.keymap.set('i', '<CR>', submit_input, { buffer = state.input_buf, silent = true, desc = "Submit to AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.input_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(state.chat_win) end, { buffer = state.input_buf, silent = true, desc = "Focus Chat" })

  -- 5. Final setup
  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd('startinsert')
  state.conversation = { "# AI Chat", "Press `i` to start a new conversation or `q` to close." }
  render_conversation()
end

function M.toggle()
  if (state.chat_win and vim.api.nvim_win_is_valid(state.chat_win)) then
    close_sidebar()
  else
    open_sidebar()
  end
end

return M

