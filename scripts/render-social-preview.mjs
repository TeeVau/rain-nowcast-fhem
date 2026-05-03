import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const bundledNodeModules =
  "C:\\Users\\TobiasVaupel\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\node\\node_modules";
const sharpEntry = pathToFileURL(
  path.join(bundledNodeModules, "sharp", "lib", "index.js")
).href;
const { default: sharp } = await import(sharpEntry);

const repoRoot = process.cwd();
const inputPath = path.join(
  repoRoot,
  "assets",
  "social-preview",
  "rain-nowcast-fhem-social-preview.svg"
);
const outputPath = path.join(
  repoRoot,
  "assets",
  "social-preview",
  "rain-nowcast-fhem-social-preview.png"
);

const svg = await fs.readFile(inputPath);

await sharp(svg, { density: 144 })
  .resize(1280, 640, { fit: "fill" })
  .png({ compressionLevel: 9 })
  .toFile(outputPath);

console.log(outputPath);
