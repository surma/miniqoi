const params = new URLSearchParams(location.search);
const decoderSrc = params.has("debug") ? "./main.debug.wasm" : "./main.wasm";
const rawImage = await fetch("./squoosh.qoi").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiateStreaming(fetch(decoderSrc));

const { memory, decode } = instance.exports;
const len = rawImage.byteLength;

memory.grow(Math.ceil(rawImage.byteLength / (64 * 1024)));
const imgView = new Uint8Array(memory.buffer);
imgView.set(new Uint8Array(rawImage));

try {
  const start = performance.now();
  decode(rawImage.byteLength);
  const duration = performance.now() - start;
  console.log({ duration });
  const [width, height] = new Uint32Array(
    memory.buffer,
    instance.exports.output_base.value,
  );
  const cvs = document.createElement("canvas");
  document.body.append(cvs);
  const ctx = cvs.getContext("2d");
  ctx.canvas.width = width;
  ctx.canvas.height = height;
  const len = width * height * 4;
  const data = new Uint8ClampedArray(len);
  data.set(
    new Uint8ClampedArray(
      memory.buffer,
      instance.exports.output_base.value + 8,
    ).subarray(0, len),
  );
  const imgData = new ImageData(data, width, height);
  ctx.putImageData(imgData, 0, 0);
} catch (e) {
  console.error(e);
  console.log({
    iptr: instance.exports.iptr.value,
    optr: instance.exports.optr.value,
  });
}
