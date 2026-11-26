$ErrorActionPreference = "Stop"

$BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ZipPath = Join-Path $BaseDir "maven-wrapper.zip"
$PropsPath = Join-Path $BaseDir ".mvn\wrapper\maven-wrapper.properties"
$Url = "https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper-distribution/3.3.2/maven-wrapper-distribution-3.3.2-only-script.zip"

Write-Host "Baixando Maven Wrapper oficial (3.3.2)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $Url -OutFile $ZipPath

Write-Host "Extraindo arquivos em $BaseDir..." -ForegroundColor Cyan
Expand-Archive -Path $ZipPath -DestinationPath $BaseDir -Force
Remove-Item -Path $ZipPath -Force

$PropsDir = Split-Path -Parent $PropsPath
if (-not (Test-Path $PropsDir)) {
    New-Item -ItemType Directory -Force -Path $PropsDir | Out-Null
}

$PropsContent = @"
wrapperVersion=3.3.2
distributionType=only-script
distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.zip
"@

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($PropsPath, $PropsContent.Replace("`r`n", "`n"), $Utf8NoBom)

Write-Host "Maven Wrapper configurado com sucesso!" -ForegroundColor Green
Write-Host "Execute agora: .\mvnw.cmd test" -ForegroundColor Yellow