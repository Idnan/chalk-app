# Chalk Makefile
#   make gen     - regenerate Chalk.xcodeproj from project.yml (XcodeGen)
#   make build   - Debug build into ./build
#   make run     - build, then relaunch the app
#   make test    - run unit tests
#   make release - Release build into ./build
#   make clean   - remove build artifacts

SCHEME = Chalk
PROJECT = Chalk.xcodeproj
DERIVED = build
APP = $(DERIVED)/Build/Products/Debug/Chalk.app

.PHONY: gen build run test release clean

gen:
	xcodegen generate

$(PROJECT): project.yml
	xcodegen generate

build: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) build | tail -n 5

run: build
	-pkill -x Chalk
	open $(APP)

test: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) test | tail -n 20

release: $(PROJECT)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED) build | tail -n 5

clean:
	rm -rf $(DERIVED)
