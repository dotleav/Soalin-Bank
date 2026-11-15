// Jalankan: node --test scripts/test/balance-answers.test.js
import test from "node:test";
import assert from "node:assert/strict";
import { balance } from "../balance-answers.js";

const mk = (text, extra = {}) => ({
  question: text, answer: "A", explanation: "Penjelasan.",
  options: { A: "a1", B: "b1", C: "c1", D: "d1", E: "e1" }, questionImages: [], explanationImages: [], ...extra,
});

test("kunci yang menumpuk di satu huruf tersebar, dan teks kunci ikut pindah", () => {
  const qs = Array.from({ length: 10 }, (_, i) => mk(`Soal ${i} apa?`));
  const r = balance(qs);
  const counts = Object.fromEntries("ABCDE".split("").map((l) => [l, qs.filter((q) => q.answer === l).length]));
  assert.deepEqual(Object.values(counts), [2, 2, 2, 2, 2]);
  assert.equal(r.moved, 8);
  for (const q of qs) assert.equal(q.options[q.answer][0], q.options[q.answer][0].toLowerCase()); // kunci tetap berisi teks yang benar
  assert.ok(qs.every((q) => ["a1", "b1", "c1", "d1", "e1"].includes(q.options[q.answer])));
});

test("soal dengan opsi 'semua' atau rujukan huruf tidak disentuh", () => {
  const semua = mk("Pilih yang tepat?", { options: { A: "Semua benar", B: "b1", C: "c1", D: "d1", E: "e1" } });
  const huruf = mk("Yang dimaksud huruf C adalah?");
  const before = JSON.stringify([semua, huruf]);
  balance([semua, huruf]);
  assert.equal(JSON.stringify([semua, huruf]), before);
});
