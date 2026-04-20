.PHONY: run compile clean

# assumes $gtm_dist and gtmroutines are set by sourcing gtmprofile first.
# point gtmroutines at the src/ dir so routine resolution finds everything.

ROUTINES := $(wildcard src/*.m)

compile: $(ROUTINES)
	@for f in $(ROUTINES); do \
		echo compiling $$f ; \
		mumps -object $$f || exit 1 ; \
	done

run: compile
	@mumps -run '^DCRAWL'

clean:
	rm -f src/*.o

# convenience: run from project root with routines path set
run-local: compile
	@gtmroutines='. src' mumps -run '^DCRAWL'
