return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                                                     ",
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find file", "<cmd>Telescope find_files<cr>"),
      dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<cr>"),
      dashboard.button("g", "  Grep text", "<cmd>Telescope live_grep<cr>"),
      dashboard.button("e", "  New file", "<cmd>ene <BAR> startinsert<cr>"),
      dashboard.button("q", "  Quit", "<cmd>qa<cr>"),
    }

    dashboard.section.header.opts.hl = "AlphaHeader"
    dashboard.section.buttons.opts.hl = "AlphaButtons"

    alpha.setup(dashboard.opts)
  end,
}
