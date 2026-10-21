# Zips a folder with forward-slash entry names (PS 5.1 tools write backslashes).
param([string]$Source, [string]$Zip)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$src = (Resolve-Path $Source).Path.TrimEnd('\')
if (Test-Path $Zip) { Remove-Item $Zip }
$archive = [IO.Compression.ZipFile]::Open($Zip, 'Create')
try {
	Get-ChildItem $src -Recurse -File | ForEach-Object {
		$name = $_.FullName.Substring($src.Length + 1).Replace('\', '/')
		[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $name)
	}
} finally { $archive.Dispose() }
