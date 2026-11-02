-- Whole-file git blame: a panel left of the code, scrolling and moving its cursor with it, and a
-- detail pane across the bottom that shows the line under the cursor and follows it.
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
-- The pane shows the line's change (its commit, message, and the hunk that touched the line) or
-- its history (every commit that changed it, `git log -L`, newest first, each with the line
-- before and after, ending where it was first written).
--
-- Follow mode is that pane without the view, for any file: a card beside the code that shows
-- the line's change and follows the cursor.

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

--- A commit trailer (Co-Authored-By:, Signed-off-by:, …): bookkeeping, not part of the message.
local function is_trailer(line)
  return line:match "^%a+%-[%w-]+: " ~= nil
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
    if vim.trim(line) ~= "" and not is_trailer(line) then
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

-- Blame of a buffer ---------------------------------------------------------------------------

local function notify(msg, level)
  vim.notify("blame: " .. msg, level or vim.log.levels.INFO)
end

--- The repository root and the buffer's path in it, or nil for a buffer that is no file in git.
local function locate(buf)
  local file = vim.bo[buf].buftype == "" and vim.fn.resolve(api.nvim_buf_get_name(buf)) or ""
  local root = file ~= "" and git(vim.fn.fnamemodify(file, ":h"), { "rev-parse", "--show-toplevel" })
  if not root then
    return nil
  end
  root = vim.fn.resolve(vim.trim(root))
  return root, file:sub(#root + 2)
end

local blames = {} -- buf -> the blame of its text at changedtick `tick`, or its error

--- The blame of the buffer's current text (unsaved edits are "not committed yet"), or nil.
local function blame_buffer(buf, loud)
  local tick = api.nvim_buf_get_changedtick(buf)
  local b = blames[buf]
  if not (b and b.tick == tick) then
    b = { tick = tick }
    blames[buf] = b
    local root, path = locate(buf)
    if not root then
      b.err = "not a file in a git repository"
    else
      local text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
      local out, err = git(root, { "blame", "--porcelain", "--contents", "-", "--", path }, text)
      if out then
        b.entries, b.commits = parse_porcelain(out)
        b.root, b.path = root, path
      else
        b.err = err
      end
    end
  end
  if b.err then
    if loud then
      notify(b.err, vim.log.levels.WARN)
    end
    return nil
  end
  return b
end

api.nvim_create_autocmd("BufWipeout", {
  group = api.nvim_create_augroup("blame-cache", { clear = true }),
  callback = function(ev) blames[ev.buf] = nil end,
})

-- The line's commit and change ----------------------------------------------------------------

local cards = {} -- "sha:path" -> { head = header and message lines, hunks = this file's hunks }

local function commit_card(root, c)
  local key = c.sha .. ":" .. c.path
  if not cards[key] then
    local out = git(root, { "show", "--date=short", "--format=%h  %an  %ad%n%n%B", "-U3", c.sha, "--", c.path }) or ""
    local card, hunk, in_diff = { head = {}, hunks = {} }, nil, false
    for _, l in ipairs(vim.split(out, "\n", { plain = true })) do
      local start, count = l:match "^@@ %-%S+ %+(%d+),?(%d*) @@"
      if start then
        hunk = { start = tonumber(start), count = count == "" and 1 or tonumber(count), lines = { l } }
        card.hunks[#card.hunks + 1] = hunk
      elseif hunk then
        hunk.lines[#hunk.lines + 1] = l
      elseif l:match "^diff %-%-git " then
        in_diff = true
      elseif not in_diff and not is_trailer(l) then
        card.head[#card.head + 1] = l
      end
    end
    for _, lines in ipairs(vim.list_extend({ card.head }, vim.tbl_map(function(h) return h.lines end, card.hunks))) do
      while lines[#lines] == "" do
        table.remove(lines)
      end
    end
    cards[key] = card
  end
  return cards[key]
end

--- The card for one blame entry: commit, message, and the hunk that touched the line. The
--- second value names what the card shows, so a caller can tell when it changes.
local function line_card(root, e)
  local c = e.commit
  if c.sha == UNCOMMITTED then
    return { "not committed yet" }, "uncommitted"
  end
  local card = commit_card(root, c)
  local lines = vim.list_extend({}, card.head)
  for i, h in ipairs(card.hunks) do
    if e.orig >= h.start and e.orig < h.start + math.max(h.count, 1) then
      lines[#lines + 1] = ""
      return vim.list_extend(lines, h.lines), c.sha .. ":" .. i
    end
  end
  return lines, c.sha
end

-- Line history --------------------------------------------------------------------------------

local HISTORY_LINES = 3 -- removed and added lines shown per commit; the rest are counted

--- The commits of `git log -L` output, newest first, each with the lines its change removed (-)
--- and added (+) in the range.
local function parse_line_log(out)
  local commits, cur, in_hunk = {}, nil, false
  for _, l in ipairs(vim.split(out, "\n", { plain = true })) do
    if l:sub(1, 1) == "\1" then
      local f = vim.split(l:sub(2), "\0", { plain = true })
      cur = { sha = f[1], author = f[2], time = tonumber(f[3]), summary = f[4], changes = {} }
      commits[#commits + 1] = cur
      in_hunk = false
    elseif l:match "^diff %-%-git " then
      in_hunk = false
    elseif l:match "^@@ " then
      in_hunk = true
    elseif cur and in_hunk and l:match "^[+-]" then
      cur.changes[#cur.changes + 1] = l
    end
  end
  -- A change that removes nothing wrote the line; git goes on tracing the range into the lines
  -- that stood near it before, which are another line's history.
  for i, c in ipairs(commits) do
    if #vim.tbl_filter(function(l) return l:sub(1, 1) == "-" end, c.changes) == 0 then
      c.born = true
      return vim.list_slice(commits, 1, i)
    end
  end
  return commits
end

--- The timeline's lines, highlights, and the commit each row belongs to.
local function history_layout(commits)
  local lines, marks, shas = {}, {}, {}
  local age = age_hls(commits)
  local function add(text, sha)
    lines[#lines + 1] = text
    shas[#lines] = sha
    return #lines
  end
  for _, c in ipairs(commits) do
    local date = os.date("%Y-%m-%d", c.time)
    local head = date .. "  " .. c.author .. "  " .. c.summary
    local row = add(head .. (c.born and "  (first written here)" or ""), c.sha)
    marks[#marks + 1] = { row, 0, #date, age[c.sha] }
    marks[#marks + 1] = { row, #date + 2, #date + 2 + #c.author, author_hl(c.author) }
    if c.born then
      marks[#marks + 1] = { row, #head, #lines[row], "Comment" }
    end
    for _, sign in ipairs { "-", "+" } do
      local side = vim.tbl_filter(function(l) return l:sub(1, 1) == sign end, c.changes)
      local shown = #side > HISTORY_LINES + 1 and HISTORY_LINES or #side
      for k = 1, shown do
        row = add("    " .. side[k], c.sha)
        marks[#marks + 1] = { row, 4, #lines[row], sign == "+" and "Added" or "Removed" }
      end
      if shown < #side then
        row = add(("    %s … %d more %s"):format(sign, #side - shown, sign == "+" and "added" or "removed"), c.sha)
        marks[#marks + 1] = { row, 4, #lines[row], "Comment" }
      end
    end
    add("", nil)
  end
  return lines, marks, shas
end

local histories = {} -- "sha:path:line" -> the line's commits, or { err = … }; history never changes
local fetching -- the one `git log -L` in flight: key and process

--- The history of the entry's line if it is known; otherwise starts reading it, calls `done`
--- once it is in, and returns nil. A newer request stops the one before.
local function line_history(root, e, done)
  local c = e.commit
  local key = table.concat({ c.sha, c.path, e.orig }, ":")
  if histories[key] then
    return histories[key]
  end
  if fetching and fetching.key == key then
    return nil
  end
  if fetching then
    fetching.proc:kill "sigterm"
  end
  local range = ("-L%d,%d:%s"):format(e.orig, e.orig, c.path)
  local cmd = { "git", "-C", root, "log", "--format=%x01%H%x00%an%x00%at%x00%s", range, c.sha }
  local this = { key = key }
  this.proc = vim.system(cmd, { text = true }, function(r)
    vim.schedule(function()
      if fetching == this then
        fetching = nil
      end
      if r.signal ~= 0 then -- stopped for a newer request, which brings its own `done`
        return
      end
      histories[key] = r.code == 0 and parse_line_log(r.stdout) or { err = vim.trim(r.stderr) }
      done()
    end)
  end)
  fetching = this
  return nil
end

-- The blame view ------------------------------------------------------------------------------
--
-- Three windows: the panel left of the code, scroll- and cursor-bound to it, and the detail
-- pane across the bottom of both. Every key works from the panel, so browsing never needs
-- another window; the code window gets <C-j>/<C-k> too.

local state -- the open view: windows, buffers, the blame, `view` (change|history), what the pane shows
local follow -- while follow mode is on: buf, and win and key while its card shows

--- The blame entry under the cursor of `win`, and the blame it is from.
local function entry_at(win, loud)
  local b = (state and win == state.panel_win) and state.blame or blame_buffer(api.nvim_win_get_buf(win), loud)
  if not b then
    return nil
  end
  return b.entries[api.nvim_win_get_cursor(win)[1]], b
end

local function keyhint(k, label)
  return "%#Title#" .. k .. "%#Comment# " .. label .. "  "
end

local function panel_winbar()
  return keyhint("h", state.view == "history" and "change" or "history") .. keyhint("s", "commit")
    .. keyhint("S", "in tab") .. keyhint("^j ^k", "scroll") .. keyhint("q", "close")
end

local function render_panel()
  local b = blame_buffer(state.base_buf, true)
  if not b then
    return false
  end
  fetch_bodies(b.root, b.commits)
  state.blame = b

  local lines, marks = layout(b.entries, b.commits, api.nvim_win_get_width(state.panel_win))
  local buf = state.panel_buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, ns, m[1] - 1, m[2], { end_col = m[3], hl_group = m[4] })
  end
  vim.wo[state.panel_win].winbar = panel_winbar()
  return true
end

--- The line under the cursor, read from the panel when it has the cursor, else from the code.
local function cursor_line()
  local here = api.nvim_get_current_win() == state.panel_win and state.panel_win or state.code_win
  return api.nvim_win_get_cursor(here)[1]
end

--- Puts a view into the detail pane, unless it already shows the one named `key`.
local function pane_set(key, title, lines, marks, ft)
  if state.shown == key then
    return
  end
  state.shown = key
  local buf = state.detail_buf
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    api.nvim_buf_set_extmark(buf, ns, m[1] - 1, m[2], { end_col = m[3], hl_group = m[4] })
  end
  vim.wo[state.detail_win].winbar = "%#Title#" .. title:gsub("%%", "%%%%")
  api.nvim_win_set_cursor(state.detail_win, { 1, 0 })
end

--- Shows the line under the cursor in the detail pane: its change or its history, or the
--- commit pinned there while the cursor stays on that commit's lines.
local function pane_update()
  if not state then
    return
  end
  local lnum = cursor_line()
  local e = state.blame.entries[lnum]
  if not e then
    return
  end
  local c = e.commit
  if state.pinned then
    if lnum == state.pinned.lnum or c.sha == state.pinned.sha then
      return
    end
    state.pinned = nil
  end
  if c.sha == UNCOMMITTED then
    return pane_set("uncommitted", "line " .. lnum, { "not committed yet" }, {}, "git")
  end
  if state.view == "change" then
    local lines, key = line_card(state.blame.root, e)
    return pane_set("change:" .. key, "the change to line " .. lnum, lines, {}, "git")
  end
  local key = table.concat({ "history", c.sha, e.orig }, ":")
  local text = vim.trim(api.nvim_buf_get_lines(state.base_buf, lnum - 1, lnum, false)[1] or "")
  local title = "history of line " .. lnum .. ":  " .. text
  local commits = line_history(state.blame.root, e, pane_update)
  if not commits then
    return pane_set(key .. ":reading", title, { "reading the history…" }, {}, "blame-history")
  elseif commits.err then
    return pane_set(key, title, { commits.err }, {}, "blame-history")
  end
  local lines, marks, shas = history_layout(commits)
  state.history_shas = shas
  pane_set(key, title, lines, marks, "blame-history")
end

--- Pins commit `sha`, all of it, in the detail pane until the cursor leaves its lines.
local function pin(sha)
  local out = git(state.blame.root, { "show", "--stat", "--patch", "--format=fuller", sha }) or ""
  state.pinned = { sha = sha, lnum = cursor_line() }
  pane_set("commit:" .. sha, "commit " .. sha:sub(1, 7) .. "   ⌫ back", vim.split(out, "\n", { plain = true }), {}, "git")
end

--- The commit to pin: in the history, the entry under the pane's cursor; else the line's.
local function commit_to_show()
  if api.nvim_get_current_win() == state.detail_win and state.view == "history" and not state.pinned then
    return state.history_shas and state.history_shas[api.nvim_win_get_cursor(state.detail_win)[1]]
  end
  local e = state.blame.entries[cursor_line()]
  if not e or e.commit.sha == UNCOMMITTED then
    return notify "this line is not committed yet"
  end
  return e.commit.sha
end

local function show_commit()
  local sha = commit_to_show()
  if sha then
    pin(sha)
  end
end

local function show_commit_in_tab()
  local sha = commit_to_show()
  if not sha then
    return
  end
  local out = git(state.blame.root, { "show", "--stat", "--patch", "--format=fuller", sha }) or ""
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(out, "\n", { plain = true }))
  pcall(api.nvim_buf_set_name, buf, "blame://commit/" .. sha:sub(1, 7)) -- a second copy keeps no name
  vim.bo[buf].modifiable, vim.bo[buf].filetype, vim.bo[buf].bufhidden = false, "git", "wipe"
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, nowait = true, desc = "Close" })
  vim.cmd "tabnew"
  api.nvim_win_set_buf(0, buf)
end

local function back()
  state.pinned, state.shown = nil, nil
  pane_update()
end

local function switch_view()
  state.view = state.view == "change" and "history" or "change"
  back()
  vim.wo[state.panel_win].winbar = panel_winbar()
end

local function pane_scroll(keys)
  return function()
    api.nvim_win_call(state.detail_win, function() vim.cmd("normal! " .. vim.keycode(keys)) end)
  end
end

-- Follow mode --------------------------------------------------------------------------------

local function follow_hide()
  if follow.win and api.nvim_win_is_valid(follow.win) then
    api.nvim_win_close(follow.win, true)
  end
  follow.win = nil
end

--- Shows the card of the line under the cursor at the side of the window, away from the cursor.
local function follow_update()
  local win = api.nvim_get_current_win()
  if not follow or api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  if state and vim.tbl_contains({ state.code_win, state.panel_win, state.detail_win }, win) then
    return follow_hide() -- the blame view's own pane shows the line already
  end
  local e, b = entry_at(win)
  if not e then
    return follow_hide()
  end
  local lines, key = line_card(b.root, e)
  if key ~= follow.key then
    vim.bo[follow.buf].modifiable = true
    api.nvim_buf_set_lines(follow.buf, 0, -1, false, lines)
    vim.bo[follow.buf].modifiable = false
  end

  local ww, wh = api.nvim_win_get_width(win), api.nvim_win_get_height(win)
  local widest = 0
  for _, l in ipairs(lines) do
    widest = math.max(widest, vim.fn.strdisplaywidth(l))
  end
  local width = math.max(1, math.min(widest, math.floor(ww * 0.5)))
  local rows = 0 -- the card wraps, so a line wider than it takes several rows
  for _, l in ipairs(lines) do
    rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
  end
  local height = math.max(1, math.min(rows, math.floor(wh * 0.5)))
  local low = vim.fn.winline() > wh / 2 -- the cursor is in the lower half, so the card goes up top
  local cfg = {
    relative = "win", win = win, anchor = low and "NE" or "SE", row = low and 0 or wh, col = ww,
    width = width, height = height, border = "rounded",
    footer = rows > height and { { " ^j ^k scroll ", "Comment" } } or "", footer_pos = "right",
  }
  if follow.win and api.nvim_win_is_valid(follow.win) then
    api.nvim_win_set_config(follow.win, cfg)
  else
    cfg.style, cfg.focusable, cfg.zindex = "minimal", false, 40
    follow.win = api.nvim_open_win(follow.buf, false, cfg)
    vim.wo[follow.win].wrap = true
  end
  if key ~= follow.key then
    api.nvim_win_set_cursor(follow.win, { 1, 0 })
    follow.key = key
  end
end

--- Scrolls the card by `keys` (half a page down or up), from whichever window has the cursor.
local function card_scroll(keys)
  return function()
    if follow and follow.win and api.nvim_win_is_valid(follow.win) then
      api.nvim_win_call(follow.win, function() vim.cmd("normal! " .. vim.keycode(keys)) end)
    end
  end
end

function M.follow()
  if follow then
    pcall(vim.keymap.del, "n", "<C-j>")
    pcall(vim.keymap.del, "n", "<C-k>")
    follow_hide()
    api.nvim_del_augroup_by_name "blame-follow"
    api.nvim_buf_delete(follow.buf, { force = true })
    follow = nil
  else
    follow = { buf = api.nvim_create_buf(false, true) }
    vim.bo[follow.buf].filetype = "git"
    local group = api.nvim_create_augroup("blame-follow", { clear = true })
    api.nvim_create_autocmd({ "CursorMoved", "WinEnter", "BufEnter", "InsertLeave", "WinResized" }, {
      group = group,
      callback = function() vim.schedule(follow_update) end,
    })
    api.nvim_create_autocmd("InsertEnter", { group = group, callback = follow_hide })
    vim.keymap.set("n", "<C-j>", card_scroll "<C-d>", { desc = "Scroll the blame card down" })
    vim.keymap.set("n", "<C-k>", card_scroll "<C-u>", { desc = "Scroll the blame card up" })
    follow_update()
  end
end

-- Opening and closing the view ---------------------------------------------------------------

function M.close()
  if not state then
    return
  end
  local s = state
  state = nil
  if fetching then
    fetching.proc:kill "sigterm"
  end
  pcall(api.nvim_del_augroup_by_name, "blame-view")
  if api.nvim_win_is_valid(s.code_win) then
    for opt, val in pairs(s.saved) do
      vim.wo[s.code_win][opt] = val
    end
  end
  if api.nvim_buf_is_valid(s.base_buf) then
    pcall(vim.keymap.del, "n", "<C-j>", { buffer = s.base_buf })
    pcall(vim.keymap.del, "n", "<C-k>", { buffer = s.base_buf })
  end
  for _, win in ipairs { s.panel_win, s.detail_win } do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
end

--- Opens the blame view on the current window's file, its pane on `view` (default "change").
function M.open(view)
  local code_win, base_buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  if not blame_buffer(base_buf, true) then
    return
  end
  local saved = {}
  for _, opt in ipairs { "scrollbind", "cursorbind", "foldenable", "wrap" } do
    saved[opt] = vim.wo[code_win][opt]
  end
  local lnum = api.nvim_win_get_cursor(code_win)[1]

  -- The pane goes in first, across the whole bottom, so the panel and the code above it are one
  -- height and their rows stay level.
  local detail_buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, detail_buf, "blame://line")
  vim.bo[detail_buf].bufhidden = "wipe"
  local detail_win = api.nvim_open_win(detail_buf, false, {
    split = "below", win = -1, height = math.max(8, math.floor(vim.o.lines * 0.35)),
  })
  local panel_buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, panel_buf, "blame://" .. vim.fn.fnamemodify(api.nvim_buf_get_name(base_buf), ":t"))
  vim.bo[panel_buf].filetype = "blame"
  vim.bo[panel_buf].bufhidden = "wipe"
  local panel_win = api.nvim_open_win(panel_buf, true, {
    split = "left", win = code_win, width = math.max(40, math.min(70, math.floor(vim.o.columns * 0.3))),
  })
  for win, fixed in pairs { [panel_win] = "winfixwidth", [detail_win] = "winfixheight" } do
    local wo = vim.wo[win][0]
    wo.number, wo.relativenumber, wo.signcolumn, wo.foldcolumn = false, false, "no", "0"
    wo.wrap, wo.list, wo.spell, wo[fixed] = false, false, false, true
  end
  vim.wo[panel_win][0].cursorline = true

  state = {
    code_win = code_win, panel_win = panel_win, detail_win = detail_win, base_buf = base_buf,
    panel_buf = panel_buf, detail_buf = detail_buf, saved = saved, view = view or "change",
  }
  if not render_panel() then
    return M.close()
  end
  api.nvim_win_set_cursor(panel_win, { lnum, 0 })
  for _, win in ipairs { code_win, panel_win } do
    vim.wo[win].foldenable, vim.wo[win].wrap = false, false
    vim.wo[win].scrollbind, vim.wo[win].cursorbind = true, true
  end
  vim.cmd "syncbind"

  for _, buf in ipairs { panel_buf, detail_buf } do
    local function map(lhs, fn, desc)
      vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
    end
    map("q", M.close, "Close blame")
    map("h", switch_view, "Switch the pane between the line's change and its history")
    map("s", show_commit, "Show the whole commit in the pane")
    map("<CR>", show_commit, "Show the whole commit in the pane")
    map("S", show_commit_in_tab, "Show the whole commit in a tab")
    map("<BS>", back, "Back to the line under the cursor")
  end
  for _, buf in ipairs { panel_buf, base_buf } do
    vim.keymap.set("n", "<C-j>", pane_scroll "<C-d>", { buffer = buf, desc = "Scroll the blame pane down" })
    vim.keymap.set("n", "<C-k>", pane_scroll "<C-u>", { buffer = buf, desc = "Scroll the blame pane up" })
  end

  local group = api.nvim_create_augroup("blame-view", { clear = true })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(code_win), tostring(panel_win), tostring(detail_win) },
    callback = function() vim.schedule(M.close) end,
  })
  api.nvim_create_autocmd("BufWinEnter", { -- another buffer in the code window ends the view
    group = group,
    callback = function()
      if state and api.nvim_win_is_valid(state.code_win) and api.nvim_win_get_buf(state.code_win) ~= state.base_buf then
        vim.schedule(M.close)
      end
    end,
  })
  api.nvim_create_autocmd("CursorMoved", { group = group, buffer = panel_buf, callback = pane_update })
  api.nvim_create_autocmd("CursorMoved", { group = group, buffer = base_buf, callback = pane_update })
  api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = group,
    buffer = base_buf,
    callback = function()
      if state and render_panel() then
        state.shown = nil
        pane_update()
      end
    end,
  })
  pane_update()
end

function M.toggle()
  if state then
    M.close()
  else
    M.open()
  end
end

--- The line's history: the blame view with its pane on the history, opened if it is not.
function M.history()
  if not state then
    return M.open "history"
  end
  if state.view ~= "history" then
    switch_view()
  end
end

return M
