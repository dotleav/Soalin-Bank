// Tambah paket soal dari file .docx langsung ke bank (convert + publish sekaligus).
//
// Usage:
//   npm run add -- "D:\Soal\File.docx" --tier reguler --category "Blok 2E" --name "Batch 1"
//   npm run add -- "D:\Soal\File.docx" --tier premium --category "Blok 3"
//
// --tier     wajib: reguler | premium
// --category wajib: kategori di menu app
// --name     opsional: nama paket (default: nama file docx)
//
// Paket ditulis ke packages/<slug>.json + images/packages/<slug>/, dan index.json
// digabung (paket lain tidak ikut hilang). Setelah itu: git add, commit, push.
import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath, pathToFileURL } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const STAGING = path.join(ROOT, "_staging");
const TIERS = ["reguler", "premium"];

function fail(msg) {
  if (msg) console.error("Error: " + msg);
  console.error('Usage: npm run add -- "file.docx" --tier reguler|premium --category "Nama Kategori" [--name "Nama Paket"]');
  process.exit(1);
}

const argv = process.argv.slice(2);
const flag = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 ? (argv[i + 1] || "").trim() : "";
};
const docx = argv[0];
const tier = flag("--tier");
const category = flag("--category");
const name = flag("--name");

if (!docx || docx.startsWith("--")) fail("file .docx belum diisi");
if (!fs.existsSync(docx)) fail(`file tidak ada: ${docx}`);
if (!TIERS.includes(tier)) fail("--tier harus reguler atau premium");
if (!category) fail("--category wajib diisi");

// Reguler memakai id apa adanya; tier lain diberi prefix supaya tidak bentrok.
const slugOf = (id) => (tier === "reguler" ? id : `${tier}__${id}`);

function remapImages(v, from, to) {
  if (typeof v === "string") return v.startsWith(from) ? to + v.slice(from.length) : v;
  if (Array.isArray(v)) return v.map((x) => remapImages(x, from, to));
  if (v && typeof v === "object") {
    const o = {};
    for (const k in v) o[k] = remapImages(v[k], from, to);
    return o;
  }
  return v;
}

// 1) Convert docx ke folder sementara.
fs.rmSync(STAGING, { recursive: true, force: true });
const conv = spawnSync(
  process.execPath,
  [path.join(ROOT, "scripts", "convert-docx.js"), path.resolve(docx), category, name],
  { cwd: ROOT, stdio: "inherit" }
);
if (conv.status !== 0) {
  fs.rmSync(STAGING, { recursive: true, force: true });
  process.exit(conv.status || 1);
}

// 2) Publish hasil convert ke folder bank.
const manifestPath = path.join(STAGING, "data", "manifest.js");
if (!fs.existsSync(manifestPath)) fail("convert tidak menghasilkan paket");
const { packages } = await import(pathToFileURL(manifestPath).href);

fs.mkdirSync(path.join(ROOT, "packages"), { recursive: true });
const entries = [];
for (const p of packages) {
  const mod = await import(pathToFileURL(path.join(STAGING, p.file)).href);
  const slug = slugOf(p.id);
  let questions = Array.isArray(mod.questions) ? mod.questions : [];
  if (slug !== p.id) questions = remapImages(questions, `images/packages/${p.id}/`, `images/packages/${slug}/`);

  const rel = `packages/${slug}.json`;
  fs.writeFileSync(path.join(ROOT, rel), JSON.stringify({ id: slug, tier, title: p.title, category: p.category, questions }, null, 2));
  entries.push({ id: slug, tier, title: p.title, category: p.category, count: questions.length, file: rel });

  const imgSrc = path.join(STAGING, "images", "packages", p.id);
  if (fs.existsSync(imgSrc)) {
    fs.cpSync(imgSrc, path.join(ROOT, "images", "packages", slug), { recursive: true });
  }
  console.log(`  ${slug} (${questions.length} soal)`);
}

// 3) Gabungkan index.json: entri tier ini dengan id sama diganti, sisanya dibiarkan.
const indexPath = path.join(ROOT, "index.json");
let prev = [];
if (fs.existsSync(indexPath)) {
  try {
    prev = JSON.parse(fs.readFileSync(indexPath, "utf-8")).packages || [];
  } catch {
    console.warn("  index.json lama tidak terbaca, ditimpa.");
  }
}
const keep = prev.filter((e) => !entries.some((n) => n.id === e.id && (e.tier || "reguler") === tier));
const all = [...keep, ...entries].sort(
  (a, b) => (a.category || "").localeCompare(b.category || "") || (a.title || "").localeCompare(b.title || "")
);
fs.writeFileSync(indexPath, JSON.stringify({ version: 1, generatedAt: new Date().toISOString(), packages: all }, null, 2));

fs.rmSync(STAGING, { recursive: true, force: true });
console.log(`\nSelesai: ${entries.length} paket tier "${tier}" ditambahkan (total di index: ${all.length}).`);
console.log("Lanjut: git add . ; git commit -m \"...\" ; git push origin main");
