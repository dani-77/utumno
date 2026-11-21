PREFIX := /usr
SHAREDIR := $(PREFIX)/share/quickshell/utumno

.PHONY: install uninstall

install:
	test -x monitor/d77-monitor && test -s monitor/eww.yuck && test -s monitor/eww.scss
	install -d $(DESTDIR)$(SHAREDIR)
	rsync -a --delete \
		--exclude='.git' \
		--exclude='.gitignore' \
		--exclude='.claude' \
		--exclude='Makefile' \
		./ $(DESTDIR)$(SHAREDIR)/

uninstall:
	rm -rf $(DESTDIR)$(SHAREDIR)
