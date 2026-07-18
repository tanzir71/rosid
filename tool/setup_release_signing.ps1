param(
  [string]$Repository = 'tanzir71/rosid',
  [string]$BackupDirectory = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Rosid\ReleaseKey')
)

$ErrorActionPreference = 'Stop'

$keytool = (Get-Command keytool -ErrorAction Stop).Source
$gh = (Get-Command gh -ErrorAction Stop).Source

& $gh api --method PUT "repos/$Repository/environments/android-release" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Could not create or verify the android-release GitHub environment.'
}

$completionSecretName = 'ANDROID_KEYSTORE_BASE64'
$expectedSecretNames = @(
  $completionSecretName,
  'ANDROID_KEY_ALIAS',
  'ANDROID_KEY_PASSWORD',
  'ANDROID_STORE_PASSWORD'
)
$secretListArguments = @(
  'secret', 'list',
  '--env', 'android-release',
  '--repo', $Repository,
  '--json', 'name',
  '--jq', '.[].name'
)
$existingSecretNames = @(& $gh @secretListArguments)
if ($LASTEXITCODE -ne 0) {
  throw 'Could not enumerate android-release environment secrets. Refusing to continue.'
}
$existingReleaseSecretNames = @(
  $expectedSecretNames | Where-Object { $existingSecretNames -contains $_ }
)
if ($existingReleaseSecretNames.Count -ne 0) {
  $existingReleaseSecretList = $existingReleaseSecretNames -join ', '
  if ($existingReleaseSecretNames.Count -eq $expectedSecretNames.Count) {
    throw "Android release secrets already exist ($existingReleaseSecretList). Refusing to rotate the signing key."
  }

  $missingReleaseSecretNames = @(
    $expectedSecretNames | Where-Object { $existingSecretNames -notcontains $_ }
  )
  $missingReleaseSecretList = $missingReleaseSecretNames -join ', '
  $completionState = if ($existingSecretNames -contains $completionSecretName) {
    'present unexpectedly'
  } else {
    'missing'
  }
  throw "Partial Android release secret set detected (present: $existingReleaseSecretList; missing: $missingReleaseSecretList; completion sentinel: $completionState). Refusing to rotate the signing key. Reconcile the partial secrets using the existing backup before retrying."
}

if (Test-Path -LiteralPath $BackupDirectory) {
  if ((Get-ChildItem -Force -LiteralPath $BackupDirectory | Measure-Object).Count -ne 0) {
    throw "Refusing to overwrite existing release-key material: $BackupDirectory"
  }
} else {
  New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
}

$acl = New-Object System.Security.AccessControl.DirectorySecurity
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  $identity,
  'FullControl',
  'ContainerInherit,ObjectInherit',
  'None',
  'Allow'
)
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
  'NT AUTHORITY\SYSTEM',
  'FullControl',
  'ContainerInherit,ObjectInherit',
  'None',
  'Allow'
)
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule($userRule)
$acl.AddAccessRule($systemRule)
Set-Acl -LiteralPath $BackupDirectory -AclObject $acl

$keystorePath = Join-Path $BackupDirectory 'rosid-release.jks'
$keyAlias = 'rosid'

$passwordBytes = New-Object byte[] 32
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
  $random.GetBytes($passwordBytes)
} finally {
  $random.Dispose()
}
$releasePassword = ([System.BitConverter]::ToString($passwordBytes)).Replace('-', '')

