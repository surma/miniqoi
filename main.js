const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./main.wasm"),
);

const { memory, decode, output_start, base } = instance.exports;
const len = rawImage.byteLength;

const mem8View = new Uint8Array(memory.buffer);
const imgView = mem8View.subarray(base.value, base.value + len);
imgView.set(new Uint8Array(rawImage));

const output = decode();
console.log({ output });

const dataView = new DataView(memory.buffer);
console.log(dataView.getUint32(output, true));
console.log(dataView.getUint32(output + 4, true));
// memory
