import fs from "fs";
import { HL_MARK } from "./highlight.js";

// Baca teks PDF per baris (pakai koordinat y), lalu gabungkan baris lanjutan.
// Baris yang berada di dalam area highlight diberi penanda HL_MARK di awal.
const PDF_START_RE = /^(\d+[.)]\s|[A-Ea-e][.)]\s|Kunci|Jawaban|Answer|Key|Correct|Penjelasan|Explanation|Gambar\s+Penjelasan|Sumber\s*:|ID\s*:|Kategori|Category|Bagian\s+\d)/i;

// Matriks PDF [a b c d e f]: m1 lalu m2 (CTM' = M × CTM).
function pdfMulM(m1, m2) {
  return [
    m1[0] * m2[0] + m1[1] * m2[2], m1[0] * m2[1] + m1[1] * m2[3],
    m1[2] * m2[0] + m1[3] * m2[2], m1[2] * m2[1] + m1[3] * m2[3],
    m1[4] * m2[0] + m1[5] * m2[2] + m2[4], m1[4] * m2[1] + m1[5] * m2[3] + m2[5],
  ];
}

// Kotak [x1,y1,x2,y2] yang sudah dikenai matriks m (hasilnya kotak sumbu-sejajar).
function pdfTransformBox(b, m) {
  const pts = [[b[0], b[1]], [b[2], b[1]], [b[0], b[3]], [b[2], b[3]]].map(([x, y]) => [
    m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5],
  ]);
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]);
  return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
}

// Kotak highlight di satu halaman: anotasi bertipe "Highlight" + area berwarna
// (gaya highlighter yang digambar langsung ke halaman, misal dari Word).
// OPS = konstanta operator pdf.js (pdfjs.OPS).
async function pdfHighlightRects(page, OPS) {
  const rects = [];
  try {
    for (const a of await page.getAnnotations()) {
      if (a.subtype === "Highlight" && a.rect) rects.push(a.rect);
    }
  } catch { /* anotasi tidak terbaca → tetap cek warna area */ }
  const ol = await page.getOperatorList();
  let ctm = [1, 0, 0, 1, 0, 0], stack = [], fill = [0, 0, 0], box = null;
  const isColored = ([r, g, b]) => Math.max(r, g, b) - Math.min(r, g, b) > 40;
  for (let i = 0; i < ol.fnArray.length; i++) {
    const f = ol.fnArray[i], a = ol.argsArray[i];
    if (f === OPS.save) stack.push(ctm.slice());
    else if (f === OPS.restore) ctm = stack.pop() || [1, 0, 0, 1, 0, 0];
    else if (f === OPS.transform) ctm = pdfMulM(a, ctm);
    else if (f === OPS.setFillRGBColor) fill = [a[0], a[1], a[2]];
    else if (f === OPS.setFillGray) { const g = a[0] * 255; fill = [g, g, g]; }
    else if (f === OPS.constructPath) box = a[2] ? pdfTransformBox(a[2], ctm) : null;
    else if (f === OPS.fill || f === OPS.eoFill) {
      if (box && isColored(fill) && box[3] - box[1] < 40) rects.push(box);
      box = null;
    } else if (f === OPS.endPath) box = null;
  }
  return rects;
}

// items per halaman + kotak highlight per halaman → baris teks (dengan HL_MARK bila di-highlight).
function pdfLinesFromPages(pages, rectsPerPage) {
  const lines = [];
  pages.forEach((items, pi) => {
    const rects = (rectsPerPage && rectsPerPage[pi]) || [];
    const inHi = (x, y) => rects.some(([x1, y1, x2, y2]) => x >= x1 - 1 && x <= x2 + 1 && y >= y1 - 1 && y <= y2 + 1);
    const pts = items
      .filter((it) => it.str && it.str.trim())
      .map((it) => ({
        s: it.str, x: it.transform[4], y: it.transform[5], w: it.width || 0,
        hl: inHi(it.transform[4] + (it.width || 0) / 2, it.transform[5] + (it.height || 8) / 2),
      }))
      .sort((a, b) => b.y - a.y || a.x - b.x);
    let row = [], rowY = null;
    const flush = () => {
      if (!row.length) return;
      row.sort((a, b) => a.x - b.x);
      let text = "", endX = null;
      for (const p of row) {
        if (endX !== null && p.x - endX > 1.5) text += " ";
        text += p.s;
        endX = p.x + p.w;
      }
      const clean = text.replace(/\s+/g, " ").trim();
      if (clean) lines.push({ text: clean, hl: row.some((p) => p.hl) });
      row = [];
    };
    for (const p of pts) {
      if (rowY === null || Math.abs(p.y - rowY) > 2) { flush(); rowY = p.y; }
      row.push(p);
    }
    flush();
  });
  // Baris yang bukan penanda (nomor soal, opsi, Kunci, Penjelasan, dst.) dianggap lanjutan
  // dari baris sebelumnya — jadi teks soal/opsi/penjelasan yang turun ke baris baru tetap utuh.
  const out = [];
  for (const l of lines) {
    if (out.length && !PDF_START_RE.test(l.text)) out[out.length - 1].text += " " + l.text;
    else out.push({ ...l });
  }
  return out.map((l) => (l.hl ? HL_MARK : "") + l.text);
}

// ── Node: baca PDF (pdfjs-dist) jadi HTML sederhana, satu <p> per baris ──
// Output dipakai sebagai pengganti hasil mammoth, jadi parser soal yang sama bisa dipakai.
// Gambar di PDF belum diekstrak (hanya teks). Teks di area highlight diberi penanda HL_MARK.
export async function pdfToHtml(pdfPath) {
  const pdfjs = await import("pdfjs-dist/legacy/build/pdf.mjs");
  const data = new Uint8Array(fs.readFileSync(pdfPath));
  const doc = await pdfjs.getDocument({ data, useSystemFonts: true }).promise;
  const pages = [], rects = [];
  for (let p = 1; p <= doc.numPages; p++) {
    const page = await doc.getPage(p);
    pages.push((await page.getTextContent()).items);
    rects.push(await pdfHighlightRects(page, pdfjs.OPS));
  }
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return pdfLinesFromPages(pages, rects)
    .map((l) => (/^Bagian\s+\d/i.test(l.replace(HL_MARK, "")) ? `<h2>${esc(l)}</h2>` : `<p>${esc(l)}</p>`))
    .join("\n");
}
