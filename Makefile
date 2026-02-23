.PHONY: all clean

all: mod.b64

mod.b64: mod.lua
	./serialize.sh mod.lua > mod.b64

clean:
	rm -f mod.b64
