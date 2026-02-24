.PHONY: all clean

VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null || echo v0)

all: mod.b64 faction_buff.b64

mod.b64: mod.lua
	@sed -i '' "1s/--BaRandom .* by LoH/--BaRandom $(VERSION) by LoH/" mod.lua; \
	./serialize.sh mod.lua > mod.b64; \
	echo "Built mod $(VERSION)"

faction_buff.b64: faction_buff.lua
	./serialize.sh faction_buff.lua > faction_buff.b64

clean:
	rm -f mod.b64 faction_buff.b64
