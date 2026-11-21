.PHONY: run compile clean generate run-local test test-mumps test-pty

# assumes $ydb_dist/$gtm_dist is set by sourcing ydb_env_set or gtmprofile first
# point routine search path at src/ so routine resolution finds what it needs

ROUTINES := $(wildcard src/*.m)
TEST_ROUTINES := $(wildcard tests/*.m)

compile: $(ROUTINES) $(TEST_ROUTINES)
	@for f in $(ROUTINES); do \
		echo compiling $$f ; \
		mumps -object=src/ $$f || exit 1 ; \
	done
	@for f in $(TEST_ROUTINES); do \
		echo compiling $$f ; \
		mumps -object=tests/ $$f || exit 1 ; \
	done

run: compile
	@mumps -run '^DCRAWL'

generate: compile
	@ydb_routines="src $${ydb_routines}" gtmroutines="src $${gtmroutines}" mumps -run '^DCGEN'

test-mumps: compile
	@echo "d ^DCTEST"
	@T=$$(mktemp -d) ; \
	bash -c 'for v in $$(compgen -v ydb_) $$(compgen -v gtm); do unset "$$v"; done; export ydb_dir="'"$$T"'" ; source /usr/local/etc/ydb_env_set >/dev/null && ydb_routines="src tests $$ydb_routines" gtmroutines="src tests $$gtmroutines" mumps -run "^DCTEST"' ; \
	RC=$$? ; rm -rf "$$T" ; exit $$RC

test-pty: compile
	python3 tests/test_pty_smoke.py

test: test-mumps test-pty
	@echo ""
	@echo "ALL TESTS PASSED!"

clean:
	rm -f src/*.o tests/*.o

# convenience: run from project root with routines path set (works on YottaDB & GT.M)
run-local: compile
	@ydb_routines="src $${ydb_routines}" gtmroutines="src $${gtmroutines}" mumps -run '^DCRAWL'
