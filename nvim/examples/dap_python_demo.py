"""
Small Python program to try nvim-dap + debugpy.

How to run (two options)
- Launch in Neovim (uses dap-python + uv or your active .venv):
  1) Open this file in Neovim
  2) Set a breakpoint on a BREAK line: <leader>db
  3) Start: <leader>dc, pick "Python: Current File"

- Attach to a running process (uses debug script; see zsh/plugin-files/debugpy.zsh):
  1) Terminal: debug nvim/examples/dap_python_demo.py
     - Waits for the debugger
     - You can also do "MYVAR=1 debug uv run file.py --myflag"
  2) Neovim: set a breakpoint <leader>db, then attach: <leader>da

Inspect and navigate
- Hover/eval: <leader>de on a variable or selection (but variables values are shown automatically)
- Variables: <leader>dtv; Frames: <leader>dtf; UI panels: <leader>du
- Step: <leader>dn (over), <leader>di (into), <leader>do (out), continue: <leader>dc

Notes
- Log point (<leader>dl): breakpoint that logs a message without stopping
"""

import time


def fib(n: int) -> int:
    a, b = 0, 1
    for i in range(n):
        a, b = b, a + b  # BREAK: watch a/b change each iteration
    return a


def buggy_div(x: int, y: int) -> float:
    z = x / y  # BREAK: step in; try y=0 later to see exception reason
    return z


def greet(name: str) -> str:
    msg = f"Hello, {name}!"  # BREAK: inspect msg in variables/hover
    return msg


def main() -> None:
    name = "Max"
    print(greet(name))

    n = 10
    f = fib(n)
    print("fib", n, "=", f)

    try:
        buggy_div(42, 2)
        buggy_div(1, 0)  # triggers ZeroDivisionError (see stop reason)
    except Exception as e:
        print("caught:", e)

    time.sleep(0.2)  # BREAK: try stepping over/into from here


if __name__ == "__main__":
    main()
