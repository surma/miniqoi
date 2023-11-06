const cvs = document.createElement("canvas");
document.body.append(cvs);
const ctx = cvs.getContext("2d");

const params = new URLSearchParams(location.search);
const decoderSrc = params.has("debug") ? "./main.debug.wasm" : "./main.wasm";
const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(fetch(decoderSrc), {
  env: {
    rerender() {
      ctx.putImageData(currentImage(), 0, 0);
    },
  },
});

function currentImage() {
  const [width, height] = new Uint32Array(
    memory.buffer,
    instance.exports.output_base.value,
  );
  ctx.canvas.width = width;
  ctx.canvas.height = height;
  const len = width * height * 4;
  const data = new Uint8ClampedArray(len);
  data.set(new Uint8ClampedArray(
    memory.buffer,
    instance.exports.output_base.value + 8,
  ).subarray(0, len));
  const imgData = new ImageData(data, width, height);
  return imgData;
}

const { memory, decode } = instance.exports;
const len = rawImage.byteLength;

const imgView = new Uint8Array(memory.buffer);
imgView.set(new Uint8Array(rawImage));

try {
  decode(rawImage.byteLength);
  ctx.putImageData(currentImage(), 0, 0);
} catch (e) {
  console.error(e);
  console.log({
    iptr: instance.exports.iptr.value,
    optr: instance.exports.optr.value,
  });
}
