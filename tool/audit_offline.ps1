param(
    [switch]$RequireMerged
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceManifest = Join-Path $projectDir 'android/app/src/main/AndroidManifest.xml'
$dataExtractionRules = Join-Path $projectDir 'android/app/src/main/res/xml/data_extraction_rules.xml'
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$toolsNamespace = 'http://schemas.android.com/tools'

$allowedPermissions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
[void]$allowedPermissions.Add('android.permission.CAMERA')
[void]$allowedPermissions.Add('android.permission.READ_MEDIA_IMAGES')
[void]$allowedPermissions.Add('app.rosid.rosid.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION')

function Read-XmlDocument {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required XML file is missing: $Path"
    }
    [xml]$document = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $document.DocumentElement) {
        throw "XML file has no document element: $Path"
    }
    return $document
}

function Get-ManifestPermissions {
    param([Parameter(Mandatory)][string]$Path)

    $document = Read-XmlDocument -Path $Path
    if ($document.DocumentElement.LocalName -ne 'manifest') {
        throw "Android manifest root element is invalid: $Path"
    }
    $namespaceManager = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
    $namespaceManager.AddNamespace('android', $androidNamespace)
    $nodes = $document.SelectNodes(
        "/*[local-name()='manifest']/*[starts-with(local-name(), 'uses-permission')]",
        $namespaceManager
    )
    foreach ($node in $nodes) {
        # A high-priority tools:node="remove" marker strips a permission that a
        # dependency requested; it is a privacy control, not an app request.
        if ($node.GetAttribute('node', $toolsNamespace) -eq 'remove') {
            continue
        }
        $name = $node.GetAttribute('name', $androidNamespace)
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $name
        }
    }
}

function Assert-ManifestPermissions {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )

    $permissions = @(Get-ManifestPermissions -Path $Path | Sort-Object -Unique)
    $rejected = @($permissions | Where-Object { -not $allowedPermissions.Contains($_) })
    if ($rejected.Count -gt 0) {
        throw "Disallowed permission(s) in $Label manifest: $($rejected -join ', ')"
    }
    if ($permissions -notcontains 'android.permission.CAMERA') {
        throw "Required CAMERA permission missing from $Label manifest: $Path"
    }
}

function Assert-ManifestBackupPolicy {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )

    $document = Read-XmlDocument -Path $Path
    $application = $document.DocumentElement.SelectSingleNode("*[local-name()='application']")
    if ($null -eq $application -or
        $application.GetAttribute('allowBackup', $androidNamespace) -ne 'false' -or
        $application.GetAttribute('fullBackupContent', $androidNamespace) -ne 'false' -or
        $application.GetAttribute('dataExtractionRules', $androidNamespace) -ne '@xml/data_extraction_rules') {
        throw "Android backup/data-extraction protection is incomplete in $Label manifest."
    }
}

Assert-ManifestPermissions -Path $sourceManifest -Label 'Android source'
Assert-ManifestBackupPolicy -Path $sourceManifest -Label 'Android source'

$rulesDocument = Read-XmlDocument -Path $dataExtractionRules
$requiredDomains = @(
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref'
)
foreach ($sectionName in @('cloud-backup', 'device-transfer')) {
    $section = $rulesDocument.DocumentElement.SelectSingleNode("*[local-name()='$sectionName']")
    if ($null -eq $section) {
        throw "Android data extraction rules are missing $sectionName."
    }
    $excludedDomains = @(
        $section.SelectNodes("*[local-name()='exclude' and @path='.']") |
            ForEach-Object { $_.GetAttribute('domain') }
    )
    $missingDomains = @($requiredDomains | Where-Object { $excludedDomains -notcontains $_ })
    if ($missingDomains.Count -gt 0) {
        throw "Android $sectionName rules do not exclude: $($missingDomains -join ', ')"
    }
}

$pubspec = Join-Path $projectDir 'pubspec.yaml'
$bannedDependency = Select-String -LiteralPath $pubspec -Pattern '^\s+(firebase_|sentry|http:|dio:|amplitude_|mixpanel_)'
if ($null -ne $bannedDependency) {
    throw "Banned network/analytics dependency found in pubspec.yaml at line $($bannedDependency.LineNumber)."
}

$mergedManifests = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$knownManifests = @(
    'build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml',
    'build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml',
    'build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml'
)
foreach ($relativePath in $knownManifests) {
    $candidate = Join-Path $projectDir $relativePath
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        [void]$mergedManifests.Add((Resolve-Path -LiteralPath $candidate).Path)
    }
}

$intermediates = Join-Path $projectDir 'build/app/intermediates'
if (Test-Path -LiteralPath $intermediates -PathType Container) {
    Get-ChildItem -LiteralPath $intermediates -Recurse -File -Filter AndroidManifest.xml |
        Where-Object { $_.FullName -match '[\\/]release[\\/]' } |
        ForEach-Object { [void]$mergedManifests.Add($_.FullName) }
}

$releaseApk = Join-Path $projectDir 'build/app/outputs/flutter-apk/app-release.apk'
$requireMergedEffective = $RequireMerged.IsPresent -or
    $env:ROSID_REQUIRE_MERGED_MANIFEST -eq '1' -or
    $env:GITHUB_REF_TYPE -eq 'tag' -or
    (Test-Path -LiteralPath $releaseApk -PathType Leaf)

foreach ($manifest in $mergedManifests) {
    Assert-ManifestPermissions -Path $manifest -Label 'Android merged release'
    Assert-ManifestBackupPolicy -Path $manifest -Label 'Android merged release'
}

if ($mergedManifests.Count -eq 0) {
    if ($requireMergedEffective) {
        throw 'Merged release manifest required but none was found; refusing a source-only pass.'
    }
    Write-Output 'Offline source audit passed; merged release manifest not requested.'
} else {
    Write-Output "Offline release audit passed across $($mergedManifests.Count) merged manifest(s)."
}
