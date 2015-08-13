function Invoke-OperationHelper
{
     param([string]$machineGroupName,
           [string]$operationName,
          [Microsoft.VisualStudio.Services.DevTestLabs.Model.ResourceV2[]]$machines)

    Write-Verbose "Entered perform action $operationName on machines for machine group $machineGroupName" -Verbose
    
    if(! $machines)
    {
        return
    }

    $machineStatus = "Succeeded"
    
    # Logs in the Dtl service that operation has started.
    $operationId = Invoke-MachineGroupOperation -machineGroupName $machineGroupName -operationName $operationName -machines $machines

    if($machines.Count -gt 0)
    {
       $passedOperationCount = $machines.Count
    }

    Foreach($machine in $machines)
    {
        $machineName = $machine.Name
        $operation = Invoke-OperationOnProvider -machineGroupName $machineGroupName -machineName $machine.Name -operationName $operationName
        Write-Verbose "[Azure Resource Manager]Call to provider to perform operation '$operationName' on the machine '$machineName' completed" -Verbose

        # Determines the status of the operation. Marks the status of machine group operation as 'Failed' if any one of the machine operation fails.
        if(! $operation)
        {
            $status = "Failed"
            $machineStatus = "Failed"
            $passedOperationCount--
            Write-Warning(Get-LocalizedString -Key "Operation '{0}' on machine '{1}' failed" -ArgumentList $operationName, $machine.Name)
        }
        else
        {
            $status = $operation.Status
            if($status -ne "Succeeded")
            {
                $machineStatus = "Failed"
                $passedOperationCount--
                Write-Warning(Get-LocalizedString -Key "Operation '{0}' on machine '{1}' failed with error '{2}'" -ArgumentList $operationName, $machine.Name, $operation.Error.Message)
            }
            else
            {
                 Write-Verbose "'$operationName' operation on the machine '$machineName' succeeded" -Verbose
            }
        }
        
        # Logs the completion of particular machine operation. Updates the status based on the provider response.
        End-MachineOperation -machineGroupName $machineGroupName -machineName $machine.Name -operationName $operationName -operationId $operationId -status $status -error $operation.Error.Message
    }

    # Logs completion of the machine group operation.
    End-MachineGroupOperation -machineGroupName $machineGroupName -operationName operationName -operationId $operationId -status $machineStatus
    Throw-ExceptionIfOperationFailesOnAllMachine -passedOperationCount $passedOperationCount -operationName $operationName -machineGroupName $machineGroupName
}

function Delete-MachinesHelper
{
    param([string]$machineGroupName,
          [string]$filters,
          [Microsoft.VisualStudio.Services.DevTestLabs.Model.ResourceV2[]]$machines)

    Write-Verbose "Entered delete machines for the machine group $machineGroupName" -Verbose

    # If filters are not provided then deletes the entire machine group.
    if(! $Filters)
    {
       Delete-MachineGroupFromProvider -machineGroupName $MachineGroupName
    }
    else
    {
      # If there are no machines corresponding to given machine names or tags then will not delete any machine.
      if(! $machines -or $machines.Count -eq 0)
      {
          return
      }
  
      $passedOperationCount = $machines.Count
      Foreach($machine in $machines)
      {
          $response = Delete-MachineFromProvider -machineGroupName $machineGroupName -machineName $machine.Name 
          if($response -ne "Succedded")
           {
              $passedOperationCount--
           }
          else
           {
              $filter = $filter + $machine.Name + ","
           }
      }
    }
    
    Throw-ExceptionIfOperationFailesOnAllMachine -passedOperationCount $passedOperationCount -operationName $operationName -machineGroupName $machineGroupName
    # Deletes the machine or machine group from Dtl
    Delete-MachineGroup -machineGroupName $MachineGroupName -filters $filter
}

function Invoke-OperationOnProvider
{
    param([string]$machineGroupName,
          [string]$machineName,
          [string]$operationName)
 
    # Performes the operation on provider based on the operation name.
    Switch ($operationName)
    {
         "Start" {
             $operation = Start-MachineInProvider -machineGroupName $machineGroupName -machineName $machineName
         }

         "Stop" {
             $operation = Stop-MachineInProvider -machineGroupName $machineGroupName -machineName $machineName
         }

         "Restart" {
             $operation = Restart-MachineInProvider -machineGroupName $machineGroupName -machineName $machineName
         }
 
         default {
              throw (Get-LocalizedString -Key "Tried to invoke an invalid operation: '{0}'" -ArgumentList $operationName)
         }
    }
    return $operation
}

# Task fails if operation fails on all the machines
function Throw-ExceptionIfOperationFailesOnAllMachine
{
   param([string]$passedOperationCount,
         [string]$operationName,
         [string]$machineGroupName)

  if(($passedOperationCount -ne $null) -and ($passedOperationCount -eq 0))
  {
        throw ( Get-LocalizedString -Key "Operation '{0}' failed on the machines in '{1}'" -ArgumentList $operationName, $machineGroupName )
  }
}

# Gets the tags in correct format
function Get-WellFormedTagsList
{
    [CmdletBinding()]
    Param
    (
        [string]$tagsListString
    )

    if([string]::IsNullOrWhiteSpace($tagsListString))
    {
        return $null
    }

    $tagsArray = $tagsListString.Split(';')
    $tagList = New-Object 'System.Collections.Generic.List[Tuple[string,string]]'
    foreach($tag in $tagsArray)
    {
        if([string]::IsNullOrWhiteSpace($tag)) {continue}
        $tagKeyValue = $tag.Split(':')
        if($tagKeyValue.Length -ne 2)
        {
            throw (Get-LocalizedString -Key 'Please have the tags in this format Role:Web,Db;Tag2:TagValue2;Tag3:TagValue3')
        }

        if([string]::IsNullOrWhiteSpace($tagKeyValue[0]) -or [string]::IsNullOrWhiteSpace($tagKeyValue[1]))
        {
            throw (Get-LocalizedString -Key 'Please have the tags in this format Role:Web,Db;Tag2:TagValue2;Tag3:TagValue3')
        }

        $tagTuple = New-Object "System.Tuple[string,string]" ($tagKeyValue[0].Trim(), $tagKeyValue[1].Trim())
        $tagList.Add($tagTuple) | Out-Null
    }

    $tagList = [System.Collections.Generic.IEnumerable[Tuple[string,string]]]$tagList
    return ,$tagList
}