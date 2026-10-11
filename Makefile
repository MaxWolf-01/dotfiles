# Run inside the devShell, which carries the tools the tests need: `nix develop -c make test`.
#
# Every *.test file names its tier on a line of its own near its top, which is where these targets read it:
#   # tier: fast                          nothing outside the checkout and a scratch directory:
#                                         no browser, desktop, tmux, systemd, network or sleeps
#   # tier: full-path (what it drives)    the real thing, end to end
# `make test` runs the fast files, `make test-full-path` the rest, and both refuse a file that names neither.
# A file exits 77 to skip, after a line `skip: <why>`; one that skips only some of its cases prints a line
# `skip <what>: <why>` for each and passes. The run ends by naming every skip, whole or in part, and every failure.

SHELL := bash

# Every *.test file in the repo, less one deleted but not yet staged.
TESTS = $(wildcard $(shell git ls-files --cached --others --exclude-standard '*.test'))
FAST = $(shell grep -lx '# tier: fast' $(TESTS))
FULL_PATH = $(shell grep -lE '^# tier: full-path( |$$)' $(TESTS))
UNDECLARED = $(filter-out $(FAST) $(FULL_PATH),$(TESTS))
# How many test files run at once; `make test JOBS=1` runs them one by one.
JOBS ?= $(shell nproc)

.PHONY: install test test-full-path

# Seconds a file may run before it is stopped and counted as failed. A script's dependencies install before its clock
# starts, so a cold uv cache does not read as a hang.
test: TIMEOUT = 120
test:
	@$(call run-tier,$(FAST))

test-full-path: TIMEOUT = 600
test-full-path:
	@$(call run-tier,$(FULL_PATH))

# The files run in parallel, and each one's output is printed whole once it ends.
define run-tier
$(if $(UNDECLARED),$(error these files name no tier: $(UNDECLARED)))
results=$$(mktemp -d); \
$(call run-files,-j$(JOBS) --output-sync=target,$(1)) \
skipped=$$(sort "$$results/skipped" 2>/dev/null); partly=$$(sort "$$results/partly" 2>/dev/null); \
failed=$$(sort "$$results/failed" 2>/dev/null); rm -rf "$$results"; \
[ -z "$$skipped" ] || { echo; echo "skipped:"; sed 's/^/  /' <<<"$$skipped"; }; \
[ -z "$$partly" ] || { echo; echo "skipped in part:"; sed 's/^/  /' <<<"$$partly"; }; \
[ -z "$$failed" ] || { echo; echo "failed:"; sed 's/^/  /' <<<"$$failed"; exit 1; }
endef

# Playwright's browser, which the page tests drive.
install:
	uv run --with playwright playwright install chromium-headless-shell

# A sub-make given no files would run the default goal instead.
run-files = $(if $(2),$(MAKE) --no-print-directory -k $(1) RESULTS=$$results TIMEOUT=$(TIMEOUT) $(patsubst %,run/%,$(2));)

run/%:
	@$(if $(RESULTS),,$(error run/$* is run by `make test` or `make test-full-path`, which collect its result))
	@echo "== $*"; log="$(RESULTS)/$$(tr / _ <<<'$*').log"; \
	if grep -q '^# /// script' $* && ! uv sync --script $* --quiet; then \
		echo "$*: its dependencies did not install" >> "$(RESULTS)/failed"; exit 0; \
	fi; \
	start=$$(date +%s); \
	timeout -k 10 $(TIMEOUT) ./$* < /dev/null 2>&1 | tee "$$log"; rc=$${PIPESTATUS[0]}; \
	case $$rc in \
		0) grep '^skip ' "$$log" | sed 's|^|$*: |' >> "$(RESULTS)/partly" ;; \
		77) echo "$*: $$(sed -n 's/^skip: //p' "$$log" | tail -1)" >> "$(RESULTS)/skipped" ;; \
		124|137) echo "$*: stopped after $(TIMEOUT) s" >> "$(RESULTS)/failed" ;; \
		*) echo "$*" >> "$(RESULTS)/failed" ;; \
	esac; \
	echo "-- $* took $$(( $$(date +%s) - start ))s"
