-- Markdown: formatter (prettier) + in-buffer renderer (visualizer)
return {
  -- Browser preview: live rendered page, auto-reloads on save/type
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview (browser)" },
    },
    config = function()
      vim.cmd([[do FileType]])
    end,
  },

  -- Visualizer: renders headings, tables, checkboxes, code blocks in buffer
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle Markdown render (in-buffer)" },
    },
    opts = {
      enabled = false, -- OFF by default. Toggle: <leader>um
    },
  },

  -- Formatter: prettier for markdown via conform (LazyVim core)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        markdown = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
      },
    },
  },

  -- Make sure prettier binary + markdown treesitter parsers exist
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "prettier", "markdownlint-cli2", "marksman" },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "markdown", "markdown_inline" },
    },
  },
}
