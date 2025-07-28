-- /dotfiles/nvim/lua/custom/ai_core.lua
local Job = require("plenary.job")
local M = {}

M.state = {
  current = {},
}

function M.request(prompt, context, callback)
  local config = require("ai-coding-assistant.config").get()
  local state = require("ai-coding-assistant.core").state

  if not state.current.provider then
    state.current.provider = config.default_provider
    state.current.model = config.default_model
  end

  local provider_name = state.current.provider
  local model_name = state.current.model
  local provider = config.providers[provider_name]
  local api_key = os.getenv(provider.api_key_env)

  if not provider or not api_key then
    vim.notify("AI provider config or API key not found for: " .. provider_name, vim.log.levels.ERROR)
    return
  end

  -- ⭐️ NEW, MORE ROBUST SYSTEM PROMPT
  local system_prompt = [[
You are an expert pair programmer integrated into Neovim. Follow these rules strictly:
1.  Your primary goal is to generate a single, valid unified diff for the requested change.
2.  The user's code will be provided as context, prefixed with '--- Context from file: ...'. Pay close attention to this file path.
3.  Your response MUST start with a brief, one-sentence explanation of the change.
4.  After the explanation, you MUST provide the code changes in a single markdown block using the unified diff format, like so: ```diff ... ```.
5.  The diff MUST contain the correct file path header (e.g., '--- a/path/to/file.ts').
6.  The line numbers in the diff (e.g., '@@ -1,5 +1,6 @@') MUST accurately match the provided context.
7.  **SPECIAL CASE: If the file context is empty, you are creating new content. Your diff MUST start with '@@ -0,0 +1,N @@' where N is the number of lines you are adding.**
8.  Do not include any other text, conversation, or apologies after the diff block.
]]

  local final_prompt
  if context then
    final_prompt = "System instruction:\n" .. system_prompt ..
                      "\n\nGiven the following context from the codebase:\n" .. context ..
                      "\n\nPlease perform the following task:\n\n" .. prompt
  else
    -- Added a case for no context, still providing the system prompt
    final_prompt = "System instruction:\n" .. system_prompt ..
                      "\n\nThe user provided no file context. Based on the request, generate a new file content block." ..
                      "\n\nPlease perform the following task:\n\n" .. prompt
  end

  local payload = provider.build_payload(model_name, final_prompt)
  local payload_json = vim.json.encode(payload)
  local provider_url = provider.url
  local curl_args = { "-s", "-X", "POST", provider_url, "-d", payload_json }

  if provider_name == "openai" then
    table.insert(curl_args, "-H"); table.insert(curl_args, "Authorization: Bearer " .. api_key)
  elseif provider_name == "anthropic" then
    table.insert(curl_args, "-H"); table.insert(curl_args, "x-api-key: " .. api_key)
    table.insert(curl_args, "-H"); table.insert(curl_args, "anthropic-version: 2023-06-01")
  elseif provider_name == "gemini" then
    curl_args[4] = provider_url .. "?key=" .. api_key
  end
  table.insert(curl_args, "-H"); table.insert(curl_args, "Content-Type: application/json")

  Job:new({
    command = "curl",
    args = curl_args,
    on_exit = function(job, return_val)
      if return_val ~= 0 then
        local error_output = table.concat(job:stderr_result(), "\n")
        vim.notify("AI API request failed. Code: " .. return_val .. "\n" .. error_output, vim.log.levels.ERROR)
        return
      end
      local response_body = table.concat(job:result(), "")
      local response_json, err = vim.json.decode(response_body)
      if err or not response_json then
        vim.notify("Failed to parse AI response: " .. response_body, vim.log.levels.ERROR)
        return
      end
      if response_json.error then
        vim.notify("API Error: " .. response_json.error.message, vim.log.levels.ERROR)
        return
      end
      local content = provider.parse_response(response_json)
      if content then
        vim.schedule(function() callback(content) end)
      else
        vim.notify("AI response format was unexpected: " .. response_body, vim.log.levels.WARN)
      end
    end,
  }):start()
end

return M
