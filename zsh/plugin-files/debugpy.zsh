# debugpy helpers for Python via uv
# Usage examples:
#   debug script.py --flag         # run a script under debugpy
#   debug -m package.module --opt  # run a module under debugpy
#   debug uv run script.py --flag  # also works if you include 'uv run'
#   DEBUGPY_PORT=5680 debug script.py  # override port
#   DEBUGPY_HOST=0.0.0.0 debug -m mypkg.cli

debug() {
  local host="${DEBUGPY_HOST:-127.0.0.1}"
  local port="${DEBUGPY_PORT:-5678}"
  local waitflag="--wait-for-client"

  if [[ $# -eq 0 ]]; then
    echo "usage: debug <script.py| -m module | uv run [<script.py>|-m module]> [args...]" >&2
    return 2
  fi

  # uv path is required since there's no global python
  if [[ "$1" == "uv" && "$2" == "run" ]]; then
    shift 2
  fi

  if [[ "$1" == "-m" ]]; then
    shift
    if [[ -z "$1" ]]; then
      echo "debug: missing module name after -m" >&2
      return 2
    fi
    local module="$1"; shift
    uv run --with debugpy -- python -X frozen_modules=off -m debugpy --listen "${host}:${port}" ${waitflag} --module "${module}" "$@"
  else
    local script="$1"; shift
    uv run --with debugpy -- python -X frozen_modules=off -m debugpy --listen "${host}:${port}" ${waitflag} "${script}" "$@"
  fi
}

# Shorthand to run a module under debugpy
debugm() { debug -m "$@"; }

# Short alias
alias dbg=debug
