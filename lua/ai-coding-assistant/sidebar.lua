local context = require("ai-coding-assistant.context")
local diff = require("ai-coding-assistant.diff")
local highlighter = require("ai-coding-assistant.highlighter")

local M = {}

local state = {
  chat_win = nil,
  chat_buf = nil,
  input_win = nil,
  input_buf = nil,
  conversation = {},
}

local open_sidebar
local close_sidebar
local submit_input
local render_conversation
local handle_input_change

render_conversation = function()
  if not state.chat_buf or not vim.api.nvim_buf_is_valid(state.chat_buf) then return end
  local lines_to_render = {}
  local highlights = {}
  local line_num = 1
  local in_code_block = false
  for _, content in ipairs(state.conversation) do
    for _, s_line in ipairs(vim.split(content, "\n")) do
      table.insert(lines_to_render, s_line)
      if s_line:match("```") then
        in_code_block = not in_code_block
        table.insert(highlights, { "AICodeBlock", line_num - 1, 0, -1 })
      elseif in_code_block then
        table.insert(highlights, { "AICodeBlock", line_num - 1, 0, -1 })
      end
      line_num = line_num + 1
    end
  end
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', true)
  vim.api.nvim_buf_clear_namespace(state.chat_buf, -1, 0, -1)
  vim.api.nvim_buf_set_lines(state.chat_buf, 0, -1, false, lines_to_render)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.chat_buf, -1, hl[1], hl[2], hl[3], hl[4])
  end
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_cursor(state.chat_win, { #lines_to_render, 0 })
end

handle_input_change = function()
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

submit_input = function()
  if not state.input_buf then return end

  local input = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1]
  if not input or input == "" then return end

  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
  local clean_prompt, context_block = context.parse(input)

  table.insert(state.conversation, "👤 **You**")
  table.insert(state.conversation, clean_prompt)
  table.insert(state.conversation, "")
  table.insert(state.conversation, "🤖 **AI Assistant**")
  table.insert(state.conversation, "Thinking...")
  render_conversation()

  local core = require("ai-coding-assistant.core")

  core.request(clean_prompt, context_block, function(response)
    -- Remove the "Thinking..." message
    table.remove(state.conversation)

    -- Try to parse a diff from the AI's response
    local parsed_diff, err = diff.parse(response)

    if parsed_diff then
      -- If a diff was found:
      -- 1. Extract the conversational part (the text before the diff block)
      local explanation = response:match("^(.-)```diff") or "Here are the proposed changes:"
      table.insert(state.conversation, explanation:gsub("^%s*", ""):gsub("%s*$", ""))

      -- 2. Apply the highlights to the target code file
      highlighter.apply(parsed_diff)

      -- 3. Add a confirmation message to the chat
      table.insert(state.conversation, "\n*Changes have been highlighted in the source file.*")

    elseif err then
      -- If parsing failed, show the error
      table.insert(state.conversation, "Error parsing diff: " .. err)
    else
      -- If no diff was found, treat it as a normal chat message
      table.insert(state.conversation, response)
    end

    -- Re-render the chat window with the new content
    render_conversation()
  end)
end


close_sidebar = function()
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
  local bottom_padding = 5
  local sidebar_height = vim.o.lines - bottom_padding
  state.chat_buf = vim.api.nvim_create_buf(false, true)
  local width = 80
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
  vim.api.nvim_set_hl(0, "AICodeBlock", { bg = "#2E3440" }) -- Defines the background color
  vim.api.nvim_buf_set_option(state.chat_buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(state.chat_buf, 'modifiable', false)
  vim.api.nvim_win_set_option(state.chat_win, 'wrap', true)
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.chat_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(state.input_win) vim.cmd('startinsert') end, { buffer = state.chat_buf, silent = true, desc = "Focus Input" })
  vim.keymap.set('i', '<CR>', submit_input, { buffer = state.input_buf, silent = true, desc = "Submit to AI" })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = state.input_buf, silent = true, desc = "Close Chat" })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(state.chat_win) end, { buffer = state.input_buf, silent = true, desc = "Focus Chat" })
  vim.api.nvim_create_autocmd("TextChangedI", { buffer = state.input_buf, callback = handle_input_change })
  vim.api.nvim_set_current_win(state.input_win)
  vim.cmd('startinsert')
  state.conversation = { "# AI Chat", "Type your message below and press Enter." }
  render_conversation()
end

M.toggle = function()
  if (state.chat_win and vim.api.nvim_win_is_valid(state.chat_win)) then
    close_sidebar()
  else
    open_sidebar()
  end
end

return M
