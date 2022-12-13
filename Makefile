CRYSTAL = crystal
CRYSTAL_PATH = `$(CRYSTAL) env CRYSTAL_PATH`
BUILD_OPTS = --error-trace --release
SPEC_OPTS = --error-trace

all: check docs build

check: formatcheck shardscheck spec

spec:
	$(CRYSTAL) spec $(SPEC_OPTS) $@ | tee $@.log

%_spec: spec/%_spec.cr
	$(CRYSTAL) spec $(SPEC_OPTS) $< | tee `basename --suffix=.cr $<`.log

formatcheck:
	$(CRYSTAL) tool format --check src spec

shardscheck:
	shards check || shards install

docs:
	$(CRYSTAL) docs

build:
	shards build $(BUILD_OPTS)

mostlyclean:
	rm -fr *.log bin/ docs/

clean: mostlyclean
	rm -fr lib/

.PHONY: all check spec formatcheck shardscheck docs mostlyclean clean
