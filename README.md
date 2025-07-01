# nvim-ai-assistant

A Neovim plugin for AI-powered code assistance, integrating OpenAI, Anthropic, and Gemini APIs. Use Telescope to select AI models and run commands on visually selected code to refactor, optimize, or explain code snippets.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/Evilbunz_sol/nvim-ai-assistant/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/Evilbunz_sol/nvim-ai-assistant)](https://github.com/Evilbunz_sol/nvim-ai-assistant)

## Features

- **Model Selection**: Choose AI models (e.g., GPT-4o, Claude, Gemini) via a Telescope picker.
- **Code Interaction**: Run AI commands on selected code for refactoring, optimization, or explanations.
- **Multi-Provider Support**: Supports OpenAI, Anthropic, and Gemini, with extensible provider configuration.
- **Configurable Keymaps**: Customize keybindings for model selection and command execution.
- **Secure API Keys**: Load API keys from a `.env` file using `dotenv.nvim`.
- **Asynchronous Requests**: Non-blocking API calls for smooth performance.

## Requirements

- Neovim >= 0.8
- `curl` installed (required for API requests)
- API keys for AI providers, stored in a `.env` file in your project root or home directory
- Dependencies:
  - [ellisonleao/dotenv.nvim](https://github.com/ellisonleao/dotenv.nvim)
  - [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  - [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

Install `nvim-ai-assistant` using your preferred plugin manager. Example for [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Evilbunz_sol/nvim-ai-assistant",
  dependencies = {
    "ellisonleao/dotenv.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("ai-assistant").setup({
      provider = "openai",
      model = "gpt-4o",
      keymaps = {
        select_model = "<leader>am",
        run_command = "<leader>ac",
      },
    })
  end,
}
```

## Usage

1. Create a `.env` file in your project root or home directory:
   ```env
   OPENAI_API_KEY=sk-...
   ```
2. In Neovim, press `<leader>am` (default: `\am`) to open the Telescope picker and select an AI model.
3. In visual mode (`v`), select code lines.
4. Press `<leader>ac` (`\ac`), enter a command (e.g., "Refactor this function"), and the selected code will be replaced with the AI's response.

**Example**:

- Select:
  ```lua
  function add(a, b)
    return a + b
  end
  ```
- Press `<leader>ac`, enter "Add input validation".
- Result:
  ```lua
  function add(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then
      error("Inputs must be numbers")
    end
    return a + b
  end
  ```

See `:help ai-assistant` for detailed documentation.

## Configuration

Customize the plugin with the `setup` function:

```lua
require("ai-assistant").setup({
  provider = "openai", -- Default provider
  model = "gpt-4o",   -- Default model
  keymaps = {
    select_model = "<leader>am", -- Select AI model
    run_command = "<leader>ac",  -- Run AI command
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
    -- Add custom providers (e.g., anthropic, gemini)
  },
  models = {
    { provider = "openai", model = "gpt-4o-mini", display = "🤖 OpenAI: gpt-4o-mini" },
    -- Add more models
  },
})
```

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please:

- Open an [issue](https://github.com/Evilbunz_sol/nvim-ai-assistant/issues) for bugs or feature requests.
- Submit a [pull request](https://github.com/Evilbunz_sol/nvim-ai-assistant/pulls) with improvements.
- Suggested contributions: new AI providers, prompt templates, or UI enhancements.

```

```
