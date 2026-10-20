# bank-gui.ps1 - Tambah paket soal ke Soalin-Bank lewat klik (tanpa terminal).
# Dipanggil dari soalin-bank.bat. Butuh Node.js (untuk convert) dan Git (opsional, untuk push).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath = Join-Path $root "index.json"

function Get-Categories {
    if (-not (Test-Path $indexPath)) { return @() }
    try {
        $idx = Get-Content $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($idx.packages | ForEach-Object { $_.category } | Where-Object { $_ } | Sort-Object -Unique)
    } catch {
        return @()
    }
}

function Add-Log($msg) {
    $txtLog.AppendText([string]$msg + "`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-Busy($busy) {
    $btnPublish.Enabled = -not $busy
    $btnAdd.Enabled = -not $busy
    $btnRemove.Enabled = -not $busy
    $btnOpen.Enabled = -not $busy
    $form.UseWaitCursor = $busy
    [System.Windows.Forms.Application]::DoEvents()
}

function Run-Tool($exe, $toolArgs) {
    $out = & $exe @toolArgs 2>&1
    $code = $LASTEXITCODE
    foreach ($line in $out) { Add-Log $line.ToString() }
    return $code
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Soalin Bank - Tambah Paket"
$form.ClientSize = New-Object System.Drawing.Size(640, 640)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# 1. File docx
$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = "1. File .docx (bisa lebih dari satu)"
$lbl1.Location = New-Object System.Drawing.Point(20, 15)
$lbl1.AutoSize = $true
$form.Controls.Add($lbl1)

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(20, 40)
$lstFiles.Size = New-Object System.Drawing.Size(470, 90)
$form.Controls.Add($lstFiles)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Pilih file..."
$btnAdd.Location = New-Object System.Drawing.Point(500, 40)
$btnAdd.Size = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Hapus dari daftar"
$btnRemove.Location = New-Object System.Drawing.Point(500, 80)
$btnRemove.Size = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnRemove)

# 2. Tier
$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "2. Tampil di"
$lbl2.Location = New-Object System.Drawing.Point(20, 145)
$lbl2.AutoSize = $true
$form.Controls.Add($lbl2)

$rbReguler = New-Object System.Windows.Forms.RadioButton
$rbReguler.Text = "Reguler (Soalin dan Premium)"
$rbReguler.Location = New-Object System.Drawing.Point(20, 170)
$rbReguler.AutoSize = $true
$rbReguler.Checked = $true
$form.Controls.Add($rbReguler)

$rbPremium = New-Object System.Windows.Forms.RadioButton
$rbPremium.Text = "Premium (hanya Soalin Premium)"
$rbPremium.Location = New-Object System.Drawing.Point(300, 170)
$rbPremium.AutoSize = $true
$form.Controls.Add($rbPremium)

# 3. Kategori
$lbl3 = New-Object System.Windows.Forms.Label
$lbl3.Text = "3. Kategori (pilih yang sudah ada, atau ketik baru)"
$lbl3.Location = New-Object System.Drawing.Point(20, 205)
$lbl3.AutoSize = $true
$form.Controls.Add($lbl3)

$cmbCategory = New-Object System.Windows.Forms.ComboBox
$cmbCategory.Location = New-Object System.Drawing.Point(20, 230)
$cmbCategory.Size = New-Object System.Drawing.Size(300, 25)
$cmbCategory.DropDownStyle = "DropDown"
$cmbCategory.Items.AddRange([object[]](Get-Categories))
$form.Controls.Add($cmbCategory)

# 4. Nama paket
$lbl4 = New-Object System.Windows.Forms.Label
$lbl4.Text = "4. Nama paket (opsional; hanya dipakai kalau 1 file, kosong = nama file)"
$lbl4.Location = New-Object System.Drawing.Point(20, 265)
$lbl4.AutoSize = $true
$form.Controls.Add($lbl4)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(20, 290)
$txtName.Size = New-Object System.Drawing.Size(600, 25)
$form.Controls.Add($txtName)

# 5. Git
$chkPush = New-Object System.Windows.Forms.CheckBox
$chkPush.Text = "Commit dan push ke GitHub setelah publish"
$chkPush.Location = New-Object System.Drawing.Point(20, 330)
$chkPush.AutoSize = $true
$form.Controls.Add($chkPush)

# Aksi
$btnPublish = New-Object System.Windows.Forms.Button
$btnPublish.Text = "PUBLISH"
$btnPublish.Location = New-Object System.Drawing.Point(20, 365)
$btnPublish.Size = New-Object System.Drawing.Size(200, 40)
$btnPublish.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnPublish)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Buka folder bank"
$btnOpen.Location = New-Object System.Drawing.Point(240, 365)
$btnOpen.Size = New-Object System.Drawing.Size(170, 40)
$form.Controls.Add($btnOpen)

# Log
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(20, 420)
$txtLog.Size = New-Object System.Drawing.Size(600, 200)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

# --- Event handler ---

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

$btnOpen.Add_Click({ Start-Process explorer.exe $root })

$btnPublish.Add_Click({
    $category = $cmbCategory.Text.Trim()
    $files = @($lstFiles.Items)
    $tier = if ($rbPremium.Checked) { "premium" } else { "reguler" }
    $name = $txtName.Text.Trim()

    if ($files.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Pilih minimal satu file .docx.", "Soalin Bank"); return }
    if (-not $category) { [System.Windows.Forms.MessageBox]::Show("Isi kategori dulu.", "Soalin Bank"); return }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show("Node.js belum terpasang. Install dari https://nodejs.org", "Soalin Bank"); return
    }

    Set-Busy $true
    try {
        Set-Location $root
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

        if ($chkPush.Checked -and $ok -gt 0) {
            Add-Log ""
            Add-Log "Commit dan push..."
            [void](Run-Tool "git" @("add", "-A"))
            $msg = "Tambah paket $tier - $category"
            [void](Run-Tool "git" @("commit", "-m", $msg))
            $code = Run-Tool "git" @("push", "origin", "main")
            if ($code -eq 0) { Add-Log "Push berhasil. Tunggu 1-5 menit sebelum app membacanya." }
            else { Add-Log "Push gagal, cek pesan di atas." }
        }
        elseif (-not $chkPush.Checked) {
            Add-Log "Belum di-push. Centang 'Commit dan push' atau jalankan git manual."
        }

        # Perbarui daftar kategori setelah publish.
        $cmbCategory.Items.Clear()
        $cmbCategory.Items.AddRange([object[]](Get-Categories))
    }
    catch {
        Add-Log "ERROR: $($_.Exception.Message)"
    }
    finally {
        Set-Busy $false
    }
})

[void]$form.ShowDialog()
