# Import MSVC environment variables into MSYS2

## Summary

A simple Bash wrapper for the MSVC vcvarsall.bat and MSYS2 msys2_shell.cmd scripts.

## Usage

1. launch a MSYS2 Environment terminal from a shortcut in the Windows Start Menu (MSYS2 folder)
   or run `C:\msys64\msys2_shell.cmd` from a Command Prompt window or File Explorer
1. source [msys2-vcvars.sh](msys2-vcvars.sh) from the terminal or the shell script requiring the vcvars
1. call `vcvarsall` with the same arguments you would pass to vcvarsall.bat
   ([see here](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line#vcvarsall-syntax))  
   `vcvarsall` returns 0 on success
1. optionally call `vcvarsall /clean_env` to restore the original environment  
   (`/clean_env` is an undocumented option of vcvarsall.bat)

Any MSYS2 environment will work.
There is no need to edit the msys2_shell.cmd `MSYS2_PATH_TYPE` setting or `-use-full-path`
because the full Windows `%PATH%` is inherited explicitly.

Note: source msys2-vcvars.sh, don't exec it; its shebang is only for stand-alone testing.
Similarly, call function `vcvarsall` inline, as command substitution will import nothing.

## Details

This script simplifies importing MSVC and ClangCL path and environment variables into the current MSYS2 process or shell.

The normal steps to set up a MSYS2 MSVC environment are:
1. launch a Developer Command Prompt window from a Windows Start menu shortcut, or
run the vcvarsall.bat script from a normal Command Prompt window, then  
1. run the msys2_shell.cmd script in full-path inherit mode to launch a MSYS2 Environment terminal  

Instead, function `vcvarsall` delegates to the Visual Studio vcvarsall.bat (front end to VsDevCmd.bat) and MSYS2 msys2_shell.cmd scripts
to do the same task but in-process.

It uses `find` to locate vcvarsall.bat, not the complex vswhere.exe tool.
Alternatively, set `VCVARSALL_PATH` to the absolute path of vcvarsall.bat (Unix or Windows format).


## See also

- [vcvarsall syntax](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line#vcvarsall-syntax) – vcvarsall.bat parameters
- [extractvcvars.sh](https://cr.openjdk.org/~erikj/build-infra5/webrev.01/common/bin/extractvcvars.sh.html) – the inspiration
- [vcvars-bash](https://github.com/nathan818fr/vcvars-bash) – a similar tool
- [ffmpeg-makexe.sh](https://github.com/scriptituk/ffmpeg-makexe/blob/main/ffmpeg-makexe.sh) – example usage (search for vcvars)

