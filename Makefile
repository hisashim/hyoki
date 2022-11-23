CRYSTAL = crystal
CRYSTAL_PATH = `$(CRYSTAL) env CRYSTAL_PATH`
BUILD_OPTS = --error-trace
SPEC_OPTS = --error-trace

all: check docs

check: formatcheck spec

spec:
	$(CRYSTAL) spec $(SPEC_OPTS) $@ | tee $@.log

%_spec: spec/%_spec.cr
	$(CRYSTAL) spec $(SPEC_OPTS) $< | tee `basename --suffix=.cr $<`.log

formatcheck:
	$(CRYSTAL) tool format --check src spec

docs:
	$(CRYSTAL) docs

mostlyclean:
	rm -fr *.log

clean: mostlyclean
	rm -fr docs/

.PHONY: all check spec formatcheck docs mostlyclean clean
