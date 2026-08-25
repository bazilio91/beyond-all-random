.PHONY: all clean segments setup docker widgets test

VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo v0)

all: mod.b64 mod_part2.b64 mod_tiers.b64 faction_buff.b64

mod.b64: mod.lua
	@sed -i '' "1s/--BaRandom .* by LoH/--BaRandom $(VERSION) by LoH/" mod.lua; \
	./serialize.sh mod.lua > mod.b64; \
	SIZE=$$(wc -c < mod.b64 | tr -d ' '); \
	echo "Built mod $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

mod_part2.b64: mod_part2.lua
	@./serialize.sh mod_part2.lua > mod_part2.b64; \
	SIZE=$$(wc -c < mod_part2.b64 | tr -d ' '); \
	echo "Built mod_part2 $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod_part2.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

mod_tiers.b64: mod_tiers.lua
	@./serialize.sh mod_tiers.lua > mod_tiers.b64; \
	SIZE=$$(wc -c < mod_tiers.b64 | tr -d ' '); \
	echo "Built mod_tiers $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod_tiers.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

faction_buff.b64: faction_buff.lua
	./serialize.sh faction_buff.lua > faction_buff.b64

segments: mod.lua mod_part2.lua mod_tiers.lua
	@luamin -c < mod.lua | node scripts/generate_segments.js
	@luamin -c < mod_part2.lua | node scripts/generate_part2_segments.js
	@luamin -c < mod_tiers.lua | node scripts/generate_tiers_segments.js

setup:
	cp scripts/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed"

docker: mod.lua mod_part2.lua mod_tiers.lua
	docker build -f Dockerfile.build -t bar-build . && \
	docker run --rm bar-build mod.lua > mod.b64 && \
	docker run --rm bar-build mod_part2.lua > mod_part2.b64 && \
	docker run --rm bar-build mod_tiers.lua > mod_tiers.b64
	@SIZE=$$(wc -c < mod.b64 | tr -d ' '); echo "Built mod (docker) — $$SIZE / 16384 chars"
	@SIZE=$$(wc -c < mod_part2.b64 | tr -d ' '); echo "Built mod_part2 (docker) — $$SIZE / 16384 chars"
	@SIZE=$$(wc -c < mod_tiers.b64 | tr -d ' '); echo "Built mod_tiers (docker) — $$SIZE / 16384 chars"

# Offline smoke test: runs every slot against a synthetic UnitDefs table.
# DEFS=<dir> merges real BAR unit defs, SEED=<n> forces a specific roll.
test:
	@docker build -q -f Dockerfile.build -t bar-build . > /dev/null
	@MSYS_NO_PATHCONV=1 docker run --rm -v "$(CURDIR)":/build -w /build --entrypoint lua5.1 bar-build scripts/smoke_test.lua $(DEFS) $(SEED)

widgets: widget_tweakdefs_bridge.lua
	@mkdir -p docs/widgets
	@cp widget_tweakdefs_bridge.lua docs/widgets/Tweakdefs_bridge.lua
	@echo "Synced widget to docs/widgets/"

clean:
	rm -f mod.b64 mod_part2.b64 mod_tiers.b64 faction_buff.b64
