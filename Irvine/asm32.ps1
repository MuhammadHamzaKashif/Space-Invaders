param(
    [Parameter(Mandatory=$true)]
    [string]$file
)

# Check if file exists
if (-not (Test-Path $file)) {
    Write-Host "Error: File $file not found!" -ForegroundColor Red
    exit 1
}

# Extract filename without extension
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)

# Path to Irvine
$IrvinePath = "C:\Irvine"

# Assemble
Write-Host "Assembling $file..."
& ml /c /coff /Fl $file
if ($LASTEXITCODE -ne 0) {
    Write-Host "Assembly failed!" -ForegroundColor Red
    exit 1
}

# Link
Write-Host "Linking $baseName.obj..."
& link "$baseName.obj" "$IrvinePath\Irvine32.lib" "$IrvinePath\Kernel32.lib" "$IrvinePath\User32.lib" /SUBSYSTEM:CONSOLE
if ($LASTEXITCODE -ne 0) {
    Write-Host "Linking failed!" -ForegroundColor Red
    exit 1
}

# Run
Write-Host "Build successful! Running $baseName.exe..."
& ".\$baseName.exe"