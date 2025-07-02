-- /lua/ai-coding-assistant/config.lua
local M = {}

-- This table holds the plugin's default settings
M.defaults = {
  default_provider = "gemini",
  default_model = "gemini-2.5-flash",
  models = {
    { provider = "openai", model = "o4-mini", display = "🤖 OpenAI: GPT-o4 Mini" },
    { provider = "openai", model = "gpt-4.1-mini", display = "🤖 OpenAI: GPT-4.1 Mini" },
    { provider = "anthropic", model = "claude-opus-4-20250514", display = "🌶️ Anthropic: Claude Opus 4" },
    { provider = "anthropic", model = "claude-sonnet-4-20250514", display = "🌶️ Anthropic: Claude Sonnet 4" },
    { provider = "gemini", model = "gemini-2.5-pro", display = "✨ Gemini: 2.5 Pro" },
    { provider = "gemini", model = "gemini-2.5-flash", display = "⚡ Gemini: 2.5 Flash" },
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
