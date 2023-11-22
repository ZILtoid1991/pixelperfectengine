# Table of contents

* Introduction
  * Current engine features
  * Planned engine features
  * Donation
* Getting started
  * Requirements
  * Setting up the developer environment and recommended toolchain
  * Working with templates

# Introduction

PixelPerfectEngine is a game engine/framework primarily designed for retro pixelart style games.

## Current engine features

## Planned engine features

## Donation

Patreon: https://www.patreon.com/ShapeshiftingLizard

The only hardware donation I might accept currently is some AArch64-based Windows PC, so I could also target that platform. 32 bit ARM devices are not considered as of now due to limited capacity. As of now, I cannot spend time on the ever changing APIs of Apple

You can also donate your testing time, knowledge, and coding directly to the engine.

# Getting started

## Requirements

The engine does not require a lot of computational power, however it requires:

* A 128 bit vector unit.
* OpenGL 2.0 or OpenGL ES 2.0 graphics.
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