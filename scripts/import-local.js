// Impor paket dari repo app lokal (data/manifest.js + data/packages + images/packages)
// ke bank. Dipakai sekali untuk memindahkan paket yang sudah ada di repo app.
//
// Usage:
//   npm run import -- "D:\Repo\Soalin\Soalin" --tier reguler
//   npm run import -- "D:\Repo\Soalin-Premium" --tier premium
//
// Id paket dipertahankan (reguler) supaya progres belajar di app tidak hilang.
import fs from "fs";
import path from "path";
import { fileURLToPath, pathToFileURL } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const TIERS = ["reguler", "premium"];

function fail(msg) {
  console.error("Error: " + msg);
  console.error('Usage: npm run import -- "D:\\path\\ke\\repo-app" --tier reguler|premium');
  process.exit(1);
}

const argv = process.argv.slice(2);
const appDir = argv[0] ? path.resolve(argv[0]) : "";
const tierAt = argv.indexOf("--tier");
const tier = tierAt >= 0 ? (argv[tierAt + 1] || "") : "";

if (!appDir) fail("folder repo app belum diisi");
if (!fs.existsSync(appDir)) fail(`folder tidak ada: ${appDir}`);
if (!TIERS.includes(tier)) fail("--tier harus reguler atau premium");

const manifestPath = path.join(appDir, "data", "manifest.js");
if (!fs.existsSync(manifestPath)) fail(`data\\manifest.js tidak ada di ${appDir} (tidak ada paket untuk diimpor)`);
const { packages } = await import(pathToFileURL(manifestPath).href);
if (!Array.isArray(packages) || packages.length === 0) fail("manifest.js tidak berisi paket");

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

fs.mkdirSync(path.join(ROOT, "packages"), { recursive: true });
const entries = [];
for (const p of packages) {
  const src = path.join(appDir, p.file);
  if (!fs.existsSync(src)) {
    console.warn(`  SKIP ${p.id} (file tidak ada: ${p.file})`);
    continue;
  }
  const mod = await import(pathToFileURL(src).href);
  const slug = slugOf(p.id);
  let questions = Array.isArray(mod.questions) ? mod.questions : [];
  if (slug !== p.id) questions = remapImages(questions, `images/packages/${p.id}/`, `images/packages/${slug}/`);

  const rel = `packages/${slug}.json`;
  fs.writeFileSync(path.join(ROOT, rel), JSON.stringify({ id: slug, tier, title: p.title, category: p.category, questions }, null, 2));
  entries.push({ id: slug, tier, title: p.title, category: p.category, count: questions.length, file: rel });

  const imgSrc = path.join(appDir, "images", "packages", p.id);
  if (fs.existsSync(imgSrc)) {
    fs.cpSync(imgSrc, path.join(ROOT, "images", "packages", slug), { recursive: true });
  }
  console.log(`  ${slug} (${questions.length} soal)`);
}

if (entries.length === 0) fail("tidak ada paket yang bisa diimpor");

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

console.log(`\n${entries.length} paket tier "${tier}" diimpor (total di index: ${all.length}).`);
console.log("Lanjut: git add . ; git commit -m \"...\" ; git push origin main");
