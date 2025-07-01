-- /lua/ai-coding-assistant/config.lua
local M = {}

-- This table holds the plugin's default settings
M.defaults = {
  default_provider = "openai",
  default_model = "gpt-4o",
  models = {
    { provider = "openai", model = "gpt-4o", display = "🤖 OpenAI: GPT-4o" },
    { provider = "openai", model = "gpt-3.5-turbo", display = "🤖 OpenAI: GPT-3.5 Turbo" },
    { provider = "anthropic", model = "claude-3-opus-20240229", display = "🌶️ Anthropic: Claude 3 Opus" },
    { provider = "anthropic", model = "claude-3-sonnet-20240229", display = "🌶️ Anthropic: Claude 3 Sonnet" },
    { provider = "anthropic", model = "claude-3-haiku-20240307", display = "🌶️ Anthropic: Claude 3 Haiku" },
    { provider = "gemini", model = "gemini-1.5-pro-latest", display = "✨ Gemini: 1.5 Pro" },
    { provider = "gemini", model = "gemini-1.5-flash-latest", display = "⚡ Gemini: 1.5 Flash" },
  },
  providers = {
    openai = {
      api_key_env = "OPENAI_API_KEY",
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
      build_payload = function(model, prompt)
        return { contents = { { parts = { { text = prompt } } } } }
      end,
      parse_response = function(json_data)
        return json_data.candidates and json_data.candidates[1].content.parts[1].text
      end,
    },
  },
}

--> This table will hold the final, merged settings.
M.options = {}

--> This function now sets our options table.
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--> This new function lets other files safely get the final config.
function M.get()
  return M.options
end

return M
