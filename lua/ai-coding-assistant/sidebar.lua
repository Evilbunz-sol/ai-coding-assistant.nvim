-- lua/ai-coding-assistant/sidebar.lua
local context = require("ai-coding-assistant.context")
local diff = require("ai-coding-assistant.diff")
local highlighter = require("ai-coding-assistant.highlighter")
local applier = require("ai-coding-assistant.applier")

local M = {}

-- Add last_active_bufnr to the state table
local state = {
  chat_win = nil,
  chat_buf = nil,
  input_win = nil,
  input_buf = nil,
  conversation = {},
  last_active_bufnr = nil,
}

local open_sidebar
local close_sidebar
local submit_input
local render_conversation
local handle_input_change
local setup_diff_actions

-- This function remains the same
setup_diff_actions = function(parsed_diff)
  local function cleanup_diff_actions()
    vim.api.nvim_buf_del_keymap(state.chat_buf, 'n', 'a')
    vim.api.nvim_buf_del_keymap(state.chat_buf, 'n', 'x')
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

  vim.keymap.set('n', 'a', on_apply, { buffer = state.chat_buf, silent = true, desc = "Apply AI Diff" })
  vim.keymap.set('n', 'x', on_reject, { buffer = state.chat_buf, silent = true, desc = "Reject AI Diff" })
end

-- This function remains the same
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

-- This function remains the same
handle_input_change = function()
  local line = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1] or ""
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

-- Pass the saved buffer to the context parser
submit_input = function()
  if not state.input_buf then return end

  local input = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)[1]
  if not input or input == "" then return end

  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
  local clean_prompt, context_block = context.parse(input, state.last_active_bufnr)

  table.insert(state.conversation, "👤 **You**")
  table.insert(state.conversation, clean_prompt)
  table.insert(state.conversation, "")
  table.insert(state.conversation, "🤖 **AI Assistant**")
  table.insert(state.conversation, "Thinking...")
  render_conversation()

  local core = require("ai-coding-assistant.core")

  core.request(clean_prompt, context_block, function(response)
    local thinking_index = #state.conversation
    local parsed_diff, err = diff.parse(response)

    if parsed_diff then
      local explanation = response:match("^(.-)```diff
      state.conversation[thinking_index] = explanation:gsub("^%s*", ""):gsub("%s*$", "")
      highlighter.apply(parsed_diff)
      table.insert(state.conversation, "")
      table.insert(state.conversation, "*Changes highlighted. Press 'a' to apply or 'x' to reject.*")
      setup_diff_actions(parsed_diff)
    elseif err then
      state.conversation[thinking_index] = "Error parsing diff: " .. err
    else
      state.conversation[thinking_index] = response
    end

    render_conversation()
  end)
end

-- This function remains the same
close_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_win_close(state.chat_win, true)
  end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
    vim.api.nvim_win_close(state.input_win, true)
  end
  -- Reset the entire state on close
  state = { chat_win = nil, chat_buf = nil, input_win = nil, input_buf = nil, conversation = {}, last_active_bufnr = nil }
end

-- Capture the buffer handle when opening the sidebar, but only if it's named
open_sidebar = function()
  if state.chat_win and vim.api.nvim_win_is_valid(state.chat_win) then
    vim.api.nvim_set_current_win(state.input_win or state.chat_win)
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_buf)
  if buf_name ~= "" then
    state.last_active_bufnr = current_buf
  else
    state.last_active_bufnr = nil  -- Skip if unnamed
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
  vim.api.nvim_set_hl(0, "AICodeBlock", { bg = "#2E3440" })
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
