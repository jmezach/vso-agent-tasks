param(
    [Parameter(Mandatory=$true)][string]$TaskPath,
    [Parameter(Mandatory=$true)][string]$TfsUrl,
    [PSCredential]$Credential = (Get-Credential),
    [switch]$Overwrite = $false
)

# Load task definition from the JSON file
$taskDefinition = (Get-Content $taskPath\task.json) -join "`n" | ConvertFrom-Json
$taskFolder = Get-Item $TaskPath

# Determine the URL that we need to go to
$url = "$TfsUrl/_apis/distributedtask/tasks"
if ($Overwrite) {
    $url = $url + "?overwrite=true"
}

# Create the task definition
Write-Output "Creating task definition"
$headers = @{ "Accept" = "application/json; api-version=1.0"; "X-TFS-FedAuthRedirect" = "Suppress" }
Invoke-RestMethod -Uri $url -Credential $Credential -Headers $headers -ContentType application/json -Method Put -Body (ConvertTo-Json $taskDefinition)

# Zip the task content
Write-Output "Zipping task content"
$taskZip = "$taskFolder\..\$($taskDefinition.id).zip"
if (Test-Path $taskZip) { Remove-Item $taskZip }

Add-Type -AssemblyName "System.IO.Compression.FileSystem"
[IO.Compression.ZipFile]::CreateFromDirectory($taskFolder, $taskZip)

# Upload task content
Write-Output "Uploading task content"
$taskZipItem = Get-Item $taskZip
$headers.Add("Content-Range", "bytes 0-$($taskZipItem.Length - 1)/$($taskZipItem.Length)")
$url = "$TfsUrl/_apis/distributedtask/tasks/$($taskDefinition.id)/$($taskDefinition.version.Major).$($taskDefinition.version.Minor).$($taskDefinition.version.Patch)"
Invoke-RestMethod -Uri $url -Credential $Credential -Headers $headers -ContentType application/octet-stream -Method Put -InFile $taskZipItem