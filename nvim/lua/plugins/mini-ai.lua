return {
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    opts = function()
      return {
        custom_textobjects = {
          -- LaTeX inline math: di$/ci$/da$/ca$ on $...$
          -- whole match ($...$) is `a`, region between the two () captures is `i`
          ["$"] = { "%$().-()%$" },
        },
      }
    end,
  },
}
