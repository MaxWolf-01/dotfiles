# What every bash test file shares, sourced near its top. The runner reads only the exit code:
# 0 passed, 77 skipped (the line `skip` printed is the reason it names), anything else failed.

failures=0

check() {
    local what="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "ok   $what"
    else
        echo "FAIL $what"
        echo "       expected: $expected"
        echo "       actual:   $actual"
        failures=$((failures + 1))
    fi
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
