# What every bash test file shares, sourced near its top. What the runner makes of the exit code and the skip lines:
# the Makefile's header.

# How many checks have failed so far, for a file that prints more on a failure before it calls finish.
failures=0

check() {
    local what="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        passed "$what"
    else
        fail "$what" "expected: $expected
actual:   $actual"
    fi
}

passed() {
    echo "ok   $1"
}

# One case this host cannot check, while the rest of the file runs: skipped <what> <why>.
skipped() {
    echo "skip $1: $2"
}

# A check that failed for the reason given, for one that is not a comparison of two values.
fail() {
    echo "FAIL $1"
    [ -z "${2:-}" ] || sed 's/^/       /' <<<"$2"
    failures=$((failures + 1))
}

# Before any check runs: a skip after a failure would hide it.
skip() {
    echo "skip: $*"
    exit 77
}

# Skips the file unless every tool named is on PATH.
needs() {
    local tool
    for tool; do
        command -v "$tool" >/dev/null || skip "$tool is not on PATH"
    done
}

finish() {
    echo
    if [ "$failures" -eq 0 ]; then
        echo "all checks passed"
        exit 0
    fi
    echo "$failures check(s) failed"
    exit 1
}
