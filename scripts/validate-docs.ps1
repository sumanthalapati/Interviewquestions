[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$rootPath = [System.IO.Path]::GetFullPath($Root)
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Get-RelativeName([string]$Path) {
    [System.IO.Path]::GetRelativePath($rootPath, $Path).Replace('\', '/')
}

function ConvertTo-GitHubSlug([string]$Heading) {
    $value = $Heading
    $value = [regex]::Replace($value, '<[^>]+>', '')
    $value = [regex]::Replace($value, '!?(\[([^\]]+)\]\([^)]*\))', '$2')
    $value = $value.Replace('`', '').Replace('*', '').Replace('_', '')
    $value = $value.ToLowerInvariant()
    $value = [regex]::Replace($value, '[^\p{L}\p{Nd}\s-]', '')
    $value = [regex]::Replace($value.Trim(), '\s', '-')
    return $value
}

function Get-Anchors([string]$Content) {
    $anchors = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $slugCounts = @{}

    foreach ($match in [regex]::Matches($Content, '(?im)<a\s+(?:name|id)=["'']([^"'']+)["''][^>]*>')) {
        [void]$anchors.Add($match.Groups[1].Value)
    }

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -notmatch '^#{1,6}\s+(.+?)\s*#*\s*$') { continue }
        $slug = ConvertTo-GitHubSlug $Matches[1]
        if ([string]::IsNullOrWhiteSpace($slug)) { continue }

        if ($slugCounts.ContainsKey($slug)) {
            $slugCounts[$slug]++
            $slug = "$slug-$($slugCounts[$slug])"
        }
        else {
            $slugCounts[$slug] = 0
        }

        [void]$anchors.Add($slug)
    }

    return $anchors
}

function Test-CodeFences([string]$Name, [string]$Content) {
    $openFence = $null
    $openLine = 0
    $lineNumber = 0

    foreach ($line in ($Content -split "`r?`n")) {
        $lineNumber++
        if ($line -notmatch '^\s*(`{3,}|~{3,})') { continue }
        $marker = $Matches[1][0]

        if ($null -eq $openFence) {
            $openFence = $marker
            $openLine = $lineNumber
        }
        elseif ($marker -eq $openFence) {
            $openFence = $null
            $openLine = 0
        }
    }

    if ($null -ne $openFence) {
        $errors.Add("$Name`: unclosed code fence opened at line $openLine")
    }
}

function Remove-FencedCode([string]$Content) {
    $builder = [System.Text.StringBuilder]::new()
    $openFence = $null

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $marker = $Matches[1][0]
            if ($null -eq $openFence) {
                $openFence = $marker
            }
            elseif ($marker -eq $openFence) {
                $openFence = $null
            }
            [void]$builder.AppendLine()
            continue
        }

        if ($null -eq $openFence) {
            [void]$builder.AppendLine($line)
        }
        else {
            [void]$builder.AppendLine()
        }
    }

    return $builder.ToString()
}

$markdownFiles = Get-ChildItem -LiteralPath $rootPath -Recurse -File -Filter '*.md' |
    Where-Object {
        $_.FullName -notmatch '[\\/](?:\.git|tmp|node_modules)[\\/]'
    }

$contentByPath = @{}
$anchorsByPath = @{}