$generateOutput = Join-Path $BackupDirectory 'keytool-generation.log'
$generateError = Join-Path $BackupDirectory 'keytool-generation-error.log'
$keytoolArguments = @(
  '-genkeypair',
  '-v',
  '-keystore', "`"$keystorePath`"",
  '-storetype', 'PKCS12',
  '-keyalg', 'RSA',
  '-keysize', '4096',
  '-validity', '10000',
  '-alias', $keyAlias,
  '-storepass:env', 'ROSID_RELEASE_STORE_PASSWORD',
  '-keypass:env', 'ROSID_RELEASE_KEY_PASSWORD',
  '-dname', 'CN=Rosid,OU=Release,O=Rosid,L=Dhaka,ST=Dhaka,C=BD',
  '-noprompt'
)
$generateProcessArguments = @{
  FilePath = $keytool
  ArgumentList = $keytoolArguments
  Wait = $true
  PassThru = $true
  NoNewWindow = $true
  RedirectStandardOutput = $generateOutput
  RedirectStandardError = $generateError
}
try {
  $env:ROSID_RELEASE_STORE_PASSWORD = $releasePassword
  $env:ROSID_RELEASE_KEY_PASSWORD = $releasePassword
  $keytoolProcess = Start-Process @generateProcessArguments
} finally {
  Remove-Item Env:\ROSID_RELEASE_STORE_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\ROSID_RELEASE_KEY_PASSWORD -ErrorAction SilentlyContinue
}
if ($keytoolProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $keystorePath)) {
  throw "keytool failed. Inspect $generateError"
}

$credentials = @"
Rosid Android release signing backup
Created: $(Get-Date -Format o)
Repository: https://github.com/$Repository
Keystore: rosid-release.jks
Alias: $keyAlias
Store password: $releasePassword
Key password: $releasePassword

Keep this directory private and back it up securely. Losing this key prevents
existing Android installs from accepting future updates.
"@
[System.IO.File]::WriteAllText(
  (Join-Path $BackupDirectory 'credentials.txt'),
  $credentials,
  (New-Object System.Text.UTF8Encoding($false))
)

$listOutput = Join-Path $BackupDirectory 'keytool-list.log'
$listError = Join-Path $BackupDirectory 'keytool-list-error.log'
$listArguments = @(
  '-list',
  '-v',
  '-keystore', "`"$keystorePath`"",
  '-storepass:env', 'ROSID_RELEASE_STORE_PASSWORD',
  '-alias', $keyAlias
)
$listProcessArguments = @{
  FilePath = $keytool
  ArgumentList = $listArguments
  Wait = $true
  PassThru = $true
  NoNewWindow = $true
  RedirectStandardOutput = $listOutput
  RedirectStandardError = $listError
}
try {
  $env:ROSID_RELEASE_STORE_PASSWORD = $releasePassword
  $env:ROSID_RELEASE_KEY_PASSWORD = $releasePassword
  $listProcess = Start-Process @listProcessArguments
} finally {
  Remove-Item Env:\ROSID_RELEASE_STORE_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\ROSID_RELEASE_KEY_PASSWORD -ErrorAction SilentlyContinue
}
if ($listProcess.ExitCode -ne 0) {
  throw "Could not inspect the generated key. Inspect $listError"
}

$fingerprintLine = Get-Content -LiteralPath $listOutput |
  Select-String -Pattern 'SHA256:' |
  Select-Object -First 1
$fingerprint = ($fingerprintLine.Line -replace '^.*SHA256:\s*', '')
$fingerprint = $fingerprint.Replace(':', '').Trim().ToUpperInvariant()
if ($fingerprint -notmatch '^[0-9A-F]{64}$') {
  throw 'The generated signing-certificate fingerprint is malformed.'
}

$keystoreBase64 = [Convert]::ToBase64String(
  [System.IO.File]::ReadAllBytes($keystorePath)
)

$environmentPolicy = '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
$environmentPolicyArguments = @(
  'api',
  '--method', 'PUT',
  "repos/$Repository/environments/android-release",
  '--input', '-'
)
$environmentPolicy | & $gh @environmentPolicyArguments | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Could not restrict the android-release environment to custom refs.'
}
$policies = & $gh api "repos/$Repository/environments/android-release/deployment-branch-policies" |
  ConvertFrom-Json
$hasReleaseTagPolicy = @($policies.branch_policies | Where-Object {
  $_.name -eq 'v*' -and $_.type -eq 'tag'
}).Count -gt 0
if (-not $hasReleaseTagPolicy) {
  $tagPolicyArguments = @(
    'api',
    '--method', 'POST',
    "repos/$Repository/environments/android-release/deployment-branch-policies",
    '-f', 'name=v*',
    '-f', 'type=tag'
  )
  & $gh @tagPolicyArguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw 'Could not add the v* deployment-tag policy.'
  }
}

$secrets = @(
  @{ Name = 'ANDROID_KEY_ALIAS'; Value = $keyAlias },
  @{ Name = 'ANDROID_KEY_PASSWORD'; Value = $releasePassword },
  @{ Name = 'ANDROID_STORE_PASSWORD'; Value = $releasePassword },
  # Upload the keystore last so a failed upload does not publish the completion sentinel.
  @{ Name = 'ANDROID_KEYSTORE_BASE64'; Value = $keystoreBase64 }
)
foreach ($entry in $secrets) {
  $entry.Value | & $gh secret set $entry.Name --env android-release --repo $Repository | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Could not configure GitHub environment secret $($entry.Name). Partial remote secrets may remain; reconcile them using $BackupDirectory before retrying."
  }
}

Write-Output "Release key backup: $BackupDirectory"
Write-Output "Certificate SHA-256: $fingerprint"
Write-Output 'GitHub android-release environment secrets configured.'
