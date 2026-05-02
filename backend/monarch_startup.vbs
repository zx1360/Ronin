Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "D:\products\Ronin\backend"
WshShell.Run "D:\products\Ronin\backend\cmd.exe", 0, False
