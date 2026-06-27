# Debian package build script using git-buildpackage (gbp) and cowbuilder
#
# Usage:
#   sudo apt install git-buildpackage cowbuilder
#   sudo /usr/sbin/cowbuilder --update
#   make -f debian.mk debianpackage \
#     GBP_EXTRA_OPTS="--git-pbuilder --git-pbuilder-options='--use-network yes'" \
#     | tee /tmp/hyoki-debianpackage-`date --utc --iso-8601=minutes`.log

GBP_EXTRA_OPTS =

debianpackage: debianversioncheck
	gbp buildpackage -us -uc \
	--git-upstream-tree=`git branch --show-current` \
	--git-ignore-branch \
	$(GBP_EXTRA_OPTS)

debianversioncheck: src/main.cr debian/changelog
	@echo "Comparing version strings in: $^"
	[ "$(shell crystal src/main.cr --version)" = "$(shell dpkg-parsechangelog --show-field=Version | cut --delimiter '-' --fields=1)" ]

debianpackageclean:
	dh_clean
	rm -f ../hyoki*

.PHONY: debianpackage debianversioncheck debianpackageclean
