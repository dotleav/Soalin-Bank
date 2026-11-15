// Crop, rotasi, dan flip tiap gambar dari XML docx, dalam urutan dokumen.
// Urutannya harus sama dengan urutan gambar yang dibaca mammoth, jadi gambar
// VML (<w:pict>) ikut dihitung walau tanpa crop.
const NO_TRANSFORM = { crop: { l: 0, t: 0, r: 0, b: 0 }, hasCrop: false, rotDeg: 0, flipH: false, flipV: false };

export function extractDrawingTransforms(documentXml) {
  const transforms = [];
  const drawingRe = /<w:drawing>([\s\S]*?)<\/w:drawing>|<w:pict>([\s\S]*?)<\/w:pict>/g;
  let dm;
  while ((dm = drawingRe.exec(documentXml)) !== null) {
    // VML (<w:pict>): hanya dihitung bila berisi gambar, tanpa crop/rotasi.
    if (dm[2] !== undefined) {
      if (/<v:imagedata\b/.test(dm[2])) transforms.push(NO_TRANSFORM);
      continue;
    }
    const block = dm[1];

    // Gambar yang cuma di-link (bukan embed) tidak punya file lokal — lewati.
    const embedMatch = block.match(/<a:blip\b[^>]*\br:embed="([^"]+)"/);
    if (!embedMatch) {
      // Gambar tertaut (r:link) tetap dihitung mammoth, jadi ikut urutan tanpa crop.
      if (/<a:blip\b[^>]*\br:link="/.test(block)) transforms.push(NO_TRANSFORM);
      continue;
    }

    // Crop: <a:srcRect l=".." t=".." r=".." b=".."/> — satuan: perseribu persen
    // (100000 = 100%). Atribut yang tidak ada dianggap 0 (tidak di-crop dari sisi itu).
    let crop = { l: 0, t: 0, r: 0, b: 0 };
    const srcRectMatch = block.match(/<a:srcRect\b([^/]*)\/>/);
    if (srcRectMatch) {
      const attrs = srcRectMatch[1];
      const get = (name) => {
        const m = attrs.match(new RegExp(`\\b${name}="(-?\\d+)"`));
        return m ? Math.max(0, parseInt(m[1], 10) / 100000) : 0;
      };
      crop = { l: get("l"), t: get("t"), r: get("r"), b: get("b") };
    }
    const hasCrop = crop.l > 0 || crop.t > 0 || crop.r > 0 || crop.b > 0;

    // Rotasi + flip ada di <a:xfrm> (satuan rot: perenampuluh ribu derajat, searah jarum jam).
    let rotDeg = 0;
    let flipH = false;
    let flipV = false;
    const xfrmMatch = block.match(/<a:xfrm\b([^>]*)>/);
    if (xfrmMatch) {
      const attrs = xfrmMatch[1];
      const rotMatch = attrs.match(/\brot="(-?\d+)"/);
      if (rotMatch) rotDeg = parseInt(rotMatch[1], 10) / 60000;
      flipH = /\bflipH="1"/.test(attrs);
      flipV = /\bflipV="1"/.test(attrs);
    }

    transforms.push({ crop, hasCrop, rotDeg, flipH, flipV });
  }
  return transforms;
}
