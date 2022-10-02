D language and engine setup

# Tools needed and installation

You'll need:

* the LDC2 compiler.
* the dub build system (included with LDC2 by default).
* a code editor (e.g. VSCode), or an IDE (e.g. Visual Studio), that can work with D code.
* a debugger (Visual Studio or x64dbg under Windows, ldb or gdb under Linux).

Visual Studio's debugger can be still used even if the IDE part isn't, simply by:
1. Install the VisualD extension (works without it, but won't highlight the D code).
2. Setting up an empty C++ console project (not a D one!).
3. In the "Debug Property Pages" switch to "Configuration Properties" then "Debugging".
4. Set "Command" to the compiled executable, then "Working Directory" to the directory where the executable resides.
5. Run the project without compiling.

VSCode works under AArch64 with no problem, but serve-d's build script might have to be edited to include `--lowmem` to
avoid running running out of memory during compilation (is an issue under Raspberry Pi400).

## Installing the LDC2 compiler

On Linux, you can type `curl -fsS https://dlang.org/install.sh | bash -s ldc`, to install the compiler, then add it to 
your path (google it if you need help). On Windows, you can download the latest release from 
`https://github.com/ldc-developers/ldc/releases` and extract it into a folder, then set up the path variables in 
"System Properties" > "Advanced" > "Environment Variables" > either "User variables" > "Path" or "System variables" >
"Path".

Besides of the D compiler, you might also want to install some standard C++ stuff for Windows (Visual C++ tools 
recommended).

It'll contain the dub build system too, which will make things easier. So far it's the friendliest build tool, although
that doesn't say too much since most build tools are as unfriendly as possible.

# Setting up a project

