// Seimbangkan huruf kunci per paket: bila jumlah kunci suatu huruf sudah melebihi
// kuota (ceil(soal/5)), isi dua opsi ditukar dan kunci pindah ke huruf yang masih kosong.
// Soal yang bergantung pada huruf, gambar, atau opsi "semua/tidak ada" tidak disentuh.
// Usage: node scripts/balance-answers.js [--apply]   (tanpa --apply hanya lapor)
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const LETTERS = ["A", "B", "C", "D", "E"];
const RISKY_WORDS = /semua|tidak ada|keduanya|seluruh/i;
const RISKY_LETTERS = /\b[A-E]\s+([Dd]an|[Aa]tau)\b|\b([Dd]an|[Aa]tau)\s+[A-E]\b/;
const LETTER_REF = /\b([Oo]psi|[Pp]ilihan|[Hh]uruf|[Jj]awaban)\s+[A-E]\b|\b[A-E]\)|\b[A-E]:\s/;

export function eligible(q) {
  if (q.isBroken || q.isIsian || !LETTERS.includes(q.answer)) return false;
  const opts = q.options || {};
  if (Object.keys(opts).length !== 5 || LETTERS.some((l) => !(l in opts))) return false;
  if ((q.questionImages || []).length) return false; // gambar soal bisa berisi label A-E
  if (Object.values(opts).some((t) => RISKY_WORDS.test(t) || RISKY_LETTERS.test(t) || /^\s*[A-E]\s*$/.test(t))) return false;
  return !LETTER_REF.test(q.question || "") && !LETTER_REF.test(q.explanation || "");
}

export function balance(questions) {
  const els = questions.filter(eligible);
  const cap = Math.ceil(els.length / 5);
  const count = Object.fromEntries(LETTERS.map((l) => [l, 0]));
  let moved = 0;
  for (const q of els) {
    if (count[q.answer] < cap) {
      count[q.answer] += 1;
      continue;
    }
    const target = LETTERS.filter((l) => count[l] < cap)
      .sort((a, b) => count[a] - count[b] || a.localeCompare(b))[0];
    const o = q.options;
    [o[q.answer], o[target]] = [o[target], o[q.answer]];
    q.answer = target;
    count[target] += 1;
    moved += 1;
  }
  return { moved, base: els.length, cap };
}

if (process.argv[1]?.endsWith("balance-answers.js")) {
  const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const apply = process.argv.includes("--apply");
  const dir = path.join(ROOT, "packages");
  for (const f of fs.readdirSync(dir).filter((n) => n.endsWith(".json")).sort()) {
    const file = path.join(dir, f);
    const raw = fs.readFileSync(file, "utf8");
    const data = JSON.parse(raw);
    const r = balance(data.questions);
    if (!r.moved) continue;
    console.log(`${f}: ${r.moved} kunci dipindah (kuota ${r.cap} per huruf dari ${r.base} soal)`);
    if (apply) fs.writeFileSync(file, JSON.stringify(data, null, 2) + (raw.endsWith("\n") ? "\n" : ""));
  }
  if (!apply) console.log("Dry run. Tambah --apply untuk menulis.");
}
