#
# Written with GNU Make in mind.
#
# I will keep it heavily commented for those not familiar wit hit.
#

#
# Default PREFIX to install to.
#
# /usr/local is the proper default. Don't change it.
#
# If you want it in /usr or something else, you override it when calling make.
#
# You do that with `make PREFIX=/usr install` instead of make install.
#
# When you see $(DESTDIR)$(PREFIX) used instead, DESTDIR is more so for
# deploying to chroots and packaging stuff. It's a best practice.
#
PREFIX ?= /usr/local

#
# Save me some frelling typing.
#

NAME = rpigo
#
# where we expect stuff in ./share to install to.
#
SHAREDIR = $(DESTDIR)$(PREFIX)/share/$(NAME)
LIBDIR = $(DESTDIR)$(PREFIX)/lib/$(NAME)
BINDIR = $(DESTDIR)$(PREFIX)/bin
CONFIGDIR = $(DESTDIR)$(PREFIX)/etc/xdg/$(NAME)
DOCDIR = $(DESTDIR)$(PREFIX)/share/doc/$(NAME)

#
# list of the .cmds files in share. We prefix the names with SHAREDIR.
#
CMDS_FILES = $(addprefix $(SHAREDIR)/,$(notdir $(shell find share -name '*.cmds' -type f -print)))
#
# Same for .lib files in lib.
#
LIB_FILES = $(addprefix $(LIBDIR)/,$(notdir $(shell find lib -maxdepth 1 -name '*.lib' -print))) \
            $(addprefix $(LIBDIR)/authd/,$(notdir $(shell find lib/authd -name '*.lib' -type f -print)))
#
# And for .sh files in src. We prefix the names with BINDIR.
#
SRC_FILES = $(addprefix $(BINDIR)/,$(basename $(shell ls src)))
#
# Don't forget .conf files in config.
#
CONFIG_FILES = $(addprefix $(CONFIGDIR)/,$(notdir $(shell find config -maxdepth 1 -type f -print))) \
               $(addprefix $(CONFIGDIR)/packages.d/,$(shell ls config/packages.d)) \

DOC_FILES = $(DOCDIR)/README.md $(DOCDIR)/HACKING.md

all:
	echo blarg.

install: $(SHAREDIR) $(CMDS_FILES) $(LIBDIR) $(LIB_FILES) $(SRC_FILES) $(CONFIGDIR) $(CONFIG_FILES) $(DOCDIR) $(DOC_FILES)
	@echo install to $(DESTDIR)$(PREFIX)

.PHONY: install

$(SHAREDIR):
	@echo mkdir "$@"

$(LIBDIR):
	@echo mkdir "$@"

$(CONFIGDIR):
	@echo mkdir "$@"
	@echo mkdir "$@"/packags.d

$(DOCDIR):
	@echo mkdir "$@"

#
# Pattern rules.
#

#
# Install .cmds files from share.
#
$(SHAREDIR)/%.cmds: share/%.cmds
	@echo install $< "$@"

#
# Install .lib files from lib.
#
$(LIBDIR)/%.lib: lib/%.lib
	@echo install $< "$@"
$(LIBDIR)/authd/%.lib: lib/authd/%.lib
	@echo install $< "$@"

#
# Install .sh files from src.
#
$(BINDIR)/%: src/%.sh
	@echo install $< "$@"

#
# Install .conf and related files from config.
#
$(CONFIGDIR)/%.conf: config/%.conf
	@echo install $< "$@"
$(CONFIGDIR)/packages.d/%.list: config/packages.d/%.list
	@echo install $< "$@"

#
# Install our Markdown files.
#
$(DOCDIR)/%.md: %.md
	@echo install $< "$@"

