##Start application
$process = New-Object System.Diagnostics.Process
$process.StartInfo.FileName = 'C:\\windows\\system32\\cmd.exe'
$process.StartInfo.RedirectStandardInput = 1
$process.StartInfo.RedirectStandardOutput = 1
$process.StartInfo.UseShellExecute = 0
$process.Start()

##Redirect input and output streams
$inputstream = $process.StandardInput
$outputstream = $process.StandardOutput

##Start encoder
$encoding = new-object System.Text.AsciiEncoding

$out = ''
##Read output stream
while($outputstream.Peek() -ne -1)
{
	$out += $encoding.GetString($outputstream.Read())
}
$out
$out = ''

while ($true)
{
	# Read next command
	$command = Read-Host -Prompt 'Enter the next command'
	$inputstream.writeline($command)

	$out = $encoding.GetString($outputstream.Read())

	##Verify Read output stream
	while($outputstream.Peek() -ne -1)
	{
		$out += $encoding.GetString($outputstream.Read())
	}
	$out.TrimEnd($inputstream.NewLine)

	$out = ''
}