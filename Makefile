.PHONY: generate open build acceptance help

help:
	@echo "LocusFeed"
	@echo "  make generate   - xcodegen → LocusFeed.xcodeproj"
	@echo "  make open       - generate + open in Xcode"
	@echo "  make build      - unsigned local Debug build (macOS + Xcode required)"
	@echo "  make acceptance - print path to ACCEPTANCE.md checklist"

generate:
	@command -v xcodegen >/dev/null || (echo "Install XcodeGen: brew install xcodegen" && exit 1)
	xcodegen generate

open: generate
	open LocusFeed.xcodeproj

build: generate
	xcodebuild -scheme LocusFeed -configuration Debug -destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build

acceptance:
	@echo "Manual acceptance checklist: ACCEPTANCE.md"
