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

# Bump patch version (1.0.0 -> 1.0.1)
bump-patch:
	@current=$$(grep -o '[0-9]*$$' <<< "$$(plutil -extract CFBundleShortVersionString raw focus/Info.plist)" || echo "0"); \
	version=$$(plutil -extract CFBundleShortVersionString raw focus/Info.plist); \
	if [[ "$$version" == *.*.* ]]; then \
		major=$$(echo $$version | cut -d. -f1); \
		minor=$$(echo $$version | cut -d. -f2); \
		patch=$$(echo $$version | cut -d. -f3); \
		new="$$major.$$minor.$$((patch + 1))"; \
	elif [[ "$$version" == *.* ]]; then \
		major=$$(echo $$version | cut -d. -f1); \
		minor=$$(echo $$version | cut -d. -f2); \
		new="$$major.$$minor.1"; \
	else \
		new="$$version.0.1"; \
	fi; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$new" focus/Info.plist; \
	build=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" focus/Info.plist); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$((build + 1))" focus/Info.plist; \
	echo "Version: $$version -> $$new (build $$((build + 1)))"

# Bump minor version (1.0 -> 1.1)
bump-minor:
	@version=$$(plutil -extract CFBundleShortVersionString raw focus/Info.plist); \
	if [[ "$$version" == *.*.* ]]; then \
		major=$$(echo $$version | cut -d. -f1); \
		minor=$$(echo $$version | cut -d. -f2); \
		new="$$major.$$((minor + 1)).0"; \
	else \
		major=$$(echo $$version | cut -d. -f1); \
		minor=$$(echo $$version | cut -d. -f2); \
		new="$$major.$$((minor + 1))"; \
	fi; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$new" focus/Info.plist; \
	build=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" focus/Info.plist); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$((build + 1))" focus/Info.plist; \
	echo "Version: $$version -> $$new (build $$((build + 1)))"

# Bump major version (1.x -> 2.0)
bump-major:
	@version=$$(plutil -extract CFBundleShortVersionString raw focus/Info.plist); \
	major=$$(echo $$version | cut -d. -f1); \
	new="$$((major + 1)).0"; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$new" focus/Info.plist; \
	build=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" focus/Info.plist); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$((build + 1))" focus/Info.plist; \
	echo "Version: $$version -> $$new (build $$((build + 1)))"

# Show current version
version:
	@echo "Version: $(VERSION) (build $$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" focus/Info.plist))"

# Create GitHub release with assets (requires gh CLI)
# Usage: make github-release NOTES="Release notes here"
#    or: make github-release (uses default notes)
github-release: dist dmg
	@echo "Creating GitHub release v$(VERSION)..."
	@gh release create v$(VERSION) \
		--title "Focus v$(VERSION)" \
		--notes "$${NOTES:-Release of Focus v$(VERSION)}" \
		"$(DIST_DIR)/Focus-$(VERSION).zip" \
		"$(DIST_DIR)/Focus-$(VERSION).dmg"
	@echo "Release published: https://github.com/BSN4/focus/releases/tag/v$(VERSION)"

# Full release workflow: bump version, build, create GitHub release
# Usage: make release-patch NOTES="Bug fixes"
#        make release-minor NOTES="New features"
#        make release-major NOTES="Breaking changes"
release-patch: bump-patch github-release
release-minor: bump-minor github-release
release-major: bump-major github-release

# Show help
help:
	@echo "Focus Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build          Build debug version"
	@echo "  release        Build release version"
	@echo "  clean          Remove build artifacts"
	@echo "  install        Build release and copy to /Applications"
	@echo "  uninstall      Remove from /Applications"
	@echo "  open           Build debug and launch"
	@echo "  run            Build release and launch"
	@echo "  dist           Create .zip for GitHub releases"
	@echo "  dmg            Create .dmg installer"
	@echo "  version        Show current version"
	@echo "  bump-patch     Bump patch version (1.0.0 -> 1.0.1)"
	@echo "  bump-minor     Bump minor version (1.0 -> 1.1)"
	@echo "  bump-major     Bump major version (1.x -> 2.0)"
	@echo "  github-release Create GitHub release with dmg+zip"
	@echo "  release-patch  Bump patch + GitHub release"
	@echo "  release-minor  Bump minor + GitHub release"
	@echo "  release-major  Bump major + GitHub release"
	@echo "  help           Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make release-minor NOTES=\"Added new feature X\""
	@echo "  make github-release NOTES=\"Bug fixes and improvements\""
