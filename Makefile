# NeonSaga — build & test orchestration.
#
# The Xcode project is generated from project.yml (XcodeGen) — never edit
# NeonSaga.xcodeproj by hand. See CLAUDE.md §2 (commands) + §1.9 (verification
# matrix). At genesis only `make verify` (core layer) is expected green; the
# iOS app/test targets are seeded empty and go green once Stage 1 lands sources.

PROJECT   := NeonSaga.xcodeproj
SCHEME    := NeonSaga
SIM       := platform=iOS Simulator,name=iPhone 17
CORE_DIR  := NeonSagaCore

.PHONY: verify verify-full hooks test-hooks install-hooks build-core test-core build test gen open clean

# verify — fast inner loop: format/lint hooks + hook self-tests + core build + tests.
verify: hooks test-hooks build-core test-core
	@echo "✅ make verify green"

# verify-full — adds Xcode project regen + iOS app build + iOS test (stage exit).
verify-full: verify gen build test
	@echo "✅ make verify-full green"

# hooks — run pre-commit hooks (swift-format lint + custom guards + hygiene).
hooks:
	pre-commit run --all-files

# test-hooks — regression-test the local pre-commit guard scripts (bad→reject, good→pass).
test-hooks:
	./scripts/precommit/test-precommit-hooks.sh

# install-hooks — install pre-commit as a git hook so `git commit` runs the gate
# locally (the committed config alone does NOT auto-install — run this once).
install-hooks:
	pre-commit install

# build-core — swift build of the pure-Swift NeonSagaCore package.
build-core:
	cd $(CORE_DIR) && swift build

# test-core — custom runner (executableTarget, not XCTest — CLAUDE.md §4).
test-core:
	cd $(CORE_DIR) && swift run NeonSagaCoreTests

# gen — regenerate the Xcode project from project.yml.
gen:
	xcodegen generate

# build — build the iOS app for the iPhone 17 simulator.
build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIM)' build

# test — run the NeonSagaTests bundle on the iPhone 17 simulator.
test: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIM)' test

# open — regenerate the project and open it in Xcode.
open: gen
	open $(PROJECT)

# clean — remove the generated project, SwiftPM build, and DerivedData.
clean:
	rm -rf $(PROJECT)
	cd $(CORE_DIR) && swift package clean
	rm -rf $(HOME)/Library/Developer/Xcode/DerivedData/NeonSaga-*
	@echo "🧹 cleaned generated project + DerivedData"
