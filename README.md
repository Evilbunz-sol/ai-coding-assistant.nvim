# AI Coding Assistant

A simple and configurable Neovim plugin for AI-powered code assistance, integrating with OpenAI, Anthropic, and Gemini APIs. Use Telescope to select your preferred AI model and run commands on visually selected code to refactor, document, or transform it.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Evilbunz-sol/ai-coding-assistant.nvim/blob/main/LICENSE)

---

## Features

- **Multi-Provider Support**: Works out-of-the-box with OpenAI, Anthropic, and Gemini.
- **Model Selection**: Instantly switch between your favorite models (e.g., GPT-4o, Claude 3 Sonnet, Gemini 1.5 Flash) using a Telescope picker.
- **Direct Code Interaction**: Run AI commands directly on visually selected code blocks.
- **Highly Configurable**: Customize everything from default models and providers to keymaps and the list of available models.
- **Asynchronous by Design**: Uses non-blocking API calls to ensure your editor never freezes.
- **Secure**: Loads your secret API keys from a local `.env` file, keeping them out of your configuration.

---

## Requirements

- Neovim >= 0.8
- `curl` installed on your system.
- An API key for at least one AI provider.
- The following plugin dependencies:

  - [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  - [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
  - [Joakker/nvim-dotenv](https://github.com/Joakker/nvim-dotenv) (for loading API keys)

---

## Installation

Install using your preferred plugin manager.

Example with **[lazy.nvim](https://github.com/folke/lazy.nvim)**:

```lua
{
  "Evilbunz_sol/ai-coding-assistant.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "Joakker/nvim-dotenv",
  },
  config = function()
    require("ai-coding-assistant").setup({
      -- Your custom configuration goes here (see below)
      keymaps = {
        select_model = "<leader>am",
        run_command = "<leader>ac",
      },
    })
  end,
}
```

---

## Usage

### Set Up API Keys

Create a `.env` file in your project's root directory. The plugin will automatically load these keys.

```dotenv
# .env file
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."
GOOGLE_API_KEY="..."
```

### Select a Model (Optional)

In Normal mode, press `<leader>am` (or your custom keymap) to open the Telescope picker and choose an AI model for your session.

### Run a Command

1. In Visual mode (v), select a block of code.
2. Press `<leader>ac` (or your custom keymap).
3. An input prompt will appear at the bottom of the screen. Type your instruction (e.g., "Refactor this function to be more efficient" or "Add documentation to this code").
4. Press Enter. The selected code will be replaced with the AI's response.

---

## Configuration

You can override the default settings by passing an options table to the `setup()` function.

Here is the full default configuration you can use as a template:

```lua
require("ai-coding-assistant").setup({
  -- The provider to use when Neovim starts
  default_provider = "openai",

  -- The model to use when Neovim starts
  default_model = "gpt-4o",

  -- Custom keymaps. Set to false to disable default keymap creation.
  keymaps = {
    select_model = "<leader>am",
    run_command = "<leader>ac",
  },

  -- The list of models to display in the Telescope picker.
  -- You can add, remove, or change these to your liking.
  models = {
    { provider = "openai", model = "gpt-4o", display = "🤖 OpenAI: GPT-4o" },
    { provider = "openai", model = "gpt-3.5-turbo", display = "🤖 OpenAI: GPT-3.5 Turbo" },
    { provider = "anthropic", model = "claude-3-opus-20240229", display = "🌶️ Anthropic: Claude 3 Opus" },
    { provider = "anthropic", model = "claude-3-sonnet-20240229", display = "🌶️ Anthropic: Claude 3 Sonnet" },
    { provider = "anthropic", model = "claude-3-haiku-20240307", display = "🌶️ Anthropic: Claude 3 Haiku" },
    { provider = "gemini", model = "gemini-1.5-pro-latest", display = "✨ Gemini: 1.5 Pro" },
    { provider = "gemini", model = "gemini-1.5-flash-latest", display = "⚡ Gemini: 1.5 Flash" },
  },

  -- The technical details for each provider. You can extend this to add new providers.
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
})
```

---

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---

## License

This project is licensed under the MIT License.
