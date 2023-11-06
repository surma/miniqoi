const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./main.wasm"),
);

const { memory, decode } = instance.exports;
const len = rawImage.byteLength;

const imgView = new Uint8Array(memory.buffer);
imgView.set(new Uint8Array(rawImage));

const output = decode(rawImage.byteLength);
console.log({output});

const dataView = new DataView(memory.buffer);
console.log(dataView.getUint32(output, true))
console.log(dataView.getUint32(output + 4, true))
// memory
