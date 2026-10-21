# bank-gui.ps1 - Kelola dan tambah paket soal di Soalin-Bank lewat klik (tanpa terminal).
# Dipanggil dari soalin-bank.bat. Butuh Node.js (convert & kelola) dan Git (opsional, untuk push).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $root "index.json"
Set-Location $root

# --- Warna & font ---

$cHeader = [System.Drawing.Color]::FromArgb(17, 42, 74)
$cHeadSub = [System.Drawing.Color]::FromArgb(147, 197, 253)
$cAccent = [System.Drawing.Color]::FromArgb(37, 99, 235)
$cAccentDk = [System.Drawing.Color]::FromArgb(29, 78, 216)
$cText   = [System.Drawing.Color]::FromArgb(17, 24, 39)
$cSoft   = [System.Drawing.Color]::FromArgb(55, 65, 81)
$cMuted  = [System.Drawing.Color]::FromArgb(107, 114, 128)
$cBorder = [System.Drawing.Color]::FromArgb(209, 213, 219)
$cDanger = [System.Drawing.Color]::FromArgb(190, 18, 60)
$cReg    = [System.Drawing.Color]::FromArgb(37, 99, 235)
$cPrem   = [System.Drawing.Color]::FromArgb(124, 58, 237)
$cKat    = [System.Drawing.Color]::FromArgb(75, 85, 99)
$cBg     = [System.Drawing.Color]::FromArgb(243, 244, 246)
$cCard   = [System.Drawing.Color]::White
$cLogBg  = [System.Drawing.Color]::FromArgb(17, 24, 39)
$cLogFg  = [System.Drawing.Color]::FromArgb(229, 231, 235)
$cOk     = [System.Drawing.Color]::FromArgb(21, 128, 61)
$cErr    = [System.Drawing.Color]::FromArgb(190, 18, 60)
$cInfo   = [System.Drawing.Color]::FromArgb(37, 99, 235)
$cWhite  = [System.Drawing.Color]::White

$fontUI    = New-Object System.Drawing.Font("Segoe UI", 10)
$fontSmall = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontHead  = New-Object System.Drawing.Font("Segoe UI", 12.5, [System.Drawing.FontStyle]::Bold)
$fontTier  = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$fontBadge = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)

# --- Data ---

function Read-Index {
    if (-not (Test-Path $indexPath)) { return @() }
    try {
        $idx = Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($idx.packages)
    } catch {
        return @()
    }
}

function Get-Categories {
    return @(Read-Index | ForEach-Object { $_.category } | Where-Object { $_ } | Sort-Object -Unique)
}

# --- Util ---

# Label & tombol WinForms memakai & sebagai tanda shortcut; "&" di teks harus digandakan.
function Mn($s) { return ([string]$s) -replace '&', '&&' }

