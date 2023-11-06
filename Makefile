.PHONEY: all
.PRECIOUS: %.debug.wasm

all: main.wasm

%.debug.wasm: %.wat
	wat2wasm --debug-names $^ -o $@

%.wasm: %.debug.wasm
	wasm-opt -Oz -o $@ $^
