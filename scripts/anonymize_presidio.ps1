param(
    [string]$InputFile = "D:\Data\input.csv",
    [string]$OutputFile = "D:\Data\input_anon.csv",
    [string]$Language = "ru",
    [string]$Delimiter = ";"
)

$ErrorActionPreference = "Stop"

function Test-Presidio {
    param([string]$Url)

    try {
        Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 5 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-PresidioAnonymization {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [string]$Text,
        [string]$Language = "ru"
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    try {
        $analyzeBody = @{
            text     = $Text
            language = $Language
        } | ConvertTo-Json -Depth 5

        $analyzeResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:5001/analyze" -ContentType "application/json; charset=utf-8" -Body $analyzeBody

        if (-not $analyzeResponse -or $analyzeResponse.Count -eq 0) {
            return $Text
        }

        $anonymizeBody = @{
            text            = $Text
            language        = $Language
            analyzer_results = $analyzeResponse
        } | ConvertTo-Json -Depth 10

        $anonResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:5002/anonymize" -ContentType "application/json; charset=utf-8" -Body $anonymizeBody

        if ($anonResponse -and $anonResponse.text) {
            return [string]$anonResponse.text
        }

        return $Text
    }
    catch {
        Write-Warning "Presidio недоступен или вернул ошибку: $($_.Exception.Message). Возвращаю исходный текст."
        return $Text
    }
}

if (-not (Test-Presidio -Url "http://localhost:5001/docs")) {
    throw "Analyzer API (http://localhost:5001) недоступен. Проверьте docker compose и проброс портов."
}

if (-not (Test-Presidio -Url "http://localhost:5002/docs")) {
    throw "Anonymizer API (http://localhost:5002) недоступен. Проверьте docker compose и проброс портов."
}

Write-Host "Reading CSV from $InputFile"
$rows = Import-Csv -Path $InputFile -Delimiter $Delimiter -Encoding UTF8

$i = 0
foreach ($row in $rows) {
    foreach ($column in $row.PSObject.Properties.Name) {
        $value = [string]$row.$column
        $row.$column = Invoke-PresidioAnonymization -Text $value -Language $Language
    }

    $i++
    if ($i % 100 -eq 0) {
        Write-Host "Processed rows: $i"
    }
}

Write-Host "Saving anonymized CSV to $OutputFile"
$rows | Export-Csv -Path $OutputFile -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8

Write-Host "DONE"