function Has-Text($s, $q) {
    return ([string]$s).IndexOf($q, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Add-Log($msg) {
    $txtLog.AppendText([string]$msg + "`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Status($msg, $kind) {
    $lblStatus.Text = $msg
    switch ($kind) {
        "ok"    { $lblStatus.ForeColor = $cOk }
        "error" { $lblStatus.ForeColor = $cErr }
        "info"  { $lblStatus.ForeColor = $cInfo }
        default { $lblStatus.ForeColor = $cMuted }
    }
}

function Set-Busy($busy) {
    $tabs.Enabled = -not $busy
    $btnOpen.Enabled = -not $busy
    $form.UseWaitCursor = $busy
    $form.Text = if ($busy) { "Soalin Bank - memproses..." } else { "Soalin Bank" }
    if ($busy) { Set-Status "Sedang memproses..." "info" }
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Info($text) {
    [void][System.Windows.Forms.MessageBox]::Show($text, "Soalin Bank")
}

function Confirm-Action($text) {
    $ans = [System.Windows.Forms.MessageBox]::Show($text, "Soalin Bank", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($ans -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Run-Tool($exe, $toolArgs) {
    $out = & $exe @toolArgs 2>&1
    $code = $LASTEXITCODE
    foreach ($line in $out) { Add-Log $line.ToString() }
    return $code
}

function Commit-Changes($msg) {
    if (-not $chkPush.Checked) {
        Add-Log "Belum di-push. Centang 'Commit dan push' atau jalankan git manual."
        return $true
    }
    Add-Log ""
    Add-Log "Commit dan push..."
    [void](Run-Tool "git" @("add", "-A"))
    [void](Run-Tool "git" @("commit", "-m", $msg))
    $code = Run-Tool "git" @("push", "origin", "main")
    if ($code -eq 0) {
        Add-Log "Push berhasil. Tunggu 1-5 menit sebelum app membacanya."
        return $true
    }
    Add-Log "Push gagal, cek pesan di atas."
    return $false
}

function Style-Button($b, $kind) {
    $b.FlatStyle = "Flat"
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Font = $fontBold
    switch ($kind) {
        "primary" {
            $b.BackColor = $cAccent; $b.ForeColor = $cWhite
            $b.FlatAppearance.BorderSize = 0
            $b.FlatAppearance.MouseOverBackColor = $cAccentDk
        }
        "danger" {
            $b.BackColor = $cWhite; $b.ForeColor = $cDanger
            $b.FlatAppearance.BorderColor = $cDanger
            $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
        }
        default {
            $b.BackColor = $cWhite; $b.ForeColor = $cText
            $b.FlatAppearance.BorderColor = $cBorder
            $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(239, 246, 255)
        }
    }
}

function Make-Label($text, $x, $y, $w, $h, $font, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    if ($font) { $l.Font = $font }
    if ($color) { $l.ForeColor = $color }
    return $l
}

# --- Tab Kelola ---

function Refresh-Categories {
    $cats = @(Get-Categories)
    $cmbCategory.Items.Clear()
    $cmbCategory.Items.AddRange([object[]]$cats)
    $cmbMove.Items.Clear()
    $cmbMove.Items.AddRange([object[]]$cats)
}

function Get-SelectedId {
    $n = $tree.SelectedNode
    if ($n -and $n.Tag -and $n.Tag.kind -eq "package") { return $n.Tag.id }
    return $null
}

function Refresh-Tree($keepId) {
    $filter = $txtSearch.Text.Trim()
    $all = @(Read-Index)
    $pkgs = @($all | Where-Object { (-not $filter) -or (Has-Text $_.title $filter) -or (Has-Text $_.category $filter) })

    $total = 0
    foreach ($p in $all) { $total += [int]$p.count }
    if ($filter) { $lblStats.Text = "" + $pkgs.Count + " cocok dari " + $all.Count + " paket" }
    else { $lblStats.Text = "" + $all.Count + " paket   |   " + $total + " soal" }

    $tree.BeginUpdate()
    $tree.Nodes.Clear()
    foreach ($tier in @("reguler", "premium")) {
        $tierPkgs = @($pkgs | Where-Object { $_.tier -eq $tier })
        if ($tier -eq "reguler") { $tierLabel = "REGULER" }
        else { $tierLabel = "PREMIUM" }
        $tierColor = if ($tier -eq "reguler") { $cReg } else { $cPrem }

        $tierNode = New-Object System.Windows.Forms.TreeNode ($tierLabel + "   " + $tierPkgs.Count)
        $tierNode.Tag = @{ kind = "tier"; tier = $tier; label = $tierLabel }
        $tierNode.NodeFont = $fontTier
        $tierNode.ForeColor = $tierColor

        $cats = @($tierPkgs | ForEach-Object { $_.category } | Where-Object { $_ } | Sort-Object -Unique)
        foreach ($cat in $cats) {
            $catPkgs = @($tierPkgs | Where-Object { $_.category -eq $cat } | Sort-Object title)
            $catNode = New-Object System.Windows.Forms.TreeNode ($cat + "   " + $catPkgs.Count)
            $catNode.Tag = @{ kind = "category"; name = $cat; tier = $tier; packages = $catPkgs.Count }
            $catNode.NodeFont = $fontBold
            $catNode.ForeColor = $cSoft
            foreach ($p in $catPkgs) {
                $n = New-Object System.Windows.Forms.TreeNode ($p.title + "    " + $p.count + " soal")
                $n.Tag = @{ kind = "package"; id = $p.id; title = $p.title; category = $p.category; tier = $p.tier; count = $p.count }
                $n.ForeColor = $cText
                [void]$catNode.Nodes.Add($n)
            }
            [void]$tierNode.Nodes.Add($catNode)
        }
        [void]$tree.Nodes.Add($tierNode)
    }
    if ($pkgs.Count -eq 0) {
        $none = New-Object System.Windows.Forms.TreeNode "Tidak ada paket yang cocok."
        $none.Tag = @{ kind = "none" }
        $none.ForeColor = $cMuted
        [void]$tree.Nodes.Add($none)
    }
    $tree.ExpandAll()
    $tree.EndUpdate()

    $target = $null
    if ($keepId) { $target = Find-Node $tree.Nodes $keepId }
    if ($target) { $tree.SelectedNode = $target }
    elseif ($tree.Nodes.Count -gt 0) { $tree.SelectedNode = $tree.Nodes[0] }
    Update-Details
}

function Find-Node($nodes, $id) {
    foreach ($n in $nodes) {
        if ($n.Tag -and $n.Tag.kind -eq "package" -and $n.Tag.id -eq $id) { return $n }
        $hit = Find-Node $n.Nodes $id
        if ($hit) { return $hit }
    }
    return $null
}

function Set-Badge($text, $color) {
    if (-not $text) { $lblBadge.Visible = $false; return }
    $lblBadge.Visible = $true
    $lblBadge.Text = $text
    $lblBadge.BackColor = $color
}

function Update-Details {
    $t = if ($tree.SelectedNode) { $tree.SelectedNode.Tag } else { $null }
    $kind = if ($t) { $t.kind } else { "" }
    $isPkg = ($kind -eq "package")

    $btnRename.Enabled = $isPkg
    $cmbMove.Enabled = $isPkg
    $btnMove.Enabled = $isPkg
    $rbMReg.Enabled = $isPkg
    $rbMPrem.Enabled = $isPkg
    $btnTier.Enabled = $isPkg
    $btnDelete.Enabled = $isPkg
    $btnRenameCat.Enabled = ($kind -eq "category")

    switch ($kind) {
        "package" {
            $tierText = if ($t.tier -eq "premium") { "PREMIUM" } else { "REGULER" }
            $tierColor = if ($t.tier -eq "premium") { $cPrem } else { $cReg }
            Set-Badge $tierText $tierColor
            $lblHead.Text = Mn $t.title
            $lblMeta.Text = "Kategori: " + (Mn $t.category) + "`r`n" + $t.count + " soal`r`nID: " + $t.id
            $cmbMove.Text = $t.category
            $rbMPrem.Checked = ($t.tier -eq "premium")
            $rbMReg.Checked = -not $rbMPrem.Checked
        }
        "category" {
            Set-Badge "KATEGORI" $cKat
            $lblHead.Text = Mn $t.name
            $tierWord = if ($t.tier -eq "premium") { "Premium" } else { "Reguler" }
            $lblMeta.Text = "Tier: " + $tierWord + "`r`n" + $t.packages + " paket`r`n`r`nGanti nama kategori berlaku untuk semua paket di dalamnya, pada tier ini saja."
        }
        "tier" {
            $tierColor = if ($t.tier -eq "premium") { $cPrem } else { $cReg }
            Set-Badge ($t.tier.ToUpper()) $tierColor
            $lblHead.Text = $t.label
            if ($t.tier -eq "premium") { $lblMeta.Text = "Paket di sini tampil hanya di Soalin Premium." }
            else { $lblMeta.Text = "Paket di sini tampil di Soalin dan Premium." }
        }
        "none" {
            Set-Badge $null $null
            $lblHead.Text = "Tidak ada paket"
            $lblMeta.Text = "Ubah kata kunci pencarian untuk melihat paket lain."
        }
        default {
            Set-Badge $null $null
            $lblHead.Text = "Pilih paket atau kategori"
            $lblMeta.Text = "Double-klik paket untuk ganti nama.`r`nCtrl+F untuk mencari paket."
        }
    }
}

# Jalankan node scripts/manage.js. Dipanggil dari semua aksi kelola.
function Invoke-Manage($manageArgs, $commitMsg, $keepId = $null) {
    Set-Busy $true
    try {
        Add-Log ""
        Add-Log ("> manage " + ($manageArgs -join " "))
        $code = Run-Tool "node" (@("scripts/manage.js") + $manageArgs)
        if ($code -ne 0) {
            Set-Status "Gagal. Tidak ada perubahan." "error"
            Add-Log "GAGAL (kode $code)."
            return
        }
        Add-Log "Berhasil."
        if (Commit-Changes $commitMsg) { Set-Status "Berhasil: $commitMsg" "ok" }
        else { Set-Status "Perubahan tersimpan lokal, tapi push gagal." "error" }
    }
    catch {
        Set-Status "Error. Lihat log." "error"
        Add-Log ("ERROR: " + $_.Exception.Message)
    }
    finally {
        Refresh-Categories
        Refresh-Tree $keepId
        Set-Busy $false
    }
}

# --- Tab Tambah ---

function Add-DocxFiles($paths) {
    $skipped = 0
    $added = 0
    foreach ($f in @($paths)) {
        if ($f -notlike "*.docx") { $skipped++; continue }
        if (-not $lstFiles.Items.Contains($f)) { [void]$lstFiles.Items.Add($f); $added++ }
    }
    if ($added -gt 0) { Set-Status ("" + $lstFiles.Items.Count + " file siap dipublish.") "info" }
    if ($skipped -gt 0) { Show-Info ("" + $skipped + " file dilewati (hanya .docx yang diterima).") }
}

function Publish-Files {
    $category = $cmbCategory.Text.Trim()
    $files = @($lstFiles.Items)
    $tier = if ($rbPremium.Checked) { "premium" } else { "reguler" }
    $name = $txtName.Text.Trim()

    if ($files.Count -eq 0) { Show-Info "Pilih minimal satu file .docx."; return }
    if (-not $category) { Show-Info "Isi kategori dulu."; return }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Show-Info "Node.js belum terpasang. Install dari https://nodejs.org"; return
    }

    Set-Busy $true
    try {
        if (-not (Test-Path (Join-Path $root "node_modules"))) {
            Add-Log "Pertama kali: npm install (sekali saja)..."
            $code = Run-Tool "cmd.exe" @("/c", "npm", "install")
            if ($code -ne 0) { Set-Status "npm install gagal." "error"; Add-Log "npm install gagal."; return }
        }

        $ok = 0
        foreach ($f in $files) {
            Add-Log ""
            Add-Log "== $f"
            $toolArgs = @("scripts/add-package.js", $f, "--tier", $tier, "--category", $category)
            if ($files.Count -eq 1 -and $name) { $toolArgs += @("--name", $name) }
            $code = Run-Tool "node" $toolArgs
            if ($code -eq 0) { $ok++ } else { Add-Log "GAGAL (kode $code), lanjut file berikutnya." }
        }
        Add-Log ""
        Add-Log "Publish selesai: $ok dari $($files.Count) file berhasil."
        if ($ok -eq $files.Count) {
            $lstFiles.Items.Clear()
            $txtName.Text = ""
        }
        if ($ok -gt 0) {
            if (Commit-Changes "Tambah paket $tier - $category") { Set-Status "Publish: $ok dari $($files.Count) berhasil." "ok" }
            else { Set-Status "Publish berhasil, tapi push gagal." "error" }
        }
        else { Set-Status "Publish gagal. Lihat log." "error" }
    }
    catch {
        Set-Status "Error. Lihat log." "error"
        Add-Log ("ERROR: " + $_.Exception.Message)
    }
    finally {
        Refresh-Categories
        Refresh-Tree $null
        Set-Busy $false
    }
}

# --- Form ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Soalin Bank"
$form.ClientSize = New-Object System.Drawing.Size(1080, 800)
$form.MinimumSize = New-Object System.Drawing.Size(1000, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.Font = $fontUI
$form.BackColor = $cBg
$form.KeyPreview = $true

$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 12000
$tip.InitialDelay = 400

# Tabs (Fill) - ditambahkan pertama agar mengisi sisa ruang
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Fill"
$tabs.Font = $fontBold
$tabs.Padding = New-Object System.Drawing.Point(18, 6)

$tabManage = New-Object System.Windows.Forms.TabPage "Kelola paket"
$tabAdd = New-Object System.Windows.Forms.TabPage "Tambah paket"
$tabManage.BackColor = $cCard
$tabAdd.BackColor = $cCard
[void]$tabs.TabPages.Add($tabManage)
[void]$tabs.TabPages.Add($tabAdd)
$form.Controls.Add($tabs)

# -- Kelola: kiri = pencarian + tree (Fill), kanan = kolom tetap 340px
$pnlRight = New-Object System.Windows.Forms.Panel
$pnlRight.Dock = "Right"
$pnlRight.Width = 340
$pnlRight.BackColor = $cBg
$pnlRight.AutoScroll = $true
$pnlRight.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 12)
$tabManage.Controls.Add($pnlRight)

$pnlLeft = New-Object System.Windows.Forms.Panel
$pnlLeft.Dock = "Fill"
$pnlLeft.BackColor = $cCard
$pnlLeft.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 12)
$tabManage.Controls.Add($pnlLeft)

# Kiri: tree (Fill) dulu, lalu bar pencarian (Top)
$tree = New-Object System.Windows.Forms.TreeView
$tree.Dock = "Fill"
$tree.Font = $fontUI
$tree.BorderStyle = "FixedSingle"
$tree.HideSelection = $false
$tree.ShowLines = $false
$tree.FullRowSelect = $true
$tree.ItemHeight = 28
$tree.ShowNodeToolTips = $true
$tree.BackColor = $cWhite
$pnlLeft.Controls.Add($tree)

$searchBar = New-Object System.Windows.Forms.Panel
$searchBar.Dock = "Top"
$searchBar.Height = 66
$searchBar.Padding = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
$pnlLeft.Controls.Add($searchBar)

$lblSearch = Make-Label "Cari paket  (judul atau kategori)" 0 12 260 20 $fontSmall $cMuted
$searchBar.Controls.Add($lblSearch)

$hintSearch = Make-Label "Ctrl+F" 240 12 100 20 $fontSmall $cMuted
$hintSearch.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$hintSearch.Anchor = "Top, Right"
$hintSearch.Location = New-Object System.Drawing.Point(232, 12)
$searchBar.Controls.Add($hintSearch)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(0, 34)
$txtSearch.Size = New-Object System.Drawing.Size(332, 26)
$txtSearch.Font = $fontUI
$txtSearch.Anchor = "Top, Left, Right"
$searchBar.Controls.Add($txtSearch)

# -- Kanan: kartu Detail
$cardDetail = New-Object System.Windows.Forms.Panel
$cardDetail.Location = New-Object System.Drawing.Point(12, 12)
$cardDetail.Size = New-Object System.Drawing.Size(314, 178)
$cardDetail.BackColor = $cCard
$pnlRight.Controls.Add($cardDetail)

$lblDetailTitle = Make-Label "DETAIL" 16 12 200 18 $fontBadge $cMuted
$cardDetail.Controls.Add($lblDetailTitle)

$lblBadge = New-Object System.Windows.Forms.Label
$lblBadge.Location = New-Object System.Drawing.Point(16, 34)
$lblBadge.Size = New-Object System.Drawing.Size(90, 22)
$lblBadge.Font = $fontBadge
$lblBadge.ForeColor = $cWhite
$lblBadge.BackColor = $cReg
$lblBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblBadge.Visible = $false
$cardDetail.Controls.Add($lblBadge)

$lblHead = Make-Label "" 16 62 282 46 $fontHead $cText
$cardDetail.Controls.Add($lblHead)

$lblMeta = Make-Label "" 16 110 282 62 $fontSmall $cSoft
$cardDetail.Controls.Add($lblMeta)

# -- Kanan: kartu Ubah paket
$cardEdit = New-Object System.Windows.Forms.Panel
$cardEdit.Location = New-Object System.Drawing.Point(12, 202)
$cardEdit.Size = New-Object System.Drawing.Size(314, 268)
$cardEdit.BackColor = $cCard
$pnlRight.Controls.Add($cardEdit)

$lblEditTitle = Make-Label "UBAH PAKET" 16 12 200 18 $fontBadge $cMuted
$cardEdit.Controls.Add($lblEditTitle)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = "Ganti nama   (F2)"
$btnRename.Location = New-Object System.Drawing.Point(16, 34)
$btnRename.Size = New-Object System.Drawing.Size(282, 36)
Style-Button $btnRename "default"
$cardEdit.Controls.Add($btnRename)

$lblMove = Make-Label "Pindah ke kategori" 16 80 282 18 $fontSmall $cSoft
$cardEdit.Controls.Add($lblMove)

$cmbMove = New-Object System.Windows.Forms.ComboBox
$cmbMove.Location = New-Object System.Drawing.Point(16, 100)
$cmbMove.Size = New-Object System.Drawing.Size(282, 26)
$cmbMove.DropDownStyle = "DropDown"
$cardEdit.Controls.Add($cmbMove)

$btnMove = New-Object System.Windows.Forms.Button
$btnMove.Text = "Pindah kategori"
$btnMove.Location = New-Object System.Drawing.Point(16, 132)
$btnMove.Size = New-Object System.Drawing.Size(282, 36)
Style-Button $btnMove "default"
$cardEdit.Controls.Add($btnMove)

$lblTier = Make-Label "Tampil di" 16 178 282 18 $fontSmall $cSoft
$cardEdit.Controls.Add($lblTier)

$rbMReg = New-Object System.Windows.Forms.RadioButton
$rbMReg.Text = "Reguler"
$rbMReg.Location = New-Object System.Drawing.Point(16, 198)
$rbMReg.AutoSize = $true
$cardEdit.Controls.Add($rbMReg)

$rbMPrem = New-Object System.Windows.Forms.RadioButton
$rbMPrem.Text = "Premium saja"
$rbMPrem.Location = New-Object System.Drawing.Point(110, 198)
$rbMPrem.AutoSize = $true
$cardEdit.Controls.Add($rbMPrem)

$btnTier = New-Object System.Windows.Forms.Button
$btnTier.Text = "Terapkan tier"
$btnTier.Location = New-Object System.Drawing.Point(16, 222)
$btnTier.Size = New-Object System.Drawing.Size(282, 34)
Style-Button $btnTier "primary"
$cardEdit.Controls.Add($btnTier)

# -- Kanan: kartu Kategori & hapus
$cardDanger = New-Object System.Windows.Forms.Panel
$cardDanger.Location = New-Object System.Drawing.Point(12, 482)
$cardDanger.Size = New-Object System.Drawing.Size(314, 126)
$cardDanger.BackColor = $cCard
$pnlRight.Controls.Add($cardDanger)

$lblDangerTitle = Make-Label "KATEGORI DAN HAPUS" 16 12 250 18 $fontBadge $cMuted
$cardDanger.Controls.Add($lblDangerTitle)

$btnRenameCat = New-Object System.Windows.Forms.Button
$btnRenameCat.Text = "Ganti nama kategori"
$btnRenameCat.Location = New-Object System.Drawing.Point(16, 34)
$btnRenameCat.Size = New-Object System.Drawing.Size(282, 34)
Style-Button $btnRenameCat "default"
$cardDanger.Controls.Add($btnRenameCat)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Hapus paket   (Del)"
$btnDelete.Location = New-Object System.Drawing.Point(16, 76)
$btnDelete.Size = New-Object System.Drawing.Size(282, 34)
Style-Button $btnDelete "danger"
$cardDanger.Controls.Add($btnDelete)

# -- Tambah paket
$tabAdd.Padding = New-Object System.Windows.Forms.Padding(12)

$grpFiles = New-Object System.Windows.Forms.GroupBox
$grpFiles.Text = "1. File .docx  (bisa lebih dari satu, atau seret ke kotak)"
$grpFiles.Font = $fontBold
$grpFiles.Location = New-Object System.Drawing.Point(12, 12)
$grpFiles.Size = New-Object System.Drawing.Size(1030, 160)
$grpFiles.Anchor = "Top, Left, Right"
$tabAdd.Controls.Add($grpFiles)

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(16, 28)
$lstFiles.Size = New-Object System.Drawing.Size(860, 118)
$lstFiles.Anchor = "Top, Left, Right, Bottom"
$lstFiles.AllowDrop = $true
$lstFiles.IntegralHeight = $false
$lstFiles.Font = $fontUI
$lstFiles.BorderStyle = "FixedSingle"
$grpFiles.Controls.Add($lstFiles)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Pilih file..."
$btnAdd.Location = New-Object System.Drawing.Point(890, 28)
$btnAdd.Size = New-Object System.Drawing.Size(124, 36)
$btnAdd.Anchor = "Top, Right"
Style-Button $btnAdd "default"
$grpFiles.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Hapus dari daftar"
$btnRemove.Location = New-Object System.Drawing.Point(890, 72)
$btnRemove.Size = New-Object System.Drawing.Size(124, 36)
$btnRemove.Anchor = "Top, Right"
Style-Button $btnRemove "default"
$grpFiles.Controls.Add($btnRemove)

$grpTier = New-Object System.Windows.Forms.GroupBox
$grpTier.Text = "2. Tampil di"
$grpTier.Font = $fontBold
$grpTier.Location = New-Object System.Drawing.Point(12, 186)
$grpTier.Size = New-Object System.Drawing.Size(1030, 62)
$grpTier.Anchor = "Top, Left, Right"
$tabAdd.Controls.Add($grpTier)

$rbReguler = New-Object System.Windows.Forms.RadioButton
$rbReguler.Text = "Reguler (Soalin dan Premium)"
$rbReguler.Location = New-Object System.Drawing.Point(16, 28)
$rbReguler.AutoSize = $true
$rbReguler.Checked = $true
$grpTier.Controls.Add($rbReguler)

$rbPremium = New-Object System.Windows.Forms.RadioButton
$rbPremium.Text = "Premium (hanya Soalin Premium)"
$rbPremium.Location = New-Object System.Drawing.Point(360, 28)
$rbPremium.AutoSize = $true
$grpTier.Controls.Add($rbPremium)

$grpCat = New-Object System.Windows.Forms.GroupBox
$grpCat.Text = "3. Kategori  (pilih yang sudah ada, atau ketik baru)"
$grpCat.Font = $fontBold
$grpCat.Location = New-Object System.Drawing.Point(12, 258)
$grpCat.Size = New-Object System.Drawing.Size(1030, 62)
$grpCat.Anchor = "Top, Left, Right"
$tabAdd.Controls.Add($grpCat)

$cmbCategory = New-Object System.Windows.Forms.ComboBox
$cmbCategory.Location = New-Object System.Drawing.Point(16, 26)
$cmbCategory.Size = New-Object System.Drawing.Size(380, 26)
$cmbCategory.DropDownStyle = "DropDown"
$grpCat.Controls.Add($cmbCategory)

$grpName = New-Object System.Windows.Forms.GroupBox
$grpName.Text = "4. Nama paket  (opsional; hanya dipakai kalau 1 file, kosong = nama file)"
$grpName.Font = $fontBold
$grpName.Location = New-Object System.Drawing.Point(12, 330)
$grpName.Size = New-Object System.Drawing.Size(1030, 62)
$grpName.Anchor = "Top, Left, Right"
$tabAdd.Controls.Add($grpName)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(16, 26)
$txtName.Size = New-Object System.Drawing.Size(996, 26)
$txtName.Anchor = "Top, Left, Right"
$grpName.Controls.Add($txtName)

$btnPublish = New-Object System.Windows.Forms.Button
$btnPublish.Text = "PUBLISH"
$btnPublish.Location = New-Object System.Drawing.Point(12, 406)
$btnPublish.Size = New-Object System.Drawing.Size(240, 46)
Style-Button $btnPublish "primary"
$btnPublish.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$tabAdd.Controls.Add($btnPublish)

# --- Bawah (dipakai kedua tab): log (Fill) lalu bar (Top)
$bottom = New-Object System.Windows.Forms.Panel
$bottom.Dock = "Bottom"
$bottom.Height = 150
$bottom.BackColor = $cBg
$bottom.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 12)
$form.Controls.Add($bottom)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Dock = "Fill"
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$txtLog.BackColor = $cLogBg
$txtLog.ForeColor = $cLogFg
$txtLog.BorderStyle = "None"
$bottom.Controls.Add($txtLog)

$bar = New-Object System.Windows.Forms.Panel
$bar.Dock = "Top"
$bar.Height = 48
$bar.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 6)
$bottom.Controls.Add($bar)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Dock = "Fill"
$lblStatus.Font = $fontBold
$lblStatus.ForeColor = $cMuted
$lblStatus.Text = "Siap."
$lblStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$bar.Controls.Add($lblStatus)

$chkPush = New-Object System.Windows.Forms.CheckBox
$chkPush.Text = "Commit dan push ke GitHub"
$chkPush.Dock = "Left"
$chkPush.AutoSize = $true
$chkPush.ForeColor = $cSoft
$chkPush.Padding = New-Object System.Windows.Forms.Padding(0, 0, 16, 0)
$bar.Controls.Add($chkPush)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Buka folder"
$btnOpen.Dock = "Right"
$btnOpen.Width = 130
Style-Button $btnOpen "default"
$bar.Controls.Add($btnOpen)

$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = "Bersihkan log"
$btnClearLog.Dock = "Right"
$btnClearLog.Width = 130
Style-Button $btnClearLog "default"
$bar.Controls.Add($btnClearLog)

# --- Header (Top). Ditambahkan terakhir.
$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Top"
$header.Height = 66
$header.BackColor = $cHeader
$form.Controls.Add($header)

$lblStats = New-Object System.Windows.Forms.Label
$lblStats.Dock = "Right"
$lblStats.Width = 360
$lblStats.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblStats.ForeColor = $cWhite
$lblStats.Font = $fontBold
$lblStats.Padding = New-Object System.Windows.Forms.Padding(0, 0, 20, 0)
$header.Controls.Add($lblStats)

$lblTitle = Make-Label "Soalin Bank" 20 9 320 32 (New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)) $cWhite
$header.Controls.Add($lblTitle)

$lblSub = Make-Label "Kelola dan tambah paket soal" 22 40 320 20 $fontSmall $cHeadSub
$header.Controls.Add($lblSub)

# Tooltips
$tip.SetToolTip($btnRename, "Ubah judul paket. ID tidak berubah, jadi progres belajar aman.")
$tip.SetToolTip($btnMove, "Pindahkan paket ke kategori yang dipilih atau yang diketik.")
$tip.SetToolTip($btnTier, "Tampilkan paket di Reguler (Soalin + Premium) atau Premium saja.")
$tip.SetToolTip($btnRenameCat, "Ganti nama kategori. Berlaku untuk semua paket di kategori itu pada tier ini.")
$tip.SetToolTip($btnDelete, "Hapus paket beserta file soal dan gambarnya dari bank.")
$tip.SetToolTip($chkPush, "Kalau dicentang, setiap perubahan langsung di-commit dan di-push ke GitHub.")
$tip.SetToolTip($btnPublish, "Convert file .docx yang dipilih dan masukkan ke bank.")

# --- Event handler: Kelola ---

$tree.Add_AfterSelect({ Update-Details })

$tree.Add_NodeMouseDoubleClick({
    param($s, $e)
    if ($e.Node.Tag -and $e.Node.Tag.kind -eq "package") {
        $tree.SelectedNode = $e.Node
        $btnRename.PerformClick()
    }
})

$tree.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::F2) {
        if ($btnRename.Enabled) { $btnRename.PerformClick() }
        elseif ($btnRenameCat.Enabled) { $btnRenameCat.PerformClick() }
        $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete -and $btnDelete.Enabled) {
        $btnDelete.PerformClick()
        $e.SuppressKeyPress = $true
    }
})

