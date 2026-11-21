.PHONY: run compile clean generate run-local

# assumes $ydb_dist/$gtm_dist is set by sourcing ydb_env_set or gtmprofile first
# point routine search path at src/ so routine resolution finds what it needs

ROUTINES := $(wildcard src/*.m)

compile: $(ROUTINES)
	@for f in $(ROUTINES); do \
		echo compiling $$f ; \
		mumps -object=src/ $$f || exit 1 ; \
	done

run: compile
	@mumps -run '^DCRAWL'

generate:
	python3 generate_dungeons.py

clean:
	rm -f src/*.o

# convenience: run from project root with routines path set (works on YottaDB & GT.M)
run-local: compile
	@ydb_routines="src $${ydb_routines}" gtmroutines="src $${gtmroutines}" mumps -run '^DCRAWL'
