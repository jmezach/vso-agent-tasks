param(
    [string]$solution,
    [string]$feed,
    [ValidateSet("Restore", "Install")]
    [string]$restoreMode = "Restore",
    [string]$excludeVersion, # Support for excludeVersion has been deprecated.
    [string]$noCache,
    [string]$nuGetRestoreArgs,
    [string]$nuGetPath
)

Write-Verbose "Entering script $MyInvocation.MyCommand.Name"
Write-Verbose "Parameter Values"
foreach($key in $PSBoundParameters.Keys)
{
    Write-Verbose ($key + ' = ' + $PSBoundParameters[$key])
}

import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

if(!$solution)
{
    throw (Get-LocalizedString -Key "Solution parameter must be set")
}

if ($feed)
{
    # get connected service endpoint and use its Url as the source
    $nugetFeedEndpoint = Get-ServiceEndpoint -Name $feed -Context $distributedTaskContext
    $args = " -Source $($nugetFeedEndpoint.Url)"
}

$b_excludeVersion = Convert-String $excludeVersion Boolean
$b_noCache = Convert-String $noCache Boolean

# Warn if deprecated parameters were supplied.
if ($excludeVersion -and "$excludeVersion".ToUpperInvariant() -ne 'FALSE')
{
    Write-Warning (Get-LocalizedString -Key 'The Exclude Version parameter has been deprecated. Ignoring the value.')
}

# check for solution pattern
if ($solution.Contains("*") -or $solution.Contains("?"))
{
    Write-Verbose "Pattern found in solution parameter."
    Write-Verbose "Find-Files -SearchPattern $solution"
    $solutionFiles = Find-Files -SearchPattern $solution
    Write-Verbose "solutionFiles = $solutionFiles"
}
else
{
    Write-Verbose "No Pattern found in solution parameter."
    $solutionFiles = ,$solution
}

if (!$solutionFiles)
{
    throw (Get-LocalizedString -Key "No solution was found using search pattern '{0}'." -ArgumentList $solution)
}

$args = (" -NonInteractive " + $args);
if($b_noCache)
{
    $args = (" -NoCache " + $args);
}

if(!$nuGetPath)
{
    $nuGetPath = Get-ToolPath -Name 'NuGet.exe';
}

if($nuGetRestoreArgs)
{
    $args = ($args + " " + $nuGetRestoreArgs);
}


if (-not $nugetPath)
{
    throw (Get-LocalizedString -Key "Unable to locate {0}" -ArgumentList 'nuget.exe')
}

foreach($sf in $solutionFiles)
{
    if($nuGetPath)
    {
        $slnFolder = $(Get-ItemProperty -Path $sf -Name 'DirectoryName').DirectoryName

        Write-Verbose "Searching for nuget package configuration files using pattern $slnFolder\**\packages.config"
        $pkgConfig = Find-Files -SearchPattern "$slnFolder\**\packages.config"
        if ($pkgConfig)
        {
            Write-Verbose "Running nuget package restore for $slnFolder"
            Invoke-Tool -Path $nugetPath -Arguments "restore `"$sf`" $args" -WorkingFolder $slnFolder
        }
        else
        {
            Write-Verbose "No nuget package configuration files found for $sf"
        }
    }
}