$txtSearch.Add_TextChanged({ Refresh-Tree (Get-SelectedId) })

$txtSearch.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        $txtSearch.Text = ""
        $e.SuppressKeyPress = $true
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Down -or $e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $tree.Focus()
        if (-not $tree.SelectedNode -and $tree.Nodes.Count -gt 0) { $tree.SelectedNode = $tree.Nodes[0] }
        $e.SuppressKeyPress = $true
    }
})

$form.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F) {
        $tabs.SelectedTab = $tabManage
        $txtSearch.Focus()
        $txtSearch.SelectAll()
        $e.SuppressKeyPress = $true
    }
})

$btnRename.Add_Click({
    $t = $tree.SelectedNode.Tag
    $new = [Microsoft.VisualBasic.Interaction]::InputBox("Judul baru untuk paket ini:", "Ganti nama", $t.title).Trim()
    if (-not $new -or $new -eq $t.title) { return }
    Invoke-Manage @("rename", $t.id, $new) ("Ganti nama - " + $new) $t.id
})

$btnMove.Add_Click({
    $t = $tree.SelectedNode.Tag
    $cat = $cmbMove.Text.Trim()
    if (-not $cat) { Show-Info "Isi kategori tujuan dulu."; return }
    if ($cat -eq $t.category) { return }
    Invoke-Manage @("move", $t.id, $cat) ("Pindah paket - " + $t.title + " ke " + $cat) $t.id
})

