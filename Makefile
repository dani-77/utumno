PREFIX := /usr
SHAREDIR := $(PREFIX)/share/quickshell/utumno

.PHONY: install uninstall

install:
	install -d $(DESTDIR)$(SHAREDIR)
	rsync -a --delete \
		--exclude='.git' \
		--exclude='.gitignore' \
		--exclude='.claude' \
		--exclude='Makefile' \
		./ $(DESTDIR)$(SHAREDIR)/

uninstall:
	rm -rf $(DESTDIR)$(SHAREDIR)
