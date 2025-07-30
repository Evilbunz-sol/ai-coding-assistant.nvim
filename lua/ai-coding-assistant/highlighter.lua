-- lua/ai-coding-assistant/highlighter.lua
local M = {}

-- Create a dedicated namespace for all our virtual elements
local ns = vim.api.nvim_create_namespace("ai_assistant_inline_diff")

-- Define the highlight groups we'll use
local function setup_highlights()
  vim.api.nvim_set_hl(0, "AIDiffTextDelete", { fg = "#999999", strikethrough = true })
  vim.api.nvim_set_hl(0, "AIDiffSignDelete", { fg = "#e88388" })
  vim.api.nvim_set_hl(0, "AIDiffTextAdd", { bg = "#2E4842" })
  vim.api.nvim_set_hl(0, "AIDiffSignAdd", { fg = "#a6e3a1" })
end

-- Clear all highlights and virtual text from a buffer
function M.clear(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

-- The new rendering engine
function M.render(target_bufnr, hunks)
  setup_highlights()
  M.clear(target_bufnr)

  local line_count = vim.api.nvim_buf_line_count(target_bufnr)
  local lines_to_add = {}

  -- First pass: Mark deletions and prepare additions
  for _, hunk in ipairs(hunks) do
    local line_cursor = hunk.original_start_line
    if line_cursor > line_count + 1 then goto continue end

    for _, change in ipairs(hunk.changes) do
      if change.type == "-" then
        local line_idx = line_cursor - 1
        vim.api.nvim_buf_set_extmark(target_bufnr, ns, line_idx, 0, {
          end_line = line_idx, end_col = -1, hl_group = "AIDiffTextDelete",
        })
        -- ⭐️ FIX: Ensure line number is always 1 or greater
        vim.fn.sign_place(0, "AIDiff", "AIDiffSignDelete", target_bufnr, { lnum = math.max(1, line_cursor), priority = 10 })
        line_cursor = line_cursor + 1
      elseif change.type == "+" then
        if not lines_to_add[line_cursor] then lines_to_add[line_cursor] = {} end
        table.insert(lines_to_add[line_cursor], change.content)
      elseif change.type == " " then
        line_cursor = line_cursor + 1
      end
    end
    ::continue::
  end

  -- Second pass: Render additions as virtual text
  local sorted_add_keys = {}
  for k in pairs(lines_to_add) do table.insert(sorted_add_keys, k) end
  table.sort(sorted_add_keys, function(a, b) return a > b end)

  for _, line_num in ipairs(sorted_add_keys) do
    local virt_lines = {}
    for _, line_content in ipairs(lines_to_add[line_num]) do
      table.insert(virt_lines, { { line_content, "AIDiffTextAdd" } })
    end

    local display_line = math.max(0, line_num - 2)
    vim.api.nvim_buf_set_extmark(target_bufnr, ns, display_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
    -- ⭐️ FIX: Ensure line number is always 1 or greater
    vim.fn.sign_place(0, "AIDiff", "AIDiffSignAdd", target_bufnr, { lnum = math.max(1, line_num - 1), priority = 10 })
  end
end

return M
