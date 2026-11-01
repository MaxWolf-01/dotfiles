-- Whole-file git blame in a panel left of the code, scrolling and moving its cursor with it.
--
-- Each commit's lines form a block. The block's first row holds the date, the author and the
-- start of the commit message; the message, then its body, flows down the block's other rows
-- under the author, so a long block reads the whole message and a short one ends on "…".
-- Colour means two things only: an author's colour is a hash of their name over the
-- colorscheme's eight hues (one person, one colour, in every file), and a date's colour is its
-- commit's rank by date among the file's commits: the accent for the newest, accent2 midway,
-- comment ink for the oldest. A rank spreads the colours evenly over whatever commits the file
-- has, where a scale in time would crowd most of them into one end. Every colour is read from
-- the colorscheme's groups and follows it.
--
-- `r` re-blames the file as it was just before the commit under the cursor, in place: the code
-- window shows that older version and the panel blames it, so a line rewritten by a reformat
-- can be followed back to whoever wrote it first. `<BS>` steps forward again.

local api = vim.api
local M = {}

local ns = api.nvim_create_namespace "blame"
local UNCOMMITTED = string.rep("0", 40)

-- Colours ------------------------------------------------------------------------------------

local author_groups = { "PreProc", "Function", "Type", "Statement", "String", "Structure", "Number", "Special" }

local function author_hl(author)
  local h = 5381 -- djb2
  for i = 1, #author do
    h = (h * 33 + author:byte(i)) % 2 ^ 32
  end
  return author_groups[h % #author_groups + 1]
end

local AGE_LEVELS = 16

local function fg(group)
  local c = api.nvim_get_hl(0, { name = group, link = false }).fg or 0x808080
  return { math.floor(c / 0x10000), math.floor(c / 0x100) % 0x100, c % 0x100 }
end

local function blend(a, b, t)
  local r = {}
  for i = 1, 3 do
    r[i] = math.floor(a[i] + (b[i] - a[i]) * t + 0.5)
  end
  return r[1] * 0x10000 + r[2] * 0x100 + r[3]
end

local function define_highlights()
  local new, mid, old = fg "Directory", fg "Changed", fg "Comment" -- accent, accent2, faint
  for level = 0, AGE_LEVELS - 1 do
    local t = level / (AGE_LEVELS - 1)
    api.nvim_set_hl(0, "BlameAge" .. level, { fg = t < 0.5 and blend(new, mid, t * 2) or blend(mid, old, t * 2 - 1) })
  end
end
define_highlights()
api.nvim_create_autocmd("ColorScheme", {
  group = api.nvim_create_augroup("blame-colors", { clear = true }),
  callback = define_highlights,
})

--- Each commit's age highlight, by its rank among `commits` from newest to oldest.
local function age_hls(commits)
  local list = vim.tbl_filter(function(c) return c.sha ~= UNCOMMITTED end, vim.tbl_values(commits))
  table.sort(list, function(a, b) return a.time > b.time end)
  local hls = {}
  for i, c in ipairs(list) do
    local t = #list > 1 and (i - 1) / (#list - 1) or 0
    hls[c.sha] = "BlameAge" .. math.floor(t * (AGE_LEVELS - 1) + 0.5)
  end
  return hls
end

-- Git ----------------------------------------------------------------------------------------

local function git(root, args, stdin)
  local r = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true, stdin = stdin }):wait()
  if r.code ~= 0 then
    return nil, vim.trim(r.stderr)
  end
  return r.stdout
end

