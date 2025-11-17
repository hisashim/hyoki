CRYSTAL = crystal
CRYSTAL_PATH = `$(CRYSTAL) env CRYSTAL_PATH`
BUILD_OPTS = --error-trace --release
SPEC_OPTS = --error-trace
DESTDIR =
PREFIX = /usr/local
SOURCE_DATE_EPOCH := $(shell (git show --quiet --format=%ct HEAD || stat --format "%Y" Makefile) 2> /dev/null)
DOC = doc/man/hyoki.1 doc/README.md doc/README_ja.md doc/README.html doc/README_ja.html

all: check build doc

check: formatcheck shardscheck spec

spec:
	$(CRYSTAL) spec $(SPEC_OPTS) $@ | tee $@.log

%_spec: spec/%_spec.cr
	$(CRYSTAL) spec $(SPEC_OPTS) $< | tee `basename --suffix=.cr $<`.log

formatcheck:
	$(CRYSTAL) tool format --check src spec

shardscheck:
	shards check || shards install

%.1: %.adoc
	SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) asciidoctor --backend=manpage --out-file=$@ $<

doc/%.md: %.md
	sed 's/\[\([^]]*\)\](doc\/\([^]]*\))/[\1](\2)/g' $< > $@

doc/%.html: doc/%.md
	cmark $< | sed 's/href="\([^"]*\)\.md"/href="\1.html"/g' > $@

doc: $(DOC)

build: bin/hyoki

bin/hyoki:
	shards build $(BUILD_OPTS)

install: bin/hyoki $(DOC)
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp bin/hyoki $(DESTDIR)$(PREFIX)/bin/

mostlyclean:
	rm -fr *.log bin/ doc/man/*.1 doc/*.md doc/*.html

clean: mostlyclean
	rm -fr lib/

.PHONY: all check spec formatcheck shardscheck doc build install mostlyclean clean
