# Soalin Bank

Bank paket soal untuk app Soalin.

- `packages/*.json`: soal per paket. `index.json`: daftar paket.
- `images/packages/<id>/`: gambar soal per paket. `images/packages/stacks/`: tumpukan gambar MRI (`stacks.json`).

Perintah (jalankan dari folder ini):

- Tambah paket dari docx: `npm run add -- "file.docx" --tier reguler --category "Blok 2E"`. Atau pakai `bank-gui.ps1`.
- Seimbangkan huruf kunci: `npm run balance` (lapor saja), lalu `npm run balance -- --apply`.
- Hapus gambar yang tidak dirujuk: `npm run prune` (lapor saja), lalu `npm run prune -- --apply`.
- Tes: `npm test`.

Id paket adalah kunci progres belajar di app. Jangan ganti id saat mengubah paket.
