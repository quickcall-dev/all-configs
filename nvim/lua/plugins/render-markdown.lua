-- Inline markdown rendering only — no linters, no LSP, no noise
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      bullet = { enabled = false },
      checkbox = { enabled = false },
      dash = { enabled = false },
    },
  },
}
