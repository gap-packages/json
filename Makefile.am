#
# json: Reading and Writing JSON
#
# This file is part of the build system of a GAP kernel extension.
# Requires automake.
#
ACLOCAL_AMFLAGS = -I m4

BINARCHDIR = bin/$(GAPARCH)
GAPINSTALLLIB = $(abs_top_srcdir)/$(BINARCHDIR)/json.so

lib_LTLIBRARIES = json.la

json_la_SOURCES = src/json.cc
json_la_LDFLAGS = -module -avoid-version
if SYS_IS_CYGWIN
json_la_LDFLAGS += -no-undefined -version-info 0:0:0 -Wl,$(GAPROOT)/bin/$(GAPARCH)/gap.dll
endif

all-local: json.la
	$(mkdir_p) $(top_srcdir)/$(BINARCHDIR)
if SYS_IS_CYGWIN
	cp .libs/json.dll $(GAPINSTALLLIB)
else
	cp .libs/json.so $(GAPINSTALLLIB)
endif
	@echo "SUCCESS!"

distclean-local:
	rm -rf bin/*
	(cd doc ; ./clean)

doc: doc/manual.six

doc/manual.six: doc/*.xml PackageInfo.g
	($(GAPROOT)/bin/gap.sh -A makedoc.g)
