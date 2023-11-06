.PHONEY: all clean
.PRECIOUS: %.debug.wasm

all: main.wasm

%.debug.wasm: %.wat
	wat2wasm --debug-names $^ -o $@

%.wasm: %.debug.wasm
	wasm-opt --strip-debug -O3 -o $@ $^

clean:
	@rm -rf *.wasm
