local signs = {
  add = { text = "" },
  change = { text = "" },
  delete = { text = "" },
  topdelete = { text = "" },
  changedelete = { text = "" },
  untracked = { text = "" },
}

-- The blame panel (:Gitsigns blame) colours each author by a hash of their name, so one person
-- keeps one colour in every file, and each date by its age: the accent for today, accent2 at
-- about a week, fading to comment ink at two years and older. The scale is logarithmic and
-- absolute, so a file nobody touched in years reads as old throughout. Every colour comes from
-- the colorscheme's own groups, and follows it when it changes.

local author_groups = { "PreProc", "Function", "Type", "Statement", "String", "Structure", "Number", "Special" }

local function author_hl(author)
  if author == "Not Committed Yet" then
    return "Comment"
  end
  local h = 5381 -- djb2
  for i = 1, #author do
    h = (h * 33 + author:byte(i)) % 2 ^ 32
  end
  return author_groups[h % #author_groups + 1]
end

local AGE_LEVELS = 16
local HOUR, OLD = 3600, 2 * 365 * 86400

local function fg(group)
  local c = vim.api.nvim_get_hl(0, { name = group, link = false }).fg or 0x808080
  return { math.floor(c / 0x10000), math.floor(c / 0x100) % 0x100, c % 0x100 }
end

local function blend(a, b, t)
  local r = {}
  for i = 1, 3 do
    r[i] = math.floor(a[i] + (b[i] - a[i]) * t + 0.5)
  end
  return r[1] * 0x10000 + r[2] * 0x100 + r[3]
end

local age_defined = false
local function define_age_groups()
  local new, mid, old = fg "Directory", fg "Changed", fg "Comment" -- accent, accent2, faint
  for level = 0, AGE_LEVELS - 1 do
    local t = level / (AGE_LEVELS - 1)
    local color = t < 0.5 and blend(new, mid, t * 2) or blend(mid, old, t * 2 - 1)
    vim.api.nvim_set_hl(0, "BlameAge" .. level, { fg = color })
  end
  age_defined = true
end

local function age_hl(time)
  if not age_defined then
    define_age_groups()
  end
  local age = math.max(os.time() - time, HOUR)
  local t = math.min(math.log(age / HOUR) / math.log(OLD / HOUR), 1)
  return "BlameAge" .. math.floor(t * (AGE_LEVELS - 1) + 0.5)
end

local function blame_formatter(_, info, ctx)
  return {
    { info.abbrev_sha, "Comment" },
    { " " },
    { info.author .. string.rep(" ", ctx.max_author_width - vim.fn.strdisplaywidth(info.author)), author_hl(info.author) },
    { " " },
    { os.date("%Y-%m-%d", info.author_time), age_hl(info.author_time) },
  }
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("blame-colors", { clear = true }),
  callback = define_age_groups,
})

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("blame-panel", { clear = true }),
  pattern = "gitsigns-blame",
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, desc = "Close blame" })
  end,
})

return {
  "lewis6991/gitsigns.nvim",

  event = "BufRead",
  cmd = "Gitsigns",

  opts = {
    current_line_blame = true,
    signs = signs,
    signs_staged = signs,
    blame_formatter = blame_formatter,
  },
}
