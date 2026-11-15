// Jalankan: node --test scripts/test/docx-transforms.test.js
import test from "node:test";
import assert from "node:assert/strict";
import { extractDrawingTransforms } from "../docx-transforms.js";

const drawing = (srcRect = "") =>
  `<w:drawing><wp:inline><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:embed="rId1"/>${srcRect}` +
  `</pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>`;
const pictImage = `<w:pict><v:shape><v:imagedata r:id="rId2"/></v:shape></w:pict>`;
const pictTextbox = `<w:pict><v:textbox><w:txbxContent>Teks</w:txbxContent></v:textbox></w:pict>`;
const chart = `<w:drawing><wp:inline><a:graphic><c:chart/></a:graphic></wp:inline></w:drawing>`;

test("crop tiap gambar tetap cocok dengan urutannya walau ada gambar VML di tengah", () => {
  const xml = `<w:body>${drawing()}${pictImage}${pictTextbox}${chart}${drawing('<a:srcRect t="20000"/>')}</w:body>`;
  const t = extractDrawingTransforms(xml);
  assert.equal(t.length, 3);
  assert.equal(t[0].hasCrop, false);
  assert.equal(t[1].hasCrop, false);
  assert.equal(t[2].hasCrop, true);
  assert.equal(t[2].crop.t, 0.2);
});

test("gambar tertaut (r:link) dihitung tanpa crop, supaya urutan tetap sama dengan mammoth", () => {
  const linked = `<w:drawing><wp:inline><a:graphic><a:graphicData><pic:pic><pic:blipFill><a:blip r:link="rId9"/>` +
    `<a:srcRect l="50000"/></pic:blipFill></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>`;
  const t = extractDrawingTransforms(`${linked}${drawing('<a:srcRect t="50000"/>')}`);
  assert.equal(t.length, 2);
  assert.equal(t[0].hasCrop, false);
  assert.equal(t[1].crop.t, 0.5);
});
