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
#
# XXX
# How to handle this? Some systems have /usr/local/etc; most do not.
# Probably should use $(DESTDIR)/etc/xdg/$(NAME) for this.
#
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

#
# Command macros.
#
MKDIR = mkdir
MKDIR_P = $(MKDIR) -p

help:
	@echo "Available targets and variables are as follows:"
	@echo ""
	@printf "\t* help:\n"
	@printf "\t* install: Install to $(DESTDIR)$(PREFIX)\n"
	@printf "\t* uninstall: uninstall files but leave $(CONFIGDIR)\n"
	@printf "\t* purge: uninstall + purge $(CONFIGDIR)\n"
	@echo ""
	@echo "You can change install location by setting PREFIX=yourpath."
	@echo 'I.e.$$ make PREFIX=/usr install'
	@echo ""
	@echo "DESTDIR will be respected as expected if given."
	@echo ""

install: $(SHAREDIR) $(CMDS_FILES) $(LIBDIR) $(LIB_FILES) $(SRC_FILES) $(CONFIGDIR) $(CONFIG_FILES) $(DOCDIR) $(DOC_FILES)
	@echo "$(NAME) was installed to $(DESTDIR)$(PREFIX)"

uninstall:
	rm -rf $(DOCDIR)
	rm -rf $(SHAREDIR)
	rm -rf $(LIBDIR)
	rm -f $(SRC_FILES)

purge: uninstall
	rm -rf $(CONFIGDIR)

.PHONY: install uninstall purge

$(SHAREDIR):
	$(MKDIR_P) "$@"

$(LIBDIR):
	$(MKDIR_P) "$@"
	$(MKDIR_P) "$@"/authd

$(CONFIGDIR):
	$(MKDIR_P) -p "$@"
	$(MKDIR_P) "$@"/packages.d

$(DOCDIR):
	$(MKDIR_P) "$@"

#
# Pattern rules.
#

#
# Install .cmds files from share.
#
$(SHAREDIR)/%.cmds: share/%.cmds
	install $< "$@"

#
# Install .lib files from lib.
#
$(LIBDIR)/%.lib: lib/%.lib
	install $< "$@"
$(LIBDIR)/authd/%.lib: lib/authd/%.lib
	install $< "$@"

#
# Install .sh files from src.
#
$(BINDIR)/%: src/%.sh
	install $< "$@"

#
# Install .conf and related files from config.
#
$(CONFIGDIR)/%.conf: config/%.conf
	install $< "$@"
$(CONFIGDIR)/packages.d/%.list: config/packages.d/%.list
	install $< "$@"
$(CONFIGDIR)/ftp.conf.secure: config/ftp.conf.secure
	install $< "$@"
$(CONFIGDIR)/ftp.conf.simple: config/ftp.conf.simple
	install $< "$@"

#
# Install our Markdown files.
#
$(DOCDIR)/%.md: %.md
	install $< "$@"

