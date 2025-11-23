# usage: make debianpackage GBP_EXTRA_OPTS="--git-pbuilder --git-pbuilder-options='--use-network yes'"
GBP_EXTRA_OPTS =

debianpackage:
	gbp buildpackage -us -uc \
	--git-upstream-tree=`git branch --show-current` \
	--git-ignore-branch $(GBP_EXTRA_OPTS)

debianpackageclean:
	dh_clean
	rm -f ../hyoki*

.PHONY: debianpackage debianpackageclean
