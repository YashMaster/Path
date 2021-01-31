for($i=0; $i -eq 0;)
{
	$Shell = new-object -comobject WScript.Shell
	$Shell.SendKeys("^{Esc}")
	Sleep 100
}