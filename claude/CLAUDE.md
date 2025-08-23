
Code Comments:
- don't add superfluous code comments.
- don't explain your changes with code comments. Explain them BEFORE using the Update/Edit tool.

Git:
- use commands like `git mv` instead of just `mv` to rename files, where possible

Python:
- Before running python commands in a project, you will need to `source .venv/bin/activate` to activate the virtual environment. It's always that same command.
- For conveniently running scripts (without creating a venv, etc.), see: `$HOME/Documents/external-docs/uv-v0.7.13/docs/guides/scripts.md`

Python Debugging Tools:
- ipdb is installed as a uv tool (command: `ipdb3`)
- Use `breakpoint()` in code to drop into ipdb debugger (PYTHONBREAKPOINT=ipdb.set_trace is set)
- Run scripts with `ipdb3 script.py` to start in debugger
- Run scripts with `uv run python -i script.py` for interactive mode after execution
- Rich tracebacks auto-enable in interactive/REPL mode when rich is available (via PYTHONSTARTUP=~/.pythonrc)
- For debugging I should:
  - Use `ipdb3` not `python -m ipdb` (it's a uv tool, not in the venv)
  - Use `uv run` for all Python execution (no system Python)
  - Add `--with rich` to uv run for beautiful tracebacks: `uv run --with rich python script.py`
- Note: Rich shows local variables in tracebacks, making debugging much easier!

