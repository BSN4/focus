.PHONY: build release clean install uninstall open dist dmg

APP_NAME = focus
BUILD_DIR = build
DIST_DIR = dist
INSTALL_DIR = /Applications
SCHEME = focus
PROJECT = focus.xcodeproj
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" focus/Info.plist)

# Build debug version
build:
	@echo "Building $(APP_NAME) (Debug)..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build 2>&1 | tail -20
	@echo "Done. App at: $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app"

# Build release version
release:
	@echo "Building $(APP_NAME) (Release)..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build 2>&1 | tail -20
	@echo "Done. App at: $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean 2>/dev/null || true
	@echo "Done."

# Install to /Applications (requires release build first)
install: release
	@echo "Installing to $(INSTALL_DIR)..."
	@cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"
	@echo ""
	@echo "Grant Accessibility permission:"
	@echo "  System Settings → Privacy & Security → Accessibility → Enable $(APP_NAME)"

# Uninstall from /Applications
uninstall:
	@echo "Uninstalling..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Done."

# Open the built app (debug)
open: build
	@open "$(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app"

# Run release build
run: release
	@open "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

# Create distributable .zip for GitHub releases
dist: release
	@echo "Creating distribution zip..."
	@mkdir -p $(DIST_DIR)
	@cd "$(BUILD_DIR)/Build/Products/Release" && zip -r -q "../../../../$(DIST_DIR)/Focus-$(VERSION).zip" "$(APP_NAME).app"
	@echo "Created: $(DIST_DIR)/Focus-$(VERSION).zip"
	@ls -lh "$(DIST_DIR)/Focus-$(VERSION).zip"

# Create .dmg installer
dmg: release
	@echo "Creating DMG..."
	@mkdir -p $(DIST_DIR)
	@rm -f "$(DIST_DIR)/Focus-$(VERSION).dmg"
	@hdiutil create -volname "Focus" -srcfolder "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" \
		-ov -format UDZO "$(DIST_DIR)/Focus-$(VERSION).dmg" 2>/dev/null
	@echo "Created: $(DIST_DIR)/Focus-$(VERSION).dmg"
	@ls -lh "$(DIST_DIR)/Focus-$(VERSION).dmg"

# Show help
help:
	@echo "Focus Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     Build debug version"
	@echo "  release   Build release version"
	@echo "  clean     Remove build artifacts"
	@echo "  install   Build release and copy to /Applications"
	@echo "  uninstall Remove from /Applications"
	@echo "  open      Build debug and launch"
	@echo "  run       Build release and launch"
	@echo "  dist      Create .zip for GitHub releases"
	@echo "  dmg       Create .dmg installer"
	@echo "  help      Show this help"
