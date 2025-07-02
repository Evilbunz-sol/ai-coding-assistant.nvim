-- /dotfiles/nvim/lua/custom/ai_core.lua
local Job = require("plenary.job")
local M = {}

M.state = {
  current = {},
}

function M.request(prompt_text, callback)
  --> Get the final, merged config from our central config module.
  local config = require("ai-coding-assistant.config").get()

  if not M.state.current.provider then
    M.state.current.provider = config.default_provider
    M.state.current.model = config.default_model
  end

  local provider_name = M.state.current.provider
  local model_name = M.state.current.model
  local provider = config.providers[provider_name]

  local api_key = os.getenv(provider.api_key_env)
  if not provider or not api_key then
    vim.notify("AI provider config or API key not found for: " .. provider_name, vim.log.levels.ERROR)
    return
  end

  -- Create payload, send request to LLM, receive a response 
  local payload = provider.build_payload(model_name, prompt_text)
  local payload_json = vim.json.encode(payload)
  local provider_url = provider.url

  local curl_args = { "-s", "-X", "POST", provider_url, "-d", payload_json }
  if provider_name == "openai" then
    table.insert(curl_args, "-H")
    table.insert(curl_args, "Authorization: Bearer " .. api_key)
  elseif provider_name == "anthropic" then
    table.insert(curl_args, "-H")
    table.insert(curl_args, "x-api-key: " .. api_key)
    table.insert(curl_args, "-H")
    table.insert(curl_args, "anthropic-version: 2023-06-01")
  elseif provider_name == "gemini" then
    curl_args[4] = provider_url .. "?key=" .. api_key
  end
  table.insert(curl_args, "-H")
  table.insert(curl_args, "Content-Type: application/json")

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
        vim.schedule(function()
          callback(content)
        end)

      else
        vim.notify("AI response format was unexpected: " .. response_body, vim.log.levels.WARN)
      end
    end,
  }):start()
end

return M
