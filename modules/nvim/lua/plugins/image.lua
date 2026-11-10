-- Inline image viewing (kitty graphics protocol — works in Ghostty, tmux passthrough enabled)
return {
  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = true },
    },
  },
}
