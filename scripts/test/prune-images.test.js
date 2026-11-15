// Jalankan: node --test scripts/test/prune-images.test.js
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { findUnused } from "../prune-images.js";

test("hanya file yang tidak dirujuk paket yang ditandai, stacks dilewati", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "prune-"));
  const put = (rel, text = "x") => { fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true }); fs.writeFileSync(path.join(root, rel), text); };
  put("packages/x.json", JSON.stringify({ questions: [{ questionImages: ["images/packages/a/1.png"] }] }));
  put("images/packages/a/1.png");
  put("images/packages/a/2.png");
  put("images/packages/stacks/s.png");
  assert.deepEqual(findUnused(root), ["images/packages/a/2.png"]);
});
