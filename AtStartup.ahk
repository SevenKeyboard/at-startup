#Requires AutoHotkey v1.1.35+
;==============================================================
; AtStartup — Manage program auto-start registration via Run keys and startup folders
;
; GitHub: https://github.com/SevenKeyboard/at-startup
; Author: SevenKeyboard Ltd. (2025)
; License: The Unlicense
;==============================================================
class VersionManager_AtStartup
{
    static _ := VersionManager_AtStartup._init()
    _init()    {
        global
        ATSTARTUP_VERSION := "2.0.1"
    }
}
Class AtStartup
{
    ;                       HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
    class HKCU
    {
        static _keyName := "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        
        register(valueName, fullPath := "", commandLineArguments := "", overwrite := true)    {
            if (valueName == "")
                return
            fullPath := fullPath !== "" ? fullPath : A_ScriptFullPath
            if (260 < strLen(fullPath))
                return
            ok := true
            try  {
                regRead _, % this._keyName, % valueName
            }  catch  {
                ok := false
            }
            if (overwrite || !ok)
                regWrite % "REG_SZ", % this._keyName, % valueName, % this._joinCmdLine(fullPath, commandLineArguments)        
        }
        unregister(valueName)    {
            if (valueName == "")
                return
            ok := true
            try  {
                regRead _, % this._keyName, % valueName
            }  catch  {
                ok := false
            }
            if (ok)
                regDelete % this._keyName, % valueName
        }
        isRegistered(valueName, fullPath := "", commandLineArguments := "")    {
            if (valueName == "")
                return 0
            fullPath := fullPath !== "" ? fullPath : A_ScriptFullPath
            ok := true
            try  {
                regRead prevCmdLine, % this._keyName, % valueName
            }  catch  {
                ok := false
            }
            if (!ok)
                return false
            prevArgv    := this._commandLineToArgvW(prevCmdLine)
            newArgv     := this._commandLineToArgvW(this._joinCmdLine(fullPath, commandLineArguments))
            if (prevArgv.length() !== newArgv.length())
                return false
            for i, arg in prevArgv    {
                if (arg !== newArgv[i])
                    return false
            }
            return true
        }
        ;--------------------------------------------------
        _joinCmdLine(fullPath, commandLineArguments)    {
            return """" fullPath """" . (commandLineArguments !== "" ? " " commandLineArguments : "")
        }
        _commandLineToArgvW(cmdLine := "")    {
            args := []
            if (pArgs:=dllCall("Shell32.dll\CommandLineToArgvW", "WStr",cmdLine, "Ptr*",nArgs, "Ptr"))    {
                loop % nArgs
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
            loop Files, % A_Startup "\*.lnk", F
            {
                fileGetShortcut % A_Startup "\" A_LoopFileName, outTarget
            }
            fileCreateShortcut % A_ScriptFullPath, % A_Startup "\" ScriptOwnName ".lnk"
        }
        */
    }
    class ProgramData
    {
    }
}