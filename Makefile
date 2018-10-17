.PHONY: all clean check

all: riposte

clean:
	rm -Rf compiled
	rm -f riposte
	rm -Rf doc
	find . -mindepth 1 -maxdepth 1 -type f -name '*~' -delete
	find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec $(MAKE) -C {} clean ';'

riposte: $(wildcard *.rkt)
	raco exe riposte.rkt

check:
	raco test *.rkt
	raco setup --check-pkg-deps --fix-pkg-deps --unused-pkg-deps --pkgs riposte
