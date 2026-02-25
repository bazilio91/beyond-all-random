.PHONY: all clean

VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo v0)

all: mod.b64 faction_buff.b64

mod.b64: mod.lua
	@sed -i '' "1s/--BaRandom .* by LoH/--BaRandom $(VERSION) by LoH/" mod.lua; \
	./serialize.sh mod.lua > mod.b64; \
	SIZE=$$(wc -c < mod.b64 | tr -d ' '); \
	echo "Built mod $(VERSION) — $$SIZE / 16384 chars"; \
	if [ "$$SIZE" -gt 16384 ]; then echo "ERROR: mod.b64 exceeds 16,384 char limit by $$((SIZE - 16384))"; exit 1; fi

faction_buff.b64: faction_buff.lua
	./serialize.sh faction_buff.lua > faction_buff.b64

clean:
	rm -f mod.b64 faction_buff.b64
