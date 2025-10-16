# default to /usr - there's no reason for /usr/local to be the default here.
ifeq ($(PREFIX),)
	PREFIX := /usr
endif
ifeq ($(LIBEXEC),)
	LIBEXEC := libexec
endif
ifeq ($(SYSCONFDIR),)
	SYSCONFDIR := /etc
endif
ifeq  ($(DOCDIR),)
	DOCDIR := $(PREFIX)/share/doc
endif

.PHONY: .FORCE

SCOUTFS_FENCED_RUN_DIR := ${PREFIX}/$(LIBEXEC)/scoutfs-fenced/run

scoutfs-fenced.conf:
	sed "s,@@PREFIX@@,$(PREFIX),g;s,@@LIBEXEC@@,$(LIBEXEC),g" scoutfs-fenced.conf.in > scoutfs-fenced.conf

# - We use the git describe from tags to set up the RPM versioning
RPM_VERSION := $(shell git describe --always --long --tags | awk -F '-' '{gsub(/^v/,""); print $$1}')
RPM_GITHASH := $(shell git rev-parse --short HEAD)

%.spec: %.spec.in .FORCE
	sed -e 's/@@VERSION@@/$(RPM_VERSION)/g' \
	    -e 's/@@GITHASH@@/$(RPM_GITHASH)/g' < $< > $@+
	mv $@+ $@

TARFILE = scoutfs-fence-agent-$(RPM_VERSION).tar

dist: $(RPM_DIR) scoutfs-fence-agent.spec
	git archive --format=tar --prefix scoutfs-fence-agent-$(RPM_VERSION)/ HEAD^{tree} > $(TARFILE)
	tar rf $(TARFILE) --transform="s@\(.*\)@scoutfs-fence-agent-$(RPM_VERSION)/\1@" scoutfs-fence-agent.spec

all:	scoutfs-fenced.conf

clean:
	rm -f scoutfs-fenced.conf scoutfs-fence-agent.spec

check:
	shellcheck scoutfs-fence-agent

install: scoutfs-fenced.conf
	install -d $(DESTDIR)$(SCOUTFS_FENCED_RUN_DIR)
	install -m0755 scoutfs-fence-agent $(DESTDIR)$(SCOUTFS_FENCED_RUN_DIR)/
	install -d $(DESTDIR)$(SYSCONFDIR)/scoutfs
	test ! -f $(DESTDIR)$(SYSCONFDIR)/scoutfs/scoutfs-fenced.conf && install scoutfs-fenced.conf $(DESTDIR)$(SYSCONFDIR)/scoutfs/
	install -d $(DESTDIR)$(DOCDIR)/scoutfs-fence-agent
	install README.md $(DESTDIR)$(DOCDIR)/scoutfs-fence-agent/
	install scoutfs-ipmi.conf-example  scoutfs-ipmi-hosts.conf-example $(DESTDIR)$(DOCDIR)/scoutfs-fence-agent/
