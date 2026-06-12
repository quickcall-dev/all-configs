-- Inline markdown rendering — headings, code, tables, bold/italic only
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("render-markdown").setup({
        bullet = { enabled = false },
        checkbox = { enabled = false },
        dash = { enabled = false },
        sign = { enabled = false },
      })
    end,
  },
}
