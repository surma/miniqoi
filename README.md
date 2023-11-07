# Miniqoi

Miniqoi is a small (904B) decoder for the [QOI image format][qoi].

## Usage

```js
const { instance } = await WebAssembly.instantiateStreaming(
  fetch("./qoi_decode.wasm"),
);
const { decode, memory } = instance.exports;

// Make sure you make memory large enough to hold the input image
memory.grow(Math.ceil(qoiImageBuffer.byteLength / 2 ** 16));
// Copy the QOI file into Wasm memory starting at address 0.
new Uint8Array(memory.buffer).set(qoiImageBuffer);

const ptr = decode(qoiImageBuffer.byteLength);
// Read width and height of the image
const [width, height] = new Uint32Array(memory.buffer, ptr);
const rgba = new Uint8ClampedArray(memory.buffer, ptr + 8, width * height * 4);
const imgData = new ImageData(rgba, width, height);

// ... use imgData as per usual. For example:

const cvs = document.createElement("canvas");
document.body.append(cvs);
const ctx = cvs.getContext("2d");
ctx.canvas.width = imgData.width;
ctx.canvas.height = imgData.height;
ctx.putImageData(imgData, 0, 0);
```

[qoi]: https://qoiformat.org/

---
Apache-2.0