foreach ($file in $markdownFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $contentByPath[$file.FullName] = $content
    $anchorsByPath[$file.FullName] = Get-Anchors $content

    $name = Get-RelativeName $file.FullName
    Test-CodeFences $name $content

    $outsideFences = Remove-FencedCode $content
    $majorHeadings = [regex]::Matches($outsideFences, '(?m)^#{1,2}\s+(.+?)\s*#*\s*$') |
        ForEach-Object { $_.Groups[1].Value.Trim() }
    $duplicateHeadings = $majorHeadings |
        Group-Object -CaseSensitive:$false |
        Where-Object { $_.Count -gt 1 }
    foreach ($duplicate in $duplicateHeadings) {
        $errors.Add("$name`: duplicate major heading '$($duplicate.Name)' ($($duplicate.Count)x)")
    }

    # These prefixes identify sections that promise the repository's complete
    # question -> failure -> corrected design -> practice learning contract.
    $structuredSections = [regex]::Matches(
        $outsideFences,
        '(?ms)^##\s+(?<id>(?:(?:HTML|EF|NGRX|TS|ASPF|ASPA|ASPX|TECH|AIE|INF)-M|(?:BDP|DSP|DI)-)\d+)\b[^\r\n]*\r?\n(?<body>.*?)(?=^#{1,2}\s+|\z)')
    $requiredStructuredLabels = @(
        '**Question:**',
        '**Answer:**',
        '**What problem does it solve?**',
        '**Before this concept:**',
        '❌ **Wrong',
        '✅ **After/correct example',
        '**How it works now:**',
        '**Trade-offs and when not to use it:**',
        '**Production checks:**',
        '**Try it:**'
    )
    foreach ($section in $structuredSections) {
        $body = $section.Groups['body'].Value
        foreach ($label in $requiredStructuredLabels) {
            if (-not $body.Contains($label)) {
                $errors.Add("$name`: $($section.Groups['id'].Value) is missing required label '$label'")
            }
        }
    }

    if ($content -match '(?m)^#{1,6}.+\s\{#[A-Za-z0-9_-]+\}\s*$') {
        $errors.Add("$name`: contains unsupported {#custom-anchor} heading syntax")
    }

    # Ignore whitespace inside code examples and the two-space Markdown hard-break syntax.
    $trailingCount = @(
        [regex]::Matches($outsideFences, '(?m)([\t ]+)$') |
            Where-Object { $_.Groups[1].Value -ne '  ' }
    ).Count
    if ($trailingCount -gt 0) {
        $warnings.Add("$name`: $trailingCount line(s) contain trailing whitespace")
    }
}

foreach ($file in $markdownFiles) {
    $sourceName = Get-RelativeName $file.FullName
    $content = Remove-FencedCode $contentByPath[$file.FullName]
    $matches = [regex]::Matches($content, '(?<!!)\[[^\]]*\]\(([^)]+)\)')

    foreach ($match in $matches) {
        $rawTarget = $match.Groups[1].Value.Trim().Trim('<', '>')
        if ([string]::IsNullOrWhiteSpace($rawTarget)) { continue }
        if ($rawTarget -match '^(?i)(?:https?://|mailto:|tel:|data:|javascript:)') { continue }

        # Optional Markdown titles follow a whitespace after the target.
        if ($rawTarget -match '^([^\s]+)\s+["'']') {
            $rawTarget = $Matches[1]
        }

        $parts = $rawTarget.Split('#', 2)
        $pathPart = [System.Uri]::UnescapeDataString($parts[0])
        $fragment = if ($parts.Count -eq 2) { [System.Uri]::UnescapeDataString($parts[1]) } else { '' }

        if ([string]::IsNullOrWhiteSpace($pathPart)) {
            $targetPath = $file.FullName
        }
        else {
            $targetPath = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $pathPart))
        }

        if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            $errors.Add("$sourceName`: missing local target '$rawTarget'")
            continue
        }

        if (-not [string]::IsNullOrWhiteSpace($fragment) -and
            [System.IO.Path]::GetExtension($targetPath) -ieq '.md') {
            if (-not $anchorsByPath.ContainsKey($targetPath)) {
                $targetContent = [System.IO.File]::ReadAllText($targetPath)
                $anchorsByPath[$targetPath] = Get-Anchors $targetContent
            }

            if (-not $anchorsByPath[$targetPath].Contains($fragment)) {
                $errors.Add("$sourceName`: missing anchor '#$fragment' in '$(Get-RelativeName $targetPath)'")
            }
        }
    }
}

# Keep the repository navigable as new top-level guides are added. Every root
# Markdown document, except the index itself, must be discoverable from it.
$guideIndexPath = Join-Path $rootPath 'GUIDE-INDEX.md'
if (-not (Test-Path -LiteralPath $guideIndexPath -PathType Leaf)) {
    $errors.Add("GUIDE-INDEX.md is missing")
}
else {
    $guideIndexContent = Remove-FencedCode ([System.IO.File]::ReadAllText($guideIndexPath))
    $topLevelGuides = Get-ChildItem -LiteralPath $rootPath -File -Filter '*.md' |
        Where-Object { $_.Name -ine 'GUIDE-INDEX.md' }

    foreach ($guide in $topLevelGuides) {
        $escapedName = [regex]::Escape($guide.Name)
        $linkPattern = "(?i)\((?:\./)?$escapedName(?:#[^)]+)?\)"
        if ($guideIndexContent -notmatch $linkPattern) {
            $errors.Add("GUIDE-INDEX.md: top-level guide '$($guide.Name)' is not indexed")
        }
    }
}

Write-Host "Documentation validation: $($markdownFiles.Count) Markdown files"

if ($warnings.Count -gt 0) {
    Write-Host "`nWarnings ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host "`nErrors ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nAll documentation checks passed." -ForegroundColor Green
