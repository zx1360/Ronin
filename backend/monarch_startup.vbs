Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "D:\products\Go\monarch"
WshShell.Run "D:\products\Go\monarch\cmd.exe", 0, False