$btnTier.Add_Click({
    $t = $tree.SelectedNode.Tag
    $target = if ($rbMPrem.Checked) { "premium" } else { "reguler" }
    if ($target -eq $t.tier) { Show-Info "Paket sudah tampil di tier itu."; return }
    if ($target -eq "premium") { $text = "Pindah paket ini ke Premium saja?`r`nPaket tidak lagi tampil di Soalin reguler." }
    else { $text = "Tampilkan paket ini di Soalin dan Premium?" }
    if (-not (Confirm-Action $text)) { return }
    Invoke-Manage @("tier", $t.id, $target) ("Tier - " + $t.title + " ke " + $target) $t.id
})

$btnDelete.Add_Click({
    $t = $tree.SelectedNode.Tag
    $text = "Hapus paket: " + $t.title + " (" + $t.count + " soal)?`r`nFile soal dan gambarnya ikut terhapus dari bank."
    if (-not (Confirm-Action $text)) { return }
    Invoke-Manage @("delete", $t.id) ("Hapus paket - " + $t.title)
})

$btnRenameCat.Add_Click({
    $t = $tree.SelectedNode.Tag
    $new = [Microsoft.VisualBasic.Interaction]::InputBox("Nama baru untuk kategori ini:", "Ganti nama kategori", $t.name).Trim()
    if (-not $new -or $new -eq $t.name) { return }
    Invoke-Manage @("rename-category", $t.name, $new, $t.tier) ("Ganti kategori - " + $t.name + " -> " + $new)
})

# --- Event handler: Tambah ---

$btnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Word (*.docx)|*.docx"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq "OK") { Add-DocxFiles $dlg.FileNames }
})

$btnRemove.Add_Click({
    $i = $lstFiles.SelectedIndex
    if ($i -ge 0) { $lstFiles.Items.RemoveAt($i) }
})

$lstFiles.Add_DragEnter({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
})

$lstFiles.Add_DragDrop({
    param($s, $e)
    Add-DocxFiles ($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
})

$lstFiles.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) {
        $i = $lstFiles.SelectedIndex
        if ($i -ge 0) { $lstFiles.Items.RemoveAt($i) }
        $e.SuppressKeyPress = $true
    }
})

$btnPublish.Add_Click({ Publish-Files })

# --- Bawah ---

$btnOpen.Add_Click({ Start-Process explorer.exe $root })
$btnClearLog.Add_Click({ $txtLog.Clear() })

Refresh-Categories
Refresh-Tree $null
[void]$form.ShowDialog()
