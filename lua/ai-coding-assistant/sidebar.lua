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
  active_suggestion = nil,
}

-- Forward-declare functions
local close_sidebar, update_last_active_buffer, handle_input_change

update_last_active_buffer = function()
  local current_win_id = vim.api.nvim_get_current_win()
  if not state.win_ids[current_win_id] then
    state.last_active_bufnr = vim.api.nvim_win_get_buf(current_win_id)
  end
end

handle_input_change = function()
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
  if state.active_suggestion then highlighter.clear(state.active_suggestion.target_bufnr) end
  state.active_suggestion = nil

  local clean_prompt, explicit_path = context_parser.get_explicit_path(prompt)
  local target_bufnr = explicit_path and vim.fn.bufnr(explicit_path, true) or state.last_active_bufnr

  if not target_bufnr or not vim.api.nvim_buf_is_valid(target_bufnr) then
    vim.notify("No valid code buffer to act on.", vim.log.levels.ERROR); return
  end

  local target_path = vim.api.nvim_buf_get_name(target_bufnr)
  local context_block = "--- Context from file: " .. target_path .. " ---\n" .. table.concat(vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false), "\n")

  table.insert(state.conversation, "👤 " .. clean_prompt)
  table.insert(state.conversation, "🤖 Thinking...")
  M.render()

  require("ai-coding-assistant.core").request(clean_prompt, context_block, function(response)
    local hunks, err = diff_parser.parse_hunks(response)
    state.conversation[#state.conversation] = "🤖 " .. (response:match("^(.-)```diff") or "AI Response:")

    if hunks then
      state.active_suggestion = { target_bufnr = target_bufnr, hunks = hunks }
      highlighter.render(target_bufnr, hunks)
      table.insert(state.conversation, string.format("*Changes for `%s` are previewed inline. Press 'a' to apply or 'x' to reject.*", vim.fn.fnamemodify(target_path, ":t")))
    else
      table.insert(state.conversation, "⚠️ " .. (err or "Could not generate a valid diff."))
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
  if state.active_suggestion then
    highlighter.clear(state.active_suggestion.target_bufnr)
    vim.fn.sign_unplace("AIDiff", { buffer = state.active_suggestion.target_bufnr })
  end
  for _, win in pairs(state.win_ids) do if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end end
  if state.autocmd_group then pcall(vim.api.nvim_del_augroup_by_id, state.autocmd_group) end
  state = { win_ids = {}, autocmd_group = nil, last_active_bufnr = nil, conversation = {}, active_suggestion = nil }
end

function M.toggle()
  if state.win_ids.chat_win and vim.api.nvim_win_is_valid(state.win_ids.chat_win) then close_sidebar() return end

  state.last_active_bufnr = vim.api.nvim_get_current_buf()
  state.autocmd_group = vim.api.nvim_create_augroup("AICompanionSidebarTracker", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", { group = state.autocmd_group, callback = update_last_active_buffer })
  vim.fn.sign_define("AIDiffSignDelete", { text = "-", texthl = "AIDiffSignDelete" })
  vim.fn.sign_define("AIDiffSignAdd", { text = "+", texthl = "AIDiffSignAdd" })

  -- ⭐️ YOUR PREFERRED LAYOUT AND STYLING ⭐️
  local bottom_padding = 3
  local sidebar_height = vim.o.lines - bottom_padding
  local width = 60
  
  local chat_buf = vim.api.nvim_create_buf(false, true)
  local chat_win = vim.api.nvim_open_win(chat_buf, true, {
    relative = 'editor', width = width, height = sidebar_height - 3, row = 0,
    col = vim.o.columns - width, style = 'minimal', border = 'single',
  })
  local input_buf = vim.api.nvim_create_buf(false, true)
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = 'editor', width = width, height = 1, row = sidebar_height - 2,
    col = vim.o.columns - width, style = 'minimal', border = 'single', noautocmd = true,
  })
  
  state.win_ids = { chat_win = chat_win, chat_buf = chat_buf, input_win = input_win, input_buf = input_buf }
  
  -- ⭐️ YOUR PREFERRED OPTIONS AND HIGHLIGHTS ⭐️
  vim.api.nvim_win_set_option(chat_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Normal')
  vim.api.nvim_win_set_option(input_win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
  vim.api.nvim_set_hl(0, "AICodeBlock", { bg = "#2E3440" })
  vim.api.nvim_buf_set_option(chat_buf, 'filetype', 'markdown')
  vim.api.nvim_win_set_option(chat_win, 'wrap', true)

  -- ⭐️ YOUR PREFERRED KEYMAPS ⭐️
  local keymap_opts = { silent = true }
  vim.keymap.set('n', 'q', close_sidebar, { buffer = chat_buf, desc = "Close Chat", unpack(keymap_opts) })
  vim.keymap.set('n', 'i', function() vim.api.nvim_set_current_win(input_win); vim.cmd('startinsert') end, { buffer = chat_buf, desc = "Focus Input", unpack(keymap_opts) })
  vim.keymap.set('n', 'a', function()
    if state.active_suggestion then
      applier.apply(state.active_suggestion.target_bufnr, state.active_suggestion.hunks)
      state.active_suggestion = nil
      table.insert(state.conversation, "✅ Changes applied.")
      M.render()
    end
  end, { buffer = chat_buf, desc = "Apply Diff", unpack(keymap_opts) })
  vim.keymap.set('n', 'x', function()
    if state.active_suggestion then
      highlighter.clear(state.active_suggestion.target_bufnr)
      vim.fn.sign_unplace("AIDiff", { buffer = state.active_suggestion.target_bufnr })
      state.active_suggestion = nil
      table.insert(state.conversation, "❌ Changes rejected.")
      M.render()
    end
  end, { buffer = chat_buf, desc = "Reject Diff", unpack(keymap_opts) })
  
  vim.keymap.set('i', '<CR>', function() run_ai_job(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)[1]); vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {""}) end, { buffer = input_buf, unpack(keymap_opts) })
  vim.keymap.set('n', 'q', close_sidebar, { buffer = input_buf, desc = "Close Chat", unpack(keymap_opts) })
  vim.keymap.set('i', '<Esc>', function() vim.api.nvim_set_current_win(chat_win) end, { buffer = input_buf, desc = "Focus Chat", unpack(keymap_opts) })
  vim.api.nvim_create_autocmd("TextChangedI", { buffer = input_buf, callback = handle_input_change })

  state.conversation = { "# AI Chat", "Type your message below and press Enter." }
  M.render()
  vim.api.nvim_set_current_win(input_win)
  vim.cmd('startinsert')
end

return M
