<#
.SYNOPSIS
   Quits the running PowerShell instance.

.DESCRIPTION
	This is just an alias for exit... I should probably just make this an alias. Why isn't this an alias?	
#>

[cmdletbinding()] 
Param()

$host.SetShouldExit(0)