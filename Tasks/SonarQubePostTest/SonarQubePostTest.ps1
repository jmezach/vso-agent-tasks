Write-Verbose "Starting SonarQube PostBuild Step"
	
if ($env:BUILDCONFIGURATION -ne "Release")
{
    Write-Host "SonarQube analysis is only run for release mode."
    return
}

import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

. ./SonarQubePostTestImpl.ps1
. ./CodeAnalysisFilePathComputation.ps1

InvokeMsBuildRunnerPostTest
UploadSummaryMdReport
HandleCodeAnalysisReporting
