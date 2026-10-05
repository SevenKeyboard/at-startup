//==============================================================
// AtStartup — Manage program auto-start registration via Run keys
//
// GitHub: https://github.com/SevenKeyboard/at-startup
// Author: SevenKeyboard Ltd. (2026)
// License: The Unlicense
//==============================================================

using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace SevenKeyboard
{
    public static class AtStartup
    {
        public static class HKCU
        {
            private const string KeyName = @"Software\Microsoft\Windows\CurrentVersion\Run";

            // Arguments are an already-quoted command line, not an array of arguments.
            // A null path uses the current process executable (not a DLL launched by dotnet).
            public static void Register(string valueName, string? fullPath = null, string commandLineArguments = "", bool overwrite = true)
            {
                ArgumentException.ThrowIfNullOrEmpty(valueName);
                if (valueName.Contains('\0'))
                    throw new ArgumentException("Embedded null characters are not supported.", nameof(valueName));

                fullPath ??= Environment.ProcessPath
                    ?? throw new InvalidOperationException("The current executable path is unavailable.");
                if (fullPath.Length > 260)
                    return;

                string commandLine = JoinCmdLine(fullPath, commandLineArguments);

                using RegistryKey key = Registry.CurrentUser.CreateSubKey(KeyName);
                if (!overwrite && key.GetValue(valueName) is not null)
                    return;

                key.SetValue(valueName, commandLine, RegistryValueKind.String);
            }

            public static void Unregister(string valueName)
            {
                ArgumentException.ThrowIfNullOrEmpty(valueName);
                if (valueName.Contains('\0'))
                    throw new ArgumentException("Embedded null characters are not supported.", nameof(valueName));

                using RegistryKey? key = Registry.CurrentUser.OpenSubKey(KeyName, writable: true);
                if (key is null)
                    return;

                key.DeleteValue(valueName, throwOnMissingValue: false);
            }

            public static bool IsRegistered(string valueName, string? fullPath = null, string commandLineArguments = "")
            {
                ArgumentException.ThrowIfNullOrEmpty(valueName);
                if (valueName.Contains('\0'))
                    throw new ArgumentException("Embedded null characters are not supported.", nameof(valueName));

                string commandLine = JoinCmdLine(fullPath, commandLineArguments);
                using RegistryKey? key = Registry.CurrentUser.OpenSubKey(KeyName);
                if (key is null)
                    return false;

                object? value = key.GetValue(valueName, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                if (value is not string previousCommandLine || previousCommandLine.Length == 0)
                    return false;

                string[] previousArguments = ParseCommandLine(previousCommandLine);
                string[] arguments = ParseCommandLine(commandLine);
                if (previousArguments.Length != arguments.Length)
                    return false;

                for (int i = 0; i < arguments.Length; i++)
                {
                    if (!string.Equals(previousArguments[i], arguments[i], StringComparison.Ordinal))
                        return false;
                }

                return true;
            }

            private static string JoinCmdLine(string? fullPath, string commandLineArguments)
            {
                ArgumentNullException.ThrowIfNull(commandLineArguments);
                if (commandLineArguments.Contains('\0'))
                    throw new ArgumentException("Embedded null characters are not supported.", nameof(commandLineArguments));

                fullPath ??= Environment.ProcessPath
                    ?? throw new InvalidOperationException("The current executable path is unavailable.");
                if (fullPath.Contains('\0'))
                    throw new ArgumentException("Embedded null characters are not supported.", nameof(fullPath));

                string commandLine = $"\"{fullPath}\"";
                if (commandLineArguments.Length > 0)
                    commandLine += " " + commandLineArguments;

                return commandLine;
            }

            private static string[] ParseCommandLine(string commandLine)
            {
                IntPtr argv = CommandLineToArgvW(commandLine, out int count);
                if (argv == IntPtr.Zero)
                    throw new Win32Exception(Marshal.GetLastWin32Error());

                try
                {
                    string[] arguments = new string[count];
                    for (int i = 0; i < count; i++)
                    {
                        IntPtr argument = Marshal.ReadIntPtr(argv, i * IntPtr.Size);
                        arguments[i] = Marshal.PtrToStringUni(argument)!;
                    }

                    return arguments;
                }
                finally
                {
                    LocalFree(argv);
                }
            }

            [DllImport("shell32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, SetLastError = true)]
            [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
            private static extern IntPtr CommandLineToArgvW(string lpCmdLine, out int pNumArgs);

            [DllImport("kernel32.dll", ExactSpelling = true)]
            [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
            private static extern IntPtr LocalFree(IntPtr hMem);
        }
    }
}
