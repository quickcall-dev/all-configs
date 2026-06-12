-- Suppress TUI terminal mode warnings from noice.nvim popups
return {
  {
    "folke/noice.nvim",
    opts = {
      routes = {
        {
          filter = {
            event = "msg_show",
            find = "terminal mode",
          },
          opts = { skip = true },
        },
      },
    },
  },
}
