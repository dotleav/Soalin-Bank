// Membuat stacks.json: daftar gambar per folder stack (dipakai soal MRI via field { stack: "brain-lobes/Coronal" }).
// Jalankan setiap kali menambah/menghapus gambar di images/packages/stacks/: node scripts/build-stacks.js
import { readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = "images/packages/stacks/brain-lobes";
const EXT = /\.(jpe?g|png|webp|gif)$/i;
const out = {};
for (const dir of readdirSync(ROOT).sort()) {
  const full = join(ROOT, dir);
  if (!statSync(full).isDirectory() || dir === "jawaban") continue; // jawaban = legenda, bukan stack
  const files = readdirSync(full).filter((f) => EXT.test(f)).sort();
  if (files.length) out["brain-lobes/" + dir] = files.map((f) => join(ROOT, dir, f).split("\\").join("/"));
}
writeFileSync("stacks.json", JSON.stringify(out, null, 2) + "\n");
console.log("stacks:", Object.fromEntries(Object.entries(out).map(([k, v]) => [k, v.length])));
