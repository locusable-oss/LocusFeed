.PHONY: generate open build acceptance self-check help

help:
	@echo "LocusFeed"
	@echo "  make generate   - xcodegen → LocusFeed.xcodeproj"
	@echo "  make open       - generate + open in Xcode"
	@echo "  make build      - unsigned local Debug build (macOS + Xcode required)"
	@echo "  make self-check - static acceptance (Linux or macOS, no Xcode, no tag)"
	@echo "  make acceptance - self-check, then print the checklist path"

generate:
	@command -v xcodegen >/dev/null || (echo "Install XcodeGen: brew install xcodegen" && exit 1)
	xcodegen generate

open: generate
	open LocusFeed.xcodeproj

build: generate
	xcodebuild -scheme LocusFeed -configuration Debug -destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build

self-check:
	./scripts/self-check.sh

acceptance: self-check
	@echo "Manual acceptance checklist: docs/checklist.md"