--- One entry per line of the blamed text, each pointing at its commit.
local function parse_porcelain(out)
  local commits, entries, cur = {}, {}, nil
  for _, l in ipairs(vim.split(out, "\n", { plain = true })) do
    local sha, orig = l:match "^(%x+) (%d+) %d+"
    if l:sub(1, 1) == "\t" then
      -- the line's content
    elseif sha and #sha == 40 then
      cur = commits[sha] or { sha = sha }
      commits[sha] = cur
      entries[#entries + 1] = { commit = cur, orig = tonumber(orig) }
    elseif cur then
      local key, val = l:match "^(%S+) ?(.*)$"
      if key == "author" then
        cur.author = val
      elseif key == "author-time" then
        cur.time = tonumber(val)
      elseif key == "summary" then
        cur.summary = val
      elseif key == "previous" then
        cur.prev_sha, cur.prev_path = val:match "^(%x+) (.+)$"
      elseif key == "filename" then
        cur.path = val
      end
    end
  end
  return entries, commits
end

local bodies = {} -- sha -> commit message body; commits never change, so this only grows

local function fetch_bodies(root, commits)
  local missing = {}
  for sha in pairs(commits) do
    if sha ~= UNCOMMITTED and not bodies[sha] then
      missing[#missing + 1] = sha
    end
  end
  if #missing == 0 then
    return
  end
  local out = git(root, vim.list_extend({ "log", "--no-walk=unsorted", "--format=%H%n%b%x00" }, missing)) or ""
  for record in out:gmatch "%s*(%x+\n[^%z]*)%z" do
    local sha, body = record:match "^(%x+)\n(.*)$"
    bodies[sha] = vim.trim(body)
  end
end

-- Layout -------------------------------------------------------------------------------------

local DATE_W = 10

local function width_of(s)
  return vim.fn.strdisplaywidth(s)
end

local function fit(s, w)
  if width_of(s) <= w then
    return s
  end
  return vim.fn.strcharpart(s, 0, math.max(w - 1, 0)) .. "…"
end

--- Word-wraps paragraphs ({text, hl}) into rows ({text, hl}), the first `first` wide, the rest `rest`.
local function flow(paras, first, rest)
  local rows = {}
  for _, p in ipairs(paras) do
    local cur = ""
    for word in p.text:gmatch "%S+" do
      local w = #rows == 0 and first or rest
      if cur ~= "" and width_of(cur .. " " .. word) > w then
        rows[#rows + 1] = { text = fit(cur, w), hl = p.hl }
        cur = word
      else
        cur = cur == "" and word or cur .. " " .. word
      end
    end
    if cur ~= "" then
      rows[#rows + 1] = { text = fit(cur, #rows == 0 and first or rest), hl = p.hl }
    end
  end
  return rows
end

local function paragraphs(c)
  local paras = { { text = c.summary or "", hl = nil } }
  for _, line in ipairs(vim.split(bodies[c.sha] or "", "\n", { plain = true })) do
    if vim.trim(line) ~= "" then
      paras[#paras + 1] = { text = line, hl = "Comment" }
    end
  end
  return paras
end

--- Lines and highlights for the panel, one row per entry.
local function layout(entries, commits, width)
  local author_w, age = 0, age_hls(commits)
  for _, e in ipairs(entries) do
    author_w = math.max(author_w, width_of(e.commit.author or ""))
  end
  author_w = math.min(author_w, 16)
  local col = 1 + DATE_W + 1 -- where the text column starts, after the bar and the date
  local text_w = width - col

  local lines, marks = {}, {}
  local function mark(row, start, text, hl)
    if hl and text ~= "" then
      marks[#marks + 1] = { row, start, start + #text, hl }
    end
  end

  local i = 1
  while i <= #entries do
    local c = entries[i].commit
    local n = 1
    while entries[i + n] and entries[i + n].commit == c do
      n = n + 1
    end

    if c.sha == UNCOMMITTED then
      for k = 0, n - 1 do
        local text = k == 0 and "not committed yet" or ""
        lines[i + k] = "▎" .. string.rep(" ", DATE_W + 1) .. text
        mark(i + k, 0, lines[i + k], "Comment")
      end
    else
      local bar = author_hl(c.author)
      local date = os.date("%Y-%m-%d", c.time)
      local author = fit(c.author, author_w)
      author = author .. string.rep(" ", author_w - width_of(author))
      local rows = flow(paragraphs(c), text_w - author_w - 1, text_w)
      if #rows > n then -- the block's last row takes as much of what is left as fits
        local rest = {}
        for k = n, #rows do
          rest[#rest + 1] = rows[k].text
        end
        rows[n].text = fit(table.concat(rest, " ") .. " ", n == 1 and text_w - author_w - 1 or text_w)
      end
      for k = 0, n - 1 do
        local row, r = i + k, rows[k + 1]
        local head = k == 0 and ("▎" .. date .. " " .. author .. " ") or ("▎" .. string.rep(" ", DATE_W + 1))
        lines[row] = head .. (r and r.text or "")
        mark(row, 0, "▎", bar)
        if k == 0 then
          mark(row, #"▎", date, age[c.sha])
          mark(row, #"▎" + #date + 1, author, bar)
        end
        if r then
          mark(row, #head, r.text, r.hl)
        end
      end
    end
    i = i + n
  end
  return lines, marks
end

-- The panel ----------------------------------------------------------------------------------

local state -- the open panel: code_win, panel_win, panel_buf, root, base_buf, saved, stack, entries

local function top()
  return state.stack[#state.stack]
end

local function winbar()
  local function key(k, label)
    return "%#Title#" .. k .. "%#Comment# " .. label .. "  "
  end
  local where = #state.stack > 1 and ("%#Comment#before " .. top().from:sub(1, 7) .. "  ") or ""
  return where
    .. key("K", "diff")
    .. key("s", "commit")
    .. key("r", "older")
    .. (#state.stack > 1 and key("⌫", "newer") or "")
    .. key("q", "close")
end

local function render()
  local frame = top()
  local out, err
  if frame.rev then
    out, err = git(state.root, { "blame", "--porcelain", frame.rev, "--", frame.path })
  else
    local text = table.concat(api.nvim_buf_get_lines(state.base_buf, 0, -1, false), "\n") .. "\n"
    out, err = git(state.root, { "blame", "--porcelain", "--contents", "-", "--", frame.path }, text)
  end
  if not out then
    vim.notify("blame: " .. err, vim.log.levels.ERROR)
    return false
  end
  local entries, commits = parse_porcelain(out)
  fetch_bodies(state.root, commits)
  state.entries = entries

  local lines, marks = layout(entries, commits, api.nvim_win_get_width(state.panel_win))
  local buf = state.panel_buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, ns, m[1] - 1, m[2], { end_col = m[3], hl_group = m[4] })
  end
  vim.wo[state.panel_win].winbar = winbar()
  return true
end

local function current_commit()
  local e = state.entries[api.nvim_win_get_cursor(state.panel_win)[1]]
  if not e or e.commit.sha == UNCOMMITTED then
    vim.notify("blame: this line is not committed yet", vim.log.levels.INFO)
    return nil
  end
  return e.commit, e
end

local function scratch(name, lines, ft)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_name(buf, name)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft
  return buf
end

--- Shows the stack's top in the code window, blames it, and puts both cursors on `lnum`.
local function show_top(lnum)
  state.shown = top().buf
  api.nvim_win_set_buf(state.code_win, top().buf)
  render()
  lnum = math.max(1, math.min(lnum, api.nvim_buf_line_count(top().buf)))
  api.nvim_win_set_cursor(state.code_win, { lnum, 0 })
  api.nvim_win_set_cursor(state.panel_win, { lnum, 0 })
end

local function older()
  local c, e = current_commit()
  if not c then
    return
  end
  if not c.prev_sha then
    vim.notify("blame: " .. c.sha:sub(1, 7) .. " added this line; there is nothing older", vim.log.levels.INFO)
    return
  end
  local out, err = git(state.root, { "show", c.prev_sha .. ":" .. c.prev_path })
  if not out then
    vim.notify("blame: " .. err, vim.log.levels.ERROR)
    return
  end
  local lines = vim.split(out:gsub("\n$", ""), "\n", { plain = true })
  local ft = vim.filetype.match { filename = c.prev_path } or ""
  local buf = scratch(("blame://%s/%s"):format(c.prev_sha:sub(1, 7), c.prev_path), lines, ft)
  top().lnum = api.nvim_win_get_cursor(state.panel_win)[1]
  table.insert(state.stack, { rev = c.prev_sha, path = c.prev_path, buf = buf, from = c.sha })
  show_top(e.orig)
end

local function newer()
  if #state.stack == 1 then
    return
  end
  local left = table.remove(state.stack)
  show_top(top().lnum)
  api.nvim_buf_delete(left.buf, { force = true })
end

local function show_commit(open)
  local c = current_commit()
  if not c then
    return
  end
  local out = git(state.root, { "show", "--stat", "--patch", "--format=fuller", c.sha }) or ""
  local buf = scratch("blame://commit/" .. c.sha:sub(1, 7), vim.split(out, "\n", { plain = true }), "git")
  vim.bo[buf].bufhidden = "wipe"
  api.nvim_set_current_win(state.code_win)
  vim.cmd(open)
  vim.wo.scrollbind, vim.wo.cursorbind = false, false -- a split inherits the code window's binding
  api.nvim_win_set_buf(0, buf)
end

local function diff_popup()
  local c = current_commit()
  if not c then
    return
  end
  local out = git(state.root, { "show", "--date=short", "--format=%h  %an  %ad%n%n%B", c.sha, "--", c.path }) or ""
  vim.lsp.util.open_floating_preview(vim.split(vim.trim(out), "\n", { plain = true }), "git", {
    border = "rounded",
    focus_id = "blame-diff",
    max_width = math.floor(vim.o.columns * 0.6),
    max_height = math.floor(vim.o.lines * 0.7),
  })
end

function M.close()
  if not state then
    return
  end
  local s = state
  state = nil
  if api.nvim_win_is_valid(s.code_win) then
    if api.nvim_win_get_buf(s.code_win) ~= s.base_buf and api.nvim_buf_is_valid(s.base_buf) then
      api.nvim_win_set_buf(s.code_win, s.base_buf)
    end
    for opt, val in pairs(s.saved) do
      vim.wo[s.code_win][opt] = val
    end
  end
  for k = 2, #s.stack do
    if api.nvim_buf_is_valid(s.stack[k].buf) then
      api.nvim_buf_delete(s.stack[k].buf, { force = true })
    end
  end
  pcall(api.nvim_del_augroup_by_name, "blame-panel")
  if api.nvim_win_is_valid(s.panel_win) then
    api.nvim_win_close(s.panel_win, true)
  end
end

function M.open()
  local code_win, base_buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local file = vim.fn.resolve(api.nvim_buf_get_name(base_buf))
  local root = file ~= "" and git(vim.fn.fnamemodify(file, ":h"), { "rev-parse", "--show-toplevel" })
  if not root then
    vim.notify("blame: not a file in a git repository", vim.log.levels.WARN)
    return
  end
  root = vim.trim(root)

  local saved = {}
  for _, opt in ipairs { "scrollbind", "cursorbind", "foldenable", "wrap" } do
    saved[opt] = vim.wo[code_win][opt]
  end
  local width = math.max(40, math.min(70, math.floor(vim.o.columns * 0.3)))
  vim.cmd(("aboveleft %dvsplit"):format(width))
  local panel_win, panel_buf = api.nvim_get_current_win(), api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(panel_win, panel_buf)
  api.nvim_buf_set_name(panel_buf, "blame://" .. vim.fn.fnamemodify(file, ":t"))
  vim.bo[panel_buf].filetype = "blame"
  vim.bo[panel_buf].bufhidden = "wipe"
  local wo = vim.wo[panel_win][0]
  wo.number, wo.relativenumber, wo.signcolumn, wo.foldcolumn = false, false, "no", "0"
  wo.wrap, wo.list, wo.spell, wo.winfixwidth, wo.cursorline = false, false, false, true, true

  state = {
    code_win = code_win, panel_win = panel_win, panel_buf = panel_buf, root = root,
    base_buf = base_buf, shown = base_buf, saved = saved,
    stack = { { path = file:sub(#vim.fn.resolve(root) + 2), buf = base_buf } },
  }
  if not render() then
    return M.close()
  end

  local lnum = api.nvim_win_get_cursor(code_win)[1]
  api.nvim_win_set_cursor(panel_win, { lnum, 0 })
  for _, win in ipairs { code_win, panel_win } do
    vim.wo[win].foldenable, vim.wo[win].wrap = false, false
    vim.wo[win].scrollbind, vim.wo[win].cursorbind = true, true
  end
  vim.cmd "syncbind"

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = panel_buf, nowait = true, desc = desc })
  end
  map("q", M.close, "Close blame")
  map("K", diff_popup, "This commit's message and its change to this file")
  map("s", function() show_commit "vsplit" end, "Show commit in a split")
  map("S", function() show_commit "tabnew" end, "Show commit in a tab")
  map("r", older, "Blame the file as it was before this commit")
  map("<BS>", newer, "Back to the newer blame")

  local group = api.nvim_create_augroup("blame-panel", { clear = true })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(code_win), tostring(panel_win) },
    callback = function() vim.schedule(M.close) end,
  })
  api.nvim_create_autocmd("BufWinEnter", { -- another buffer in the code window ends the blame
    group = group,
    callback = function()
      if state and api.nvim_win_is_valid(state.code_win) and api.nvim_win_get_buf(state.code_win) ~= state.shown then
        vim.schedule(M.close)
      end
    end,
  })
  api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = group,
    buffer = base_buf,
    callback = function()
      if state and #state.stack == 1 then
        render()
      end
    end,
  })
end

function M.toggle()
  if state then
    M.close()
  else
    M.open()
  end
end

return M
