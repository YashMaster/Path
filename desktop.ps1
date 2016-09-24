<#
.SYNOPSIS
   Navigates to the desktop.

.DESCRIPTION
	This is just an alias... I should probably just make this an alias. Why isn't this an alias?	
#>

[cmdletbinding()] 
Param()

$desktop = [Environment]::GetFolderPath("Desktop")
cd $desktop