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
CONFIGDIR = $(DESTDIR)/etc/xdg/$(NAME)
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
# Various files to import into the OS.
#
OS_FILES = $(SUDOERS_FILE) /etc/init.d/rpigo /etc/logrotate.d/$(NAME)

#
# For setting up sudo.
#
RPIGO_USERNAME ?= $(NAME)
SUDOERS_TEMPLATE = sudoers
SUDOERS_FILE = $(DESTDIR)/etc/sudoers.d/rpigo

#
# Command macros.
#
MKDIR = mkdir
MKDIR_P = $(MKDIR) -p
INSTALL_CONFIG = install -m 0644 -o root -g root

help:
	@echo "Available targets and variables are as follows:"
	@echo ""
	@printf "\t* help: You're reading it.\n"
	@printf "\t* install: Install to $(DESTDIR)$(PREFIX)\n"
	@printf "\t* uninstall: uninstall files but leave $(CONFIGDIR)\n"
	@printf "\t* purge: uninstall + purge $(CONFIGDIR)\n"
	@printf "\t* useradd: do a useradd for $(RPIGO_USERNAME).\n"
	@printf "\t* userdel: do a userdel for $(RPIGO_USERNAME).\n"
	@echo ""
	@echo "You can change install location by setting PREFIX=yourpath."
	@echo 'I.e.$$ make PREFIX=/usr install'
	@echo ""
	@echo "DESTDIR will be respected as expected if given."
	@echo ""
	@echo "RPIGO_USERNAME can be set to the username to run as."
	@echo "The useradd, userdel, and various install dependencies"
	@echo "will respect this variable."
	@echo ""

install: $(SHAREDIR) $(CMDS_FILES) $(LIBDIR) $(LIB_FILES) $(SRC_FILES) $(CONFIGDIR) $(CONFIG_FILES) $(DOCDIR) $(DOC_FILES) $(OS_FILES)
	@echo "$(NAME) was installed to $(DESTDIR)$(PREFIX)"

# TODO: this should stop the daemon horde before hosing init scripts.
uninstall:
	rm -rf $(DOCDIR)
	rm -rf $(SHAREDIR)
	rm -rf $(LIBDIR)
	rm -f $(SRC_FILES)
	rm -f $(OS_FILES)
	update-rc.d -f rpigo remove

purge: uninstall
	rm -rf $(CONFIGDIR)
	rm -f $(SUDOERS_FILE)

.PHONY: install uninstall purge useradd userdel

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

# note: probably not gonna work without GNU sed.
/etc/init.d/rpigo: init/rpigo
	sed -e 's/RPIGO_USERNAME/$(RPIGO_USERNAME)/g' -e 's%RPIGO_BINDIR%$(BINDIR)%g' "$<" > "$@"
	chmod 0755 $@
	chown root:root $@
	update-rc.d -f rpigo defaults

# XXX should we use /bin/sh or /usr/sbin/nologin?
useradd:
	useradd -c "RPIGO Service Daemon" -r -M -d /srv/rpigo -s /usr/sbin/nologin "$(RPIGO_USERNAME)"

userdel:
	userdel "$(RPIGO_USERNAME)"

$(SUDOERS_FILE): $(SUDOERS_TEMPLATE)
	sed -e 's/RPIGO_USERNAME/$(RPIGO_USERNAME)/g' "$<" > "$@"
	chown 0:0 $@
	chmod 0440 $@


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
	$(INSTALL_CONFIG) $< "$@"
$(CONFIGDIR)/packages.d/%.list: config/packages.d/%.list
	$(INSTALL_CONFIG) $< "$@"
$(CONFIGDIR)/ftp.conf.secure: config/ftp.conf.secure
	$(INSTALL_CONFIG) $< "$@"
$(CONFIGDIR)/ftp.conf.simple: config/ftp.conf.simple
	$(INSTALL_CONFIG) $< "$@"
$(CONFIGDIR)/storage.config: config/storage.config
	sed -e 's/RPIGO_USERNAME/$(RPIGO_USERNAME)/g' "$<" > "$@"
	chmod 0644 $@
	chown root:root $@
/etc/logrotate.d/$(NAME): logrotate.conf
	$(INSTALL_CONFIG) $< "$@"

#
# Install our Markdown files.
#
$(DOCDIR)/%.md: %.md
	install $< "$@"

