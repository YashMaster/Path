# another way to send keys
$Shell = new-object -comobject WScript.Shell
$Shell.SendKeys("^{Esc}")
Sleep -milliseconds 1000

	#Wait till the device is booted again
	for($i=0; $i -lt 5; $i++)
	{
		Sleep 10
		
		#If this fails, it will force Tshell to disconnect. If it succeedds, then the device is on and booted.
		cmdd dir
		if($?) 
			{break}
		
		#If it succeeds, then the device is back up
		Open-Device 127.0.0.1
		if($?) 
			{break}
	}