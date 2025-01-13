# Introduction

PixelPerfectEngine is a game engine/framework primarily designed for retro pixelart style games.

## Current engine features

* CPU rendered graphics.
* Live color lookup.
* Multiple tile and sprite layers.
* Era-accurate shimmering when scaling.
* Software synths for audio.
* Music/audio scripting system.
* Various collision detection systems.

## Planned engine features

* Moving most of the rendering to the GPU.
* Shadow/highlight effects.
* Physics subsystem.
* General purpose scripting.

## Donation

Patreon: https://www.patreon.com/ShapeshiftingLizard

The only hardware donation I might accept currently is some AArch64-based Windows PC, so I could also target that platform. 32 bit ARM devices are not considered as of now due to limited capacity. As of now, I cannot spend time on the ever changing APIs of Apple

You can also donate your testing time, knowledge, and coding directly to the engine.

# Getting started

## Requirements

The engine does not require a lot of computational power, however it requires:

* A 128 bit vector unit.
* OpenGL 2.1 or OpenGL ES 2.0 graphics. (OpenGL 3.3 / 3.0 ES recommended).
* At least 100MB free system memory.
* An audio device (low latency devices recommended).
* Some form of input device.

Also the engine is no longer being tested for 32 bit processors, contact me if you really need 32 bit support.

To build the engine, you'll need the LLVM D compiler (LDC), due to its stellar performance and better vector support. DMD no longer supported.

## Setting up developer environment and recommended toolchain

First, you'll need the LDC compiler. You can download it from the following link:

https://github.com/ldc-developers/ldc

It works on Windows, Linux, X86-64, AArch64, which are the platforms currently capable of running the engine. It'll also come with dub, which is one of the best build tools/package managers ever created.

As a development environment I recommend using VSCode or one of its community versions. There's a D extension by WebFreak, you'll need to install that. Optionally, you might want to install a C++ plugin with a debugger. Under Windows, you'll unfortuantely be needing Visual Studio itself for its linker and libraries.

Speaking of debuggers, under Linux, I have a lot of good luck with GDB. LLDB probably works too. Windows, on the other hand, is way more complicated. Since the engine now primarily targets 64 bit CPUs, our choice of debuggers are limited. VS and WinDBG works for sure, but really doesn't like D structs and pointers when the target is 64 bits. RemedyBG on the other hand, is a paid solution, however for most things, works better than any of Microsoft's own debuggers. Except break on exceptions, but it can be worked around by putting breakpoints into the constructors of the exceptions.

### Setting up Kate

As an alternative to VSCode, Kate is recommended. You'll need to install serve-d (just clone the repository, compile it with dub, then move the execuable into a folder added to your path), then it's ready to go.

## Paths

By default, the engine stores all executables in a `./bin-[CPUarch]-[OS]` subfolder, such as `./bin-x86_64-windows`. The engine will work without modification if the executables from that folder are moved to the root as long as it can detect the presence of the `./system` folder. It is recommended to use the function `resolvePath()` alongside with path symbols to avoid issues related to portability.

Path symbols are treated similar to the operating system's, and both starts and ends with a `%` symbol, e.g. `%SHADERS%`. The `%` symbol can be escaped by placing two of them side-by-side. Custom path symbols can be created with the line `pathSymbols["SYMBOLNAME"] = pathRoot ~ "/yourpath/";`. Path symbols also can used for other purposes, like localization settings. Can be escaped, e.g. `%%APPDATA%%` to access system paths.

### More important path symbols and folders.

 * `%PATH%`: points to the root where the current instance of the game engine resides. Might not be present of smartphones, consoles, etc.
 * `%EXEC%`: points to the folder of the current binary, could be either equal to `%PATH%`, or `%PATH%/bin-[CPUarch]-[OS]`.
 * `%SYSTEM%`: contains system assets in `%PATH%/system/`, like default configuration, default bindings, etc.
 * `%SHADERS%`: contains shaders in `%PATH%/shaders/`.
 * `%SHDRVER%`: contains the currently set shader version, intended to be used like `%SHADER%/final_%SHDRVER%.frag`.
 * `%LOCAL%`: contains localization files.
 * `%CURRLOCAL%`: contains the current localizaton setting, intended to be used like `%LOCAL%/texts_%CURRLOCAL%.xml`.

## Garbage collection

In most circumstances, the tracing garbage collector shouldn't interfere too much with performance, as in most usecases, it only takes a few miliseconds to run, and the audio is running on a separate thread. However refresh rates higher than 60-75 Hz will pose a challenge, and more memory use will mean longer tracing times.

By version 1.0, even more things will avoid the GC, so it can be optionally disabled, and reference counting will be added to the engine as an option. Even later versions might even move to an alternative runtime.

## Working with templates

In the engine's root folder, there's a folder for application templates. It is recommended to copy the code out from them and into your initial source file, especially if you're unfamiliar with the many subsystems of the engine. You can modify them to fit your needs later on.

# Tile maps and tile layers

# Sprites

# Audio
