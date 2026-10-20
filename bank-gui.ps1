# bank-gui.ps1 - Kelola dan tambah paket soal di Soalin-Bank lewat klik (tanpa terminal).
# Dipanggil dari soalin-bank.bat. Butuh Node.js (convert & kelola) dan Git (opsional, untuk push).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $root "index.json"
Set-Location $root

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

function Add-Log($msg) {
    $txtLog.AppendText([string]$msg + "`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Busy($busy) {
    $tabs.Enabled = -not $busy
    $btnOpen.Enabled = -not $busy
    $form.UseWaitCursor = $busy
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Info($text) {
    [void][System.Windows.Forms.MessageBox]::Show($text, "Soalin Bank")
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
        return
    }
    Add-Log ""
    Add-Log "Commit dan push..."
    [void](Run-Tool "git" @("add", "-A"))
    [void](Run-Tool "git" @("commit", "-m", $msg))
    $code = Run-Tool "git" @("push", "origin", "main")
    if ($code -eq 0) { Add-Log "Push berhasil. Tunggu 1-5 menit sebelum app membacanya." }
    else { Add-Log "Push gagal, cek pesan di atas." }
}

# --- Tab Kelola ---

function Refresh-Categories {
    $cats = @(Get-Categories)
    $cmbCategory.Items.Clear()
    $cmbCategory.Items.AddRange([object[]]$cats)
    $cmbMove.Items.Clear()
    $cmbMove.Items.AddRange([object[]]$cats)
}

function Refresh-Tree($keepId) {
    $tree.BeginUpdate()
    $tree.Nodes.Clear()
    $pkgs = @(Read-Index)
    foreach ($tier in @("reguler", "premium")) {
        $tierPkgs = @($pkgs | Where-Object { $_.tier -eq $tier })
        $tierLabel = if ($tier -eq "reguler") { "Reguler (Soalin dan Premium)" } else { "Premium (hanya Soalin Premium)" }
        $tierNode = New-Object System.Windows.Forms.TreeNode ($tierLabel + " - " + $tierPkgs.Count + " paket")
        $tierNode.Tag = @{ kind = "tier"; tier = $tier }
        $cats = @($tierPkgs | ForEach-Object { $_.category } | Where-Object { $_ } | Sort-Object -Unique)
        foreach ($cat in $cats) {
            $catPkgs = @($tierPkgs | Where-Object { $_.category -eq $cat } | Sort-Object title)
            $catNode = New-Object System.Windows.Forms.TreeNode ($cat + " (" + $catPkgs.Count + ")")
            $catNode.Tag = @{ kind = "category"; name = $cat; tier = $tier; packages = $catPkgs.Count }
            foreach ($p in $catPkgs) {
                $n = New-Object System.Windows.Forms.TreeNode ($p.title + "  [" + $p.count + "]")
                $n.Tag = @{ kind = "package"; id = $p.id; title = $p.title; category = $p.category; tier = $p.tier; count = $p.count }
                [void]$catNode.Nodes.Add($n)
            }
            [void]$tierNode.Nodes.Add($catNode)
        }
        [void]$tree.Nodes.Add($tierNode)
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

function Update-Details {
    $t = if ($tree.SelectedNode) { $tree.SelectedNode.Tag } else { $null }
    $kind = if ($t) { $t.kind } else { "" }
    $isPkg = ($kind -eq "package")

    $btnRename.Enabled = $isPkg
    $cmbMove.Enabled = $isPkg
    $btnMove.Enabled = $isPkg
    $btnDelete.Enabled = $isPkg
    $btnRenameCat.Enabled = ($kind -eq "category")

    switch ($kind) {
        "package" {
            $lblInfo.Text = "Judul: " + $t.title + "`r`nKategori: " + $t.category + "`r`nTier: " + $t.tier + "`r`nJumlah soal: " + $t.count + "`r`nID: " + $t.id
            $cmbMove.Text = $t.category
        }
        "category" {
            $lblInfo.Text = "Kategori: " + $t.name + "`r`nTier: " + $t.tier + "`r`nJumlah paket: " + $t.packages + "`r`n`r`nGanti nama kategori mengubah semua paket di dalamnya."
        }
        default {
            $lblInfo.Text = "Pilih paket atau kategori di sebelah kiri."
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
            Add-Log "GAGAL (kode $code)."
            return
        }
        Commit-Changes $commitMsg
    }
    catch {
        Add-Log ("ERROR: " + $_.Exception.Message)
    }
    finally {
        Refresh-Categories
        Refresh-Tree $keepId
        Set-Busy $false
    }
}

function Confirm-Action($text) {
    $ans = [System.Windows.Forms.MessageBox]::Show($text, "Soalin Bank", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    return ($ans -eq [System.Windows.Forms.DialogResult]::Yes)
}

# --- Tab Tambah ---

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
            if ($code -ne 0) { Add-Log "npm install gagal."; return }
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
        if ($ok -gt 0) { Commit-Changes "Tambah paket $tier - $category" }
    }
    catch {
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
$form.Text = "Soalin Bank - Kelola Paket"
$form.ClientSize = New-Object System.Drawing.Size(760, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(12, 12)
$tabs.Size = New-Object System.Drawing.Size(736, 420)
$form.Controls.Add($tabs)

$tabManage = New-Object System.Windows.Forms.TabPage "Kelola paket"
$tabAdd = New-Object System.Windows.Forms.TabPage "Tambah paket"
[void]$tabs.TabPages.Add($tabManage)
[void]$tabs.TabPages.Add($tabAdd)

# -- Kelola: tree di kiri
$tree = New-Object System.Windows.Forms.TreeView
$tree.Location = New-Object System.Drawing.Point(10, 10)
$tree.Size = New-Object System.Drawing.Size(430, 370)
$tree.ShowNodeToolTips = $true
$tree.HideSelection = $false
$tabManage.Controls.Add($tree)

# -- Kelola: panel kanan
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(455, 10)
$lblInfo.Size = New-Object System.Drawing.Size(265, 120)
$tabManage.Controls.Add($lblInfo)

$btnRename = New-Object System.Windows.Forms.Button
$btnRename.Text = "Ganti nama...  (F2)"
$btnRename.Location = New-Object System.Drawing.Point(455, 140)
$btnRename.Size = New-Object System.Drawing.Size(265, 32)
$tabManage.Controls.Add($btnRename)

$lblMove = New-Object System.Windows.Forms.Label
$lblMove.Text = "Pindah ke kategori (pilih, atau ketik baru):"
$lblMove.Location = New-Object System.Drawing.Point(455, 185)
$lblMove.AutoSize = $true
$tabManage.Controls.Add($lblMove)

$cmbMove = New-Object System.Windows.Forms.ComboBox
$cmbMove.Location = New-Object System.Drawing.Point(455, 208)
$cmbMove.Size = New-Object System.Drawing.Size(265, 25)
$cmbMove.DropDownStyle = "DropDown"
$tabManage.Controls.Add($cmbMove)

$btnMove = New-Object System.Windows.Forms.Button
$btnMove.Text = "Pindah"
$btnMove.Location = New-Object System.Drawing.Point(455, 240)
$btnMove.Size = New-Object System.Drawing.Size(265, 32)
$tabManage.Controls.Add($btnMove)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Hapus paket...  (Del)"
$btnDelete.Location = New-Object System.Drawing.Point(455, 290)
$btnDelete.Size = New-Object System.Drawing.Size(265, 32)
$tabManage.Controls.Add($btnDelete)

$btnRenameCat = New-Object System.Windows.Forms.Button
$btnRenameCat.Text = "Ganti nama kategori..."
$btnRenameCat.Location = New-Object System.Drawing.Point(455, 340)
$btnRenameCat.Size = New-Object System.Drawing.Size(265, 32)
$tabManage.Controls.Add($btnRenameCat)

# -- Tambah: isi (sama seperti sebelumnya, pindah ke tab)
$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "1. File .docx (bisa lebih dari satu)"
$lbl1.Location = New-Object System.Drawing.Point(20, 15)
$lbl1.AutoSize = $true
$tabAdd.Controls.Add($lbl1)

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(20, 40)
$lstFiles.Size = New-Object System.Drawing.Size(470, 90)
$tabAdd.Controls.Add($lstFiles)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Pilih file..."
$btnAdd.Location = New-Object System.Drawing.Point(500, 40)
$btnAdd.Size = New-Object System.Drawing.Size(120, 30)
$tabAdd.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Hapus dari daftar"
$btnRemove.Location = New-Object System.Drawing.Point(500, 80)
$btnRemove.Size = New-Object System.Drawing.Size(120, 30)
$tabAdd.Controls.Add($btnRemove)

$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "2. Tampil di"
$lbl2.Location = New-Object System.Drawing.Point(20, 145)
$lbl2.AutoSize = $true
$tabAdd.Controls.Add($lbl2)

$rbReguler = New-Object System.Windows.Forms.RadioButton
$rbReguler.Text = "Reguler (Soalin dan Premium)"
$rbReguler.Location = New-Object System.Drawing.Point(20, 170)
$rbReguler.AutoSize = $true
$rbReguler.Checked = $true
$tabAdd.Controls.Add($rbReguler)

$rbPremium = New-Object System.Windows.Forms.RadioButton
$rbPremium.Text = "Premium (hanya Soalin Premium)"
$rbPremium.Location = New-Object System.Drawing.Point(300, 170)
$rbPremium.AutoSize = $true
$tabAdd.Controls.Add($rbPremium)

$lbl3 = New-Object System.Windows.Forms.Label
$lbl3.Text = "3. Kategori (pilih yang sudah ada, atau ketik baru)"
$lbl3.Location = New-Object System.Drawing.Point(20, 205)
$lbl3.AutoSize = $true
$tabAdd.Controls.Add($lbl3)

$cmbCategory = New-Object System.Windows.Forms.ComboBox
$cmbCategory.Location = New-Object System.Drawing.Point(20, 230)
$cmbCategory.Size = New-Object System.Drawing.Size(300, 25)
$cmbCategory.DropDownStyle = "DropDown"
$tabAdd.Controls.Add($cmbCategory)

$lbl4 = New-Object System.Windows.Forms.Label
$lbl4.Text = "4. Nama paket (opsional; hanya dipakai kalau 1 file, kosong = nama file)"
$lbl4.Location = New-Object System.Drawing.Point(20, 265)
$lbl4.AutoSize = $true
$tabAdd.Controls.Add($lbl4)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(20, 290)
$txtName.Size = New-Object System.Drawing.Size(600, 25)
$tabAdd.Controls.Add($txtName)

$btnPublish = New-Object System.Windows.Forms.Button
$btnPublish.Text = "PUBLISH"
$btnPublish.Location = New-Object System.Drawing.Point(20, 330)
$btnPublish.Size = New-Object System.Drawing.Size(200, 40)
$btnPublish.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$tabAdd.Controls.Add($btnPublish)

# -- Bawah (dipakai kedua tab)
$chkPush = New-Object System.Windows.Forms.CheckBox
$chkPush.Text = "Commit dan push ke GitHub setelah setiap perubahan"
$chkPush.Location = New-Object System.Drawing.Point(12, 445)
$chkPush.AutoSize = $true
$form.Controls.Add($chkPush)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Buka folder bank"
$btnOpen.Location = New-Object System.Drawing.Point(578, 440)
$btnOpen.Size = New-Object System.Drawing.Size(170, 30)
$form.Controls.Add($btnOpen)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(12, 478)
$txtLog.Size = New-Object System.Drawing.Size(736, 210)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

# --- Event handler: Kelola ---

$tree.Add_AfterSelect({ Update-Details })

$tree.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::F2) {
        if ($btnRename.Enabled) { $btnRename.PerformClick() }
        elseif ($btnRenameCat.Enabled) { $btnRenameCat.PerformClick() }
    }
    elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete -and $btnDelete.Enabled) {
        $btnDelete.PerformClick()
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
    if ($dlg.ShowDialog() -eq "OK") {
        foreach ($f in $dlg.FileNames) {
            if (-not $lstFiles.Items.Contains($f)) { [void]$lstFiles.Items.Add($f) }
        }
    }
})

$btnRemove.Add_Click({
    $i = $lstFiles.SelectedIndex
    if ($i -ge 0) { $lstFiles.Items.RemoveAt($i) }
})

$btnPublish.Add_Click({ Publish-Files })

# --- Bawah ---

$btnOpen.Add_Click({ Start-Process explorer.exe $root })

Refresh-Categories
Refresh-Tree $null
[void]$form.ShowDialog()
