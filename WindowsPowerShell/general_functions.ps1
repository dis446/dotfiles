Set-Alias c clear
function src {
    $FolderPath = "C:\Users\Tsetsen-Erdene\dotfiles\WindowsPowerShell"
    Get-ChildItem -Path $FolderPath -Filter "*.ps1" -File | ForEach-Object { . $_.FullName }
}