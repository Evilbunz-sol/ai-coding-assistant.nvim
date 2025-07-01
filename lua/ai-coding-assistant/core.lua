-- /dotfiles/nvim/lua/custom/ai_core.lua
-- We no longer need require("dotenv").load() here
local Job = require("plenary.job")
local M = {}

M.config = {
  current = {
    provider = "openai",
    model = "gpt-4o", -- Make sure this model name is correct, gpt-4.1-mini is not a public model
  },
  providers = {
    -- We remove the api_key fields from here.
    openai = {
      api_key_env = "OPENAI_API_KEY", -- Store the name of the env variable instead
      url = "https://api.openai.com/v1/chat/completions",
      build_payload = function(model, prompt)
        return { model = model, messages = { { role = "user", content = prompt } } }
      end,
      parse_response = function(json_data)
        return json_data.choices and json_data.choices[1].message.content
      end,
    },
    anthropic = {
      api_key_env = "ANTHROPIC_API_KEY",
      url = "https://api.anthropic.com/v1/messages",
      -- ... (rest of anthropic config is the same)
      build_payload = function(model, prompt)
        return { model = model, max_tokens = 4096, messages = { { role = "user", content = prompt } } }
      end,
      parse_response = function(json_data)
        return json_data.content and json_data.content[1].text
      end,
    },
    gemini = {
      api_key_env = "GOOGLE_API_KEY",
      url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent",
      -- ... (rest of gemini config is the same)
      build_payload = function(model, prompt)
        return { contents = { { parts = { { text = prompt } } } } }
      end,
      parse_response = function(json_data)
        return json_data.candidates and json_data.candidates[1].content.parts[1].text
      end,
    },
  },
}

function M.request(prompt_text, callback)
  local provider_name = M.config.current.provider
  local model_name = M.config.current.model
  local provider = M.config.providers[provider_name]

  -- 🔽 THIS IS THE NEW, JUST-IN-TIME LOGIC 🔽
  local api_key = os.getenv(provider.api_key_env) -- Get the key now!

  if not provider or not api_key then
    vim.notify("AI provider config or API key not found for: " .. provider_name, vim.log.levels.ERROR)
    return
  end

  local payload = provider.build_payload(model_name, prompt_text)
  local payload_json = vim.json.encode(payload)
  
  -- The URL needs to be copied so we don't modify the original config table
  local provider_url = provider.url

  local curl_args = { "-s", "-X", "POST", provider_url, "-d", payload_json }

  if provider_name == "openai" then
    table.insert(curl_args, "-H")
    table.insert(curl_args, "Authorization: Bearer " .. api_key) -- Use the fresh key
  elseif provider_name == "anthropic" then
    table.insert(curl_args, "-H")
    table.insert(curl_args, "x-api-key: " .. api_key) -- Use the fresh key
    table.insert(curl_args, "-H")
    table.insert(curl_args, "anthropic-version: 2023-06-01")
  elseif provider_name == "gemini" then
    curl_args[4] = provider_url .. "?key=" .. api_key -- Use the fresh key
  end
  table.insert(curl_args, "-H")
  table.insert(curl_args, "Content-Type: application/json")

  -- The rest of the Job:new() function remains exactly the same...
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

      -- Check for API-level errors in the response body
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
