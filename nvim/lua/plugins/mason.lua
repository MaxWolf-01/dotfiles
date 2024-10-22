return {
  "williamboman/mason.nvim",

  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },

  opts = {
    ui = {
      icons = {
        package_pending = " ",
        package_installed = " ",
        package_uninstalled = " ",
      },
    },

    max_concurrent_installers = 10,
  },
}

