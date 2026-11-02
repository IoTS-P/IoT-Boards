param(
    [string]$InputPath = "D:\stm32-trace\stm32f103_dma_trace.log",
    [string]$OutputPath = "D:\stm32-trace\stm32f103_dma_trace.clean.log"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input log not found: $InputPath"
}

# GDB/MI console stream records look like: ~"text\n"
# Decode those C/JSON-compatible quoted strings and discard protocol/control records.
$clean = New-Object System.Collections.Generic.List[string]
$decodedRecords = 0
$ignoredRecords = 0

foreach ($line in Get-Content -LiteralPath $InputPath) {
    if ($line.StartsWith('~"')) {
        $quoted = $line.Substring(1)  # retain the leading quote
        try {
            $decoded = ConvertFrom-Json -InputObject $quoted
            [void]$clean.Add([string]$decoded)
            $decodedRecords++
        }
        catch {
            # Keep a visible marker rather than silently losing an undecodable console record.
            [void]$clean.Add("[UNDECODED MI CONSOLE RECORD] " + $line)
            $ignoredRecords++
        }
    }
    elseif ($line.StartsWith('@"')) {
        # Target stream output, if any; decode it using the same quoted-string rules.
        $quoted = $line.Substring(1)
        try {
            $decoded = ConvertFrom-Json -InputObject $quoted
            [void]$clean.Add("[TARGET OUTPUT] " + [string]$decoded)
            $decodedRecords++
        }
        catch {
            [void]$clean.Add("[UNDECODED MI TARGET RECORD] " + $line)
            $ignoredRecords++
        }
    }
    else {
        # Drop MI protocol records (=, *, &, ^), prompts, and command echoes.
        $ignoredRecords++
    }
}

# MI strings often contain embedded \n. Join decoded records, then normalize CRLF.
$content = ($clean -join "")
$content = $content -replace "`r?`n", "`r`n"
[System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.Encoding]::UTF8)

Write-Host "Decoded console records: $decodedRecords"
Write-Host "Ignored protocol/control records: $ignoredRecords"
Write-Host "Clean log written to: $OutputPath"
Write-Host "Raw log was preserved unchanged."