const params = new URLSearchParams(location.search);
const decoderSrc = params.has("debug") ? "./main.debug.wasm" : "./main.wasm";
const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(
  fetch(decoderSrc),
);

const { memory, decode } = instance.exports;
const len = rawImage.byteLength;

const imgView = new Uint8Array(memory.buffer);
imgView.set(new Uint8Array(rawImage));

try {
  const output = decode(rawImage.byteLength);
  console.log({output});
} catch(e) {
  console.error(e);
  console.log({
    iptr: instance.exports.iptr.value,
    optr: instance.exports.optr.value,
  });
}

const [width, height] = new Uint32Array(memory.buffer, 
  instance.exports.output_base.value);
const data = new Uint8ClampedArray(memory.buffer, instance.exports.output_base.value + 8).subarray(0, width * height * 4);
const imgData = new ImageData(data, width, height);

const cvs = document.createElement("canvas");
document.body.append(cvs);
cvs.width = width;
cvs.height = height;
const ctx = cvs.getContext("2d");
ctx.putImageData(imgData, 0, 0);


