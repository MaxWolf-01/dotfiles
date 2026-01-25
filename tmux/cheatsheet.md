# Tmux Cheatsheet

Prefix: **Ctrl+a** (press, release, then next key)

## Panes

| Key | Action |
|-----|--------|
| `Alt+qweasdf` | Switch to pane 1-7 (no prefix!) |
| `\|` | Split vertical (side by side) |
| `-` | Split horizontal (stacked) |
| `h/j/k/l` | Navigate panes |
| `H/J/K/L` | Resize panes |
| `z` | Zoom/unzoom (fullscreen toggle) |
| `x` | Kill pane |

## Windows (tabs)

| Key | Action |
|-----|--------|
| `Alt+1-4` | Switch to window 1-4 (no prefix!) |
| `c` | New window |
| `n/p` | Next/prev window |
| `,` | Rename window |
| `&` | Kill window |
| `Ctrl+Shift+←/→` | Swap window position (no prefix!) |

## Sessions

| Key | Action |
|-----|--------|
| `f` | fzf session picker |
| `s` | Built-in session list |
| `S` | Create new session |
| `$` | Rename current session |
| `d` | Detach (session keeps running) |

**From terminal:**
```bash
tms name                     # Attach or create session
tmux ls                      # List all sessions
tmux kill-session -t name    # Delete a session
tmux rename -t old new       # Rename a session
tmux switch-client -t name   # Switch session (from inside tmux)
```

## Copy Mode

| Key | Action |
|-----|--------|
| `v` | Enter copy mode |
| `/` | Enter copy mode + search |
| *in copy mode:* | |
| `v` | Start selection |
| `y` | Yank to clipboard |
| `n/N` | Next/prev search match |
| `q` | Exit copy mode |

**Tip:** Hold `Shift` while selecting to use terminal's native clipboard.

## Persistence

Sessions auto-save every 1min. After reboot, just run `tmux`.

| Key | Action |
|-----|--------|
| `Ctrl+s` | Save (no prefix needed!) |
| `C-r` | Manual restore (needs prefix) |

**Saves:** window/pane layout, working directories, pane contents
**Doesn't save:** running processes (but shows which dir they were in)

## Misc

| Key | Action |
|-----|--------|
| `r` | Reload config |
| `Ctrl+q` | Beginning of line (since Ctrl+a is prefix) |
| `Ctrl+a Ctrl+a` | Beginning of line (keep Ctrl held!) |

---

## tmux-dev Layout

`tmux-dev sessionname` creates:
- **Alt+1** dev: single pane (customize per project)
- **Alt+2** farm: 5 equal columns
- **Alt+3** dev2: btop | nvim+terminal | claude | claude
- **Alt+4** farm2: 5 equal columns

## Typical Workflow

1. **Start project:** `tmux-dev myproject`
2. **Work...** switch panes with `Alt+qweasdf`, windows with `Alt+1-4`
3. **Save before leaving:** `Ctrl+s`
4. **Detach:** `Ctrl+a d`
5. **Come back:** `tms myproject` or `Ctrl+a f`
6. **Switch sessions (inside tmux):** `Ctrl+a f` or `Ctrl+a s`
7. **After crash/reboot:** just `tmux` (auto-restores)
8. **Done with project:** `tmux kill-session -t myproject`
