// Hapus file gambar di images/packages yang tidak dirujuk packages/*.json.
// Folder images/packages/stacks dilewati (dirujuk stacks.json).
// Usage: node scripts/prune-images.js [--apply]   (tanpa --apply hanya daftar)
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]
  );
}

export function findUnused(root) {
  const refs = new Set();
  const pkgDir = path.join(root, "packages");
  for (const f of fs.readdirSync(pkgDir).filter((n) => n.endsWith(".json"))) {
    for (const m of fs.readFileSync(path.join(pkgDir, f), "utf8").matchAll(/"(images\/packages\/[^"]+)"/g)) {
      refs.add(m[1]);
    }
  }
  return walk(path.join(root, "images", "packages"))
    .map((p) => path.relative(root, p).split(path.sep).join("/"))
    .filter((rel) => !rel.startsWith("images/packages/stacks/") && !refs.has(rel));
}

if (process.argv[1]?.endsWith("prune-images.js")) {
  const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const apply = process.argv.includes("--apply");
  const unused = findUnused(ROOT);
  let bytes = 0;
  for (const rel of unused) {
    const file = path.join(ROOT, rel);
    bytes += fs.statSync(file).size;
    if (apply) fs.unlinkSync(file);
  }
  const mb = (bytes / 1048576).toFixed(1);
  console.log(`${unused.length} file tidak dirujuk, ${mb} MB${apply ? " (dihapus)" : ". Tambah --apply untuk menghapus."}`);
}
