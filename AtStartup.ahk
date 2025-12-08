#Requires AutoHotkey v2.0.0+
;==============================================================
; AtStartup — Manage program auto-start registration via Run keys and startup folders
;
; GitHub: https://github.com/SevenKeyboard/at-startup
; Author: SevenKeyboard Ltd. (2025)
; License: The Unlicense
;==============================================================
class VersionManager_AtStartup
{
    static _ := this._init()
    static _init()    {
        global
        ATSTARTUP_VERSION := "2.0.0"
    }
}
Class AtStartup
{
    ;                       HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    class HKCU
    {
        static _keyName := "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        
        static register(valueName, fullPath := A_ScriptFullPath, commandLineArguments := "", overwrite := true)    {
            if (valueName == "")
                return
            if (260 < strLen(fullPath))
                return
            isEmpty := false
            try  {
                regRead(this._keyName, valueName)
            }  catch  {
                isEmpty := true
            }
            if (overwrite || isEmpty)
                regWrite(this._joinCmdLine(fullPath, commandLineArguments), "REG_SZ", this._keyName, valueName)
        }
        static unregister(valueName)    {
            if (valueName == "")
                return
            isEmpty := false
            try  {
                regRead(this._keyName, valueName)
            }  catch  {
                isEmpty := true
            }
            if (!isEmpty)
                regDelete(this._keyName, valueName)
        }
        static isRegistered(valueName, fullPath := A_ScriptFullPath, commandLineArguments := "")    {
            if (valueName == "")
                return 0
            try  {
                prevCmdLine := regRead(this._keyName, valueName)
            }  catch  {
                return false
            }
            prevArgv    := this._commandLineToArgvW(prevCmdLine)
            newArgv     := this._commandLineToArgvW(this._joinCmdLine(fullPath, commandLineArguments))
            if (prevArgv.Length !== newArgv.Length)
                return false
            for i, arg in prevArgv    {
                if (arg !== newArgv[i])
                    return false
            }
            return true
        }
        ;--------------------------------------------------
        static _joinCmdLine(fullPath, commandLineArguments)    {
            return '"' fullPath '"' . (commandLineArguments !== "" ? " " commandLineArguments : "")
        }
        static _commandLineToArgvW(cmdLine := "")    {
            args := []
            if (pArgs:=dllCall("Shell32.dll\CommandLineToArgvW", "WStr",cmdLine, "Ptr*",&nArgs:=0, "Ptr"))    {
                loop nArgs
                    args.push(strGet(numGet((A_Index-1)*A_PtrSize+pArgs,"Ptr"),"UTF-16"))
                dllCall("Kernel32.dll\LocalFree", "Ptr",pArgs)
            }
            return args
        }
    }
    ;  SetRegView, 64       HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    ;  SetRegView, 32       HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run
    class HKLM
    {
    }
    ;  A_StartupCommon      C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup
    ;  A_Startup            C:\Users\<UserName>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
    class AppData
    {
        /*
        if (fileExist(A_Startup))    {
            loop files, A_Startup "\*.lnk", "F"
            {
                fileGetShortcut(A_Startup "\" A_LoopFileName, &outTarget)
            }
            fileCreateShortcut(A_ScriptFullPath, A_Startup "\" ScriptOwnName ".lnk")
        }
        */
    }
    class ProgramData
    {
    }
}