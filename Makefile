INSTALL_DIR ?= $(HOME)/.local/bin

.PHONY: compile test install

compile:
	@true

test:
	@true

install:
	@mkdir -p $(INSTALL_DIR)
	@ln -sf $(CURDIR)/bin/liquibase-shell "$(INSTALL_DIR)/liquibase-shell"
	@ln -sf $(CURDIR)/bin/liquibase-update "$(INSTALL_DIR)/liquibase-update"
	@ln -sf $(CURDIR)/bin/provision-db "$(INSTALL_DIR)/provision-db"
	@install -m 755 bin/tsdb-snapshot "$(INSTALL_DIR)/tsdb-snapshot"
	@install -m 755 bin/stage-db-refresh "$(INSTALL_DIR)/stage-db-refresh"
	@echo "✓ Installed liquibase-shell, liquibase-update, provision-db (symlinked), tsdb-snapshot, stage-db-refresh"
	@echo "Note: SQL files are templates — copy and customize manually"
