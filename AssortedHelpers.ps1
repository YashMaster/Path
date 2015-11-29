#Removes duplicates from %PATH%
#Source: https://gallery.technet.microsoft.com/scriptcenter/How-to-check-for-duplicate-5d9dd711
Function Clean-PathDuplicates
{
	$RegKey = ([Microsoft.Win32.Registry]::LocalMachine).OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment", $True)
	$PathValue = $RegKey.GetValue("Path", $Null, "DoNotExpandEnvironmentNames")
	Write-host "Original path :" + $PathValue
	$PathValues = $PathValue.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
	$IsDuplicate = $False
	$NewValues = @()

	foreach ($Value in $PathValues)
	{
		if ($NewValues -notcontains $Value)
			{$NewValues += $Value}
		else
			{$IsDuplicate = $True}
	}

	if ($IsDuplicate)
	{
		$NewValue = $NewValues -join ";"
		$RegKey.SetValue("Path", $NewValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
		Write-Host "Duplicate PATH entry found and new PATH built removing all duplicates. New Path :" + $NewValue
	}
	else
		{Write-Host "No Duplicate PATH entries found. The PATH will remain the same." }
	
	$RegKey.Close()
}


#Prints invocations
Function Write-Invocation
{
	Write-Verbose "FUNC: PSCommandPath: $PSCommandPath"
	Write-Verbose "FUNC: PSScriptRoot: $PSScriptRoot"
	Write-Verbose "FUNC: Invocation: $($MyInvocation)"
	Write-Verbose "FUNC: Invocation: $($MyInvocation.Line)"
	Write-Verbose "FUNC: Invocation: $($MyInvocation.MyCommand)"
	Write-Verbose "FUNC: Invocation: $($MyInvocation.MyCommand.Path)"
	Write-Verbose "FUNC: Invocation: $($MyInvocation.MyCommand.Name)"
}