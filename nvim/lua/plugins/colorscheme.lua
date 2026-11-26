return {
  -- "theme" colorscheme (colors/theme.lua): follows the global theme ~/.config/themes,
  -- falls back to colors/orange-black.lua (port of the Zed theme of the same name).
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "theme",
    },
  },
}
