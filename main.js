const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./main.wasm"),
);

const { memory, decode, output_start } = instance.exports;
const start = 0;
const len = rawImage.byteLength;

const mem8View = new Uint8Array(memory.buffer);
const mem32View = new Uint32Array(memory.buffer);
const imgView = mem8View.subarray(start, start + len);
imgView.set(new Uint8Array(rawImage));

console.log(decode(start, len));

console.log(mem32View[output_start.value / 4]);
console.log(mem32View[output_start.value / 4 + 1]);
// memory
