APP := build/dd/Build/Products/Release/Dozer.app
XCB := xcodebuild -project Dozer.xcodeproj -scheme Dozer -configuration Release \
       -derivedDataPath build/dd -clonedSourcePackagesDirPath build/spm

# Dependencies are resolved by SwiftPM as part of the Xcode build; the only
# tool you need on PATH is xcodegen (brew install xcodegen).
project:
	@xcodegen

build: project
	@$(XCB) build

# Replace the copy in /Applications with a freshly built one.
install: build
	@echo "Quitting any running Dozer…"
	@-osascript -e 'tell application "Dozer" to quit' 2>/dev/null || true
	@-pkill -f "Dozer.app/Contents/MacOS/Dozer" 2>/dev/null || true
	@sleep 2
	@rm -rf /Applications/Dozer.app
	@cp -R "$(APP)" /Applications/Dozer.app
	@echo "Installed to /Applications/Dozer.app"
	@open /Applications/Dozer.app

open: project
	@xed .

clean:
	@rm -rf build Dozer.xcodeproj

.PHONY: project build install open clean
