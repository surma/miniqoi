const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./main.wasm"),
);

const { memory, decode } = instance.exports;
const start = 0;
const len = rawImage.byteLength;

const memView = new Uint8Array(memory.buffer);
const imgView = memView.subarray(start, start + len);
imgView.set(new Uint8Array(rawImage));

console.log(decode(start, len));
