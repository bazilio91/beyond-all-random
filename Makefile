.PHONY: all clean segments setup docker

VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo v0)

all: mod.b64 mod_buildings.b64 faction_buff.b64

mod.b64: mod.lua
	@sed -i '' "1s/--BaRandom .* by LoH/--BaRandom $(VERSION) by LoH/" mod.lua; \
	./serialize.sh mod.lua > mod.b64; \
	SIZE=$$(wc -c < mod.b64 | tr -d ' '); \
	echo "Built mod $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

mod_buildings.b64: mod_buildings.lua
	@./serialize.sh mod_buildings.lua > mod_buildings.b64; \
	SIZE=$$(wc -c < mod_buildings.b64 | tr -d ' '); \
	echo "Built mod_buildings $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod_buildings.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

faction_buff.b64: faction_buff.lua
	./serialize.sh faction_buff.lua > faction_buff.b64

segments: mod.lua mod_buildings.lua
	@luamin -c < mod.lua | node scripts/generate_segments.js
	@luamin -c < mod_buildings.lua | node scripts/generate_buildings_segments.js

setup:
	cp scripts/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed"

docker: mod.lua mod_buildings.lua
	docker build -f Dockerfile.build -t bar-build . && \
	docker run --rm bar-build mod.lua > mod.b64 && \
	docker run --rm bar-build mod_buildings.lua > mod_buildings.b64
	@SIZE=$$(wc -c < mod.b64 | tr -d ' '); echo "Built mod (docker) — $$SIZE / 16384 chars"
	@SIZE=$$(wc -c < mod_buildings.b64 | tr -d ' '); echo "Built mod_buildings (docker) — $$SIZE / 16384 chars"

clean:
	rm -f mod.b64 mod_buildings.b64 faction_buff.b64
