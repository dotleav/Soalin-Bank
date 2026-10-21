// Kelola paket yang sudah ada di bank: ganti nama, pindah kategori, hapus.
// Dipanggil dari bank-gui.ps1, bisa juga dipakai manual.
//
// Usage:
//   node scripts/manage.js rename <id> "Judul baru"
//   node scripts/manage.js move <id> "Kategori baru"
//   node scripts/manage.js delete <id>
//   node scripts/manage.js rename-category "Kategori lama" "Kategori baru" [reguler|premium]
//   node scripts/manage.js tier <id> reguler|premium
//
// id paket TIDAK pernah berubah: id adalah kunci progres belajar di app.
// Karena id tetap, progres belajar ikut pindah bersama paket saat ganti tier.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const INDEX = path.join(ROOT, "index.json");

function fail(msg) {
  console.error("Error: " + msg);
  process.exit(1);
}

const [cmd, ...args] = process.argv.slice(2);
const clean = (s) => (s || "").trim();

function loadIndex() {
  if (!fs.existsSync(INDEX)) fail("index.json tidak ada");
  return JSON.parse(fs.readFileSync(INDEX, "utf-8"));
}

function saveIndex(idx) {
  idx.packages.sort(
    (a, b) => (a.category || "").localeCompare(b.category || "") || (a.title || "").localeCompare(b.title || "")
  );
  idx.generatedAt = new Date().toISOString();
  fs.writeFileSync(INDEX, JSON.stringify(idx, null, 2));
}

function findEntry(idx, id) {
  if (!id) fail("id paket belum diisi");
  if (/[\\/]|\.\./.test(id)) fail("id paket tidak valid: " + id);
  const e = idx.packages.find((p) => p.id === id);
  if (!e) fail("paket tidak ditemukan: " + id);
  return e;
}

// packages/<id>.json juga memuat title & category; samakan supaya tidak beda dengan index.
function patchPackageFile(entry, fields) {
  if (!entry.file || !entry.file.startsWith("packages/")) return;
  const p = path.join(ROOT, entry.file);
  if (!fs.existsSync(p)) return;
  const data = JSON.parse(fs.readFileSync(p, "utf-8"));
  fs.writeFileSync(p, JSON.stringify({ ...data, ...fields }, null, 2));
}

switch (cmd) {
  case "rename": {
    const title = clean(args[1]);
    if (!title) fail("judul baru kosong");
    const idx = loadIndex();
    const e = findEntry(idx, clean(args[0]));
    e.title = title;
    patchPackageFile(e, { title });
    saveIndex(idx);
    console.log(`Diganti nama: ${title}`);
    break;
  }
  case "move": {
    const category = clean(args[1]);
    if (!category) fail("kategori tujuan kosong");
    const idx = loadIndex();
    const e = findEntry(idx, clean(args[0]));
    e.category = category;
    patchPackageFile(e, { category });
    saveIndex(idx);
    console.log(`Dipindah ke kategori: ${category}`);
    break;
  }
  case "delete": {
    const idx = loadIndex();
    const e = findEntry(idx, clean(args[0]));
    // Index dulu, baru file: kalau gagal di tengah, index tetap konsisten dengan yang masih ada.
    idx.packages = idx.packages.filter((p) => p !== e);
    saveIndex(idx);
    if (e.file && e.file.startsWith("packages/")) fs.rmSync(path.join(ROOT, e.file), { force: true });
    fs.rmSync(path.join(ROOT, "images", "packages", e.id), { recursive: true, force: true });
    console.log(`Dihapus: ${e.title} (${e.count} soal)`);
    break;
  }
  case "rename-category": {
    const from = clean(args[0]);
    const to = clean(args[1]);
    const tier = clean(args[2]);
    if (!from || !to) fail("nama kategori lama dan baru wajib diisi");
    if (from === to) fail("nama kategori sama");
    if (tier && tier !== "reguler" && tier !== "premium") fail("tier harus reguler atau premium");
    const idx = loadIndex();
    const hit = idx.packages.filter((p) => p.category === from && (!tier || p.tier === tier));
    if (hit.length === 0) fail(`kategori tidak ditemukan: ${from}`);
    for (const e of hit) {
      e.category = to;
      patchPackageFile(e, { category: to });
    }
    saveIndex(idx);
    console.log(`${hit.length} paket dipindah dari "${from}" ke "${to}".`);
    break;
  }
  case "tier": {
    const tier = clean(args[1]);
    if (tier !== "reguler" && tier !== "premium") fail("tier harus reguler atau premium");
    const idx = loadIndex();
    const e = findEntry(idx, clean(args[0]));
    if (e.tier === tier) fail(`paket sudah di tier ${tier}`);
    e.tier = tier;
    patchPackageFile(e, { tier });
    saveIndex(idx);
    console.log(`Tier diubah ke ${tier}: ${e.title}`);
    break;
  }
  default:
    fail("perintah tidak dikenal: " + (cmd || "(kosong)") + " (pakai rename | move | delete | rename-category | tier)");
}
