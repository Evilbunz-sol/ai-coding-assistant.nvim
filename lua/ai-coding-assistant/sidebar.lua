local context = require("ai-coding-assistant.context")

local M = {}

local state = {
  chat_win = nil,
  chat_buf = nil,
  input_win = nil,
  input_buf = nil,
  conversation = {},
}

-- Forward declarations
local open_sidebar
local close_sidebar
local submit_input
local render_conversation

-- This new function will handle the @-mention logic
local function handle_input_change()
  local line = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1] or ""
  local trigger = line:match "@$"

  if trigger then
    vim.cmd.stopinsert()
    vim.schedule(function()
      require("telescope.builtin").find_files({
        prompt_title = "Select Context File",
        cwd = vim.fn.getcwd(),
        attach_mappings = function(prompt_bufnr, map)
          map("i", "<CR>", function(p_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()

            --> THIS IS THE CORRECTED LINE
            require("telescope.actions").close(p_bufnr)

            local current_line = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1] or ""
            local new_line = current_line:gsub("@$", "@" .. selection.value .. " ")
            vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { new_line })
            vim.api.nvim_set_current_win(state.input_win)
            vim.cmd.startinsert()
          end)
          return true
        end,
      })
    end)
  end
end

render_conversation = function()
  -- (This function remains the same as before)
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
  vim.api.nvim_win_set_cursor(state.chat_win, { #lines_to_render, 0 })
end

submit_input = function()
  if not state.input_buf then return end

  local input = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1]
  if not input or input == "" then return end

  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })

  --> NEW: Parse the input for @-mentions BEFORE doing anything else.
  local clean_prompt, context_block = context.parse(input)

  -- Add the user's message to the history (using the clean version without @)
  table.insert(state.conversation, "👤 **You**")
  table.insert(state.conversation, clean_prompt)
  table.insert(state.conversation, "")
  table.insert(state.conversation, "🤖 **AI Assistant**")
  table.insert(state.conversation, "Thinking...")
  render_conversation()

  local core = require("ai-coding-assistant.core")

  --> NEW: Pass the context_block to the core engine.
  core.request(clean_prompt, context_block, function(response)
    table.remove(state.conversation) -- Remove "Thinking..."
    table.insert(state.conversation, response)
    render_conversation()
  end)
end


close_sidebar = function()
  -- (This function remains the same as before)
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_win_close(state.chat_win, true)
  end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  state = { chat_win = nil, chat_buf = nil, input_win = nil, input_buf = nil, conversation = {} }
end

open_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_set_current_win(state.input_win or state.chat_win)
    return
  end

  local bottom_padding = 3
  local sidebar_height = vim.o.lines - bottom_padding
  state.chat_buf = vim.api.nvim_create_buf(false, true)
  local width = 60
  state.chat_win = vim.api.nvim_open_win(state.chat_buf, true, {
    relative = 'editor', width = width, height = sidebar_height - 3, row = 0,
    col = vim.o.columns - width, style = 'minimal', border = 'single',
  })
  state.input_buf = vim.api.nvim_create_buf(false, true)
  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative = 'editor', width = width, height = 1, row = sidebar_height - 2,
    col = vim.o.columns - width, style = 'minimal', border = 'single', noautocmd = true,
  })

  vim.api.nvim_win_set_option(state.chat_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Normal')
  vim.api.nvim_win_set_option(state.input_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_buf_set_option(state.chat_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_option(state.chat_win, 'wrap', true)

  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.chat_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(state.input_win) vim.cmd('startinsert') end, { buffer = state.chat_buf, silent = true, desc = "Focus Input" })
  vim.keymap.set('i', '<CR>', submit_input, { buffer = state.input_buf, silent = true, desc = "Submit to AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.input_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(state.chat_win) end, { buffer = state.input_buf, silent = true, desc = "Focus Chat" })

  --> NEW: Create an autocommand to watch for changes in the input buffer
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = state.input_buf,
    callback = handle_input_change,
  })

  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd('startinsert')
  state.conversation = { "# AI Chat", "Type your message below and press Enter." }
  render_conversation()
end

M.toggle = function()
  -- (This function remains the same as before)
  if (state.chat_win and vim.api.nvim_win_is_valid(state.chat_win)) then
    close_sidebar()
  else
    open_sidebar()
  end
end

return M
