local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {}, {
  -- Inline math
  s({ trig = "mk" }, { t("$"), i(1), t("$") }),
  -- Block math
  s({ trig = "dm", wordTrig = true }, { t({ "$$", "" }), i(1), t({ "", "$$" }) }),
  -- Block align
  s({ trig = "Dm", wordTrig = true }, { t({ "$$", "\\begin{align}", "" }), i(1), t({ "", "\\end{align}", "$$" }) }),
  -- Block align*
  s({ trig = "d*" }, { t({ "$$", "\\begin{align*}", "" }), i(1), t({ "", "\\end{align*}", "$$" }) }),
}
