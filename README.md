# PixelPerfectEngine

A retro engine for 2D and pseudo-3D games written in D by László Szerémi.

Started out as a project for college, and continued as a hobby to learn game and software development. Has its own GUI
subsystem, which is influenced by the looks of old graphical operating systems' (Amiga Workbench, old MacOS, etc.).

# Why use PixelPerfectEngine over the competition?

## Authentic pixel graphics

I was looking for a project idea to present something for Object-Oriented Programming exams, that would be doable by a 
single person, yet fun enough to keep me occupied to work on it. While I underestimated the complexity and the work 
that should go into an engine (especially as a rookie), I noticed a few odd things about 2D retro games. As modern 
engines often use 3D polygons for sprites, there are often many errors:

* Rounding errors from floating-point coordinates.
* Unauthentic scaling and rotation effects due to direct rendering on high-resolution framebuffers.
* Ability of use of sprites and textures with baked-in big pixels, which lead to misaligned pixels.

Currently the engine uses OpenGL to render to a low-resolution framebuffer, which is

## Small footprint and lightweight

Some other, popular engines used for 2D retro games are 3D engines that are made to display 2D graphics instead. This 
often adds additional bulk onto an otherwise small game.

This lightweight nature of the engine will soon enable to be compiled for low-powered ARMv8 devices, which will allow 
to be run on many smartphones and even single-board computers.

## Open-source without the hassle

This engine is licensed under the Boost Software License 1.0, which means it can be used without attribution and even 
in commercial applications, without any associated fees (licensing fee, per-install fee, etc.). Be aware that many
components are on different licenses, such as SDL2 and ZLib.

# How to build

PixelPerfectEngine actually requires ldc2 to build since that has better vector support than DMD, and vectors are used 
to speed up the rendering.

To compile windowmakerforconcrete, launch a simple :
```
dub build :wmfc --compiler=ldc2
```

## Test cases, demos, and tools

PixelPerfectEngine comes with multiple test cases, both to test various functionalities during development, and to 
showcase the capabilities of the engine.

### test0

Displays an automatically generated tilemap pattern on two layers (one is transformable) and multiple sprites (art by
arkark3). There's also a semi transparent text-layer displaying the framerate and collision information. This all can
be controlled from the keyboard.

### test1

Audio testcase. Tests audio initialization and plugins, also intended as part of an audio development kit (ADK). In the
future, it'll also be able to play MIDI files.

### test2

Map format testcase. Tests most functionality of the Extendible Map Format (XMF). Can load any XMP files.

### test3

GUI elements testcase. Tests if GUI elements work correctly.

### test4

Test of the scripting engine.

### test5

Test of the XML text parsing engine and the text drawing functions.

### snake

A simple engine demonstration game.

The classic game of Snake, where the player must collect apples (red dots) in order to grow.

### icebreaker

Arkanoid-clone game. Currently under development.

### Windowmaker for Concrete/PPE

Window layout editor with code generation features. (Dub package name is `wmfc`, to avoid issues from too long paths
under Windows)

### PixelPerfectEditor

External project. Map editor, with some other tools built in, like a BMFont editor, and format converter. Can be found
here: https://github.com/ZILtoid1991/pixelperfecteditor

A must-have for this engine, due to it using some unusual features, like palette shifting.

# Features

* Pixel-accurate retro graphics.
* Either hard-transparency using blitter, or soft-transparency using alpha-blending.
* Various effects with other composing functions.
* A tile layer that is capable of displaying uniform tiles from a map, with some Mode7-esque affine transformation.
* A sprite layer with sprite scaling and transformation, simple slicing, and individual composing functions for each
sprite.
* GUI through Concrete
* Configuration file handling
* Collision detection
* Handling of multiple inputs
* An audio subsystem capable of era-correct synthesis
* Scripting via WASM (coming soon!)
* ...and many more

# Known issues:

* WindowMakerForConcrete and PixelPerfectEditor are currently unfinished. The former will be soon working fully with 
extra features (such as undo/redo, snapping to grid and components), then the latter can be developed without an issue.
* Error handling isn't fully realized, so a lot of errors might happen. You can help me by reporting errors, testing on
various systems.
* Lots of untested and not fully tested features. Many are tested to at least run somewhat, but not tested in-depth. 
Currently, I'm the sole maintainer of this project, and things are quite tough, especially after you factor in my 
full-time job.
* Semi-implemented features, that need to be fully realized.

# Future plans:

* Compressed data file handling.
* Support for MacOS. (Contact me, if you have hardware for it and willing to contribute to the project)
* Support for Android. (Either will be done by me later on, or contact me if you're up for this challenge)
* Support for iOS. (Contact me if you have the hardware and you willing to contribute)
