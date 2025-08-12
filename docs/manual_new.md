# Introduction

PixelPerfectEngine is a game engine/framework primarily designed for retro pixelart style games.

## Currently implemented and tested engine features

* GPU rendered graphics.
* Live color lookup.
* Multiple tile and sprite layers.
* Era-accurate shimmering when scaling.
* Software synths for audio.
* Music/audio scripting system.
* Various collision detection systems.

## Planned engine features

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
* OpenGL 3.3 or OpenGL ES 3.0 graphics.
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

By default, the engine stores all executables in a `./bin-[CPUarch]-[OS]` subfolder, such as `./bin-x86_64-windows`. The engine will work without modification if the executables from that folder are moved to the root as long as it can detect the presence of the `./system` folder as long as paths are processed first with the `resolvePath()` function.

Path symbols are treated similar to the operating system's, and both starts and ends with a `%` symbol, e.g. `%SHADERS%`. The `%` symbol can be escaped by placing two of them side-by-side. Custom path symbols can be created with the line `pathSymbols["SYMBOLNAME"] = pathRoot ~ "/yourpath/";`. Path symbols also can used for other purposes, like localization settings. Can be escaped, e.g. `%%APPDATA%%` to access system paths, but not recommended due to potential portability issues.

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

# Palettes and color math

The engine is using indexed color for the most part with shaders doing the color lookup and composing work.

## Palette system

(NOTE TO SELF: Insert illustration of describing the color table and partitioning)

There are two palettes in the game engine:
1) The color palette, consisting of 4 (Red, Green, Blue, and Alpha) 8 bit unsigned elements.
2) The normal palette, consisting of 2 (X and Y) 16 bit signed elements, mainly used when normal mapping is enabled, but in theory, with alternative shader math, can be repurposed.

The palettes are 2D textures, 256x256 in size. This enables 256 subpalettes, each with 256 color indices. The palette can be further partitioned into smaller chunks as long as they follow the power of two scheme and are bound to the texture sizes, this could enable 4096 subpalettes with 16 color indices, 1024 subpalettes with 64 color indices, etc. Make sure your bitmaps only use the lower portion of the palette indices. The palette does not need to be partitioned all the way the same way, you can freely mix and match 32 color subpalettes for sprites, 16 color subpalettes for foreground tiles, and 8 and 4 color subpalettes for the various background tiles used for parallax scrolling.

Additionally, color-cycling effects work as expected. Per-scanline color-cycling needs to be done through shaders.

## Color math

Color math can be used to apply:
- Shadow and highlights
- Alternative color palette selection (works with monochomatic palettes the best)
- Primitive normal mapping (lighting) effects
- Almost anything else

on the selected graphics objects.

The engine is supplied with two extra fragment shaders. One of them does hardlight (multiply below 0.5, screen above 0.5) to the graphics elements. The other on top of it also applies a per-pixel lighting effect based on the pixel's normal values.

# Entity component system and data-oriented design

(Note to self: insert graphics here showcasing the differences between the concepts)

The engine is using ECS and DOD whenever it's either the simpler or faster solution. The engine still uses OOP for certain components to make interchangability and expansion easier (e.g. GUI, serialization), but often still uses ECS and DOD under the hood (e.g. graphics layers).

Entity component system (ECS) is an abstraction system, that is very different from the hierarchial system of object-oriented (OOP) system. Rather than relying on often multiple level inheritance, in ECS each component of an entity is stored in a separate array, and depending on ECS implementation, each entity can choose its own components.

## Examples

A player character or an enemy will have one or more associated sprites, one or more associated collision shapes, some game logic related definition (stats, means of attack, behavior, etc.), and could have physics affecting them.

A game item to be picked up by the player (or even the enemy) will have a sprite and a collision shape, but may not have the physics affecting it, and will have different kind of stats.

Particle effects will have a sprite, physics, and a collision shape. Logic is limited to physics behavior and a lifetime.

Event markers don't have a sprite nor physics, but have a hitbox and a behavior.

## Keyed entity component systems

The engine generally uses a keyed entity component system. This makes is simple and fast to search for a given entity over multiple arrays. One downside is that it also adds some extra space needed for the components, which in turn sometimes ends with more data being packed with the structs to make the alignment work correctly. This is most apparent with the engine's default physics system, which always couples together position and other data.

# Basics of graphics layers

The game engine works with customizable layers, each of which run certain display commands to draw to the screen.

Each layer's order can be set by the developer, and are fully customizable. Using the engine's own OOP system, one even can create their own custom layers.

## Layer linking

Some layers, like tile layers can be linked together, for priority purposes, to emulate such behavior of the old tile-based systems.

## Layer masks

Layers can use a so-called mask layer, that is shared between the other layers, for various purposes, like advanced color math. Unlike on old systems, masks are much more advanced, and allow for more color variation than those did, meaning entire bitmaps can be used for masks.

## Common layer functions

# Tile maps and tile layers

Since Galaga, a lot of game systems were built upon tilemapping engines, where each element acted like a highly modifiable graphics character. This enabled a building block system, that is easy to use and understand.

## PPE tile format

### Tilemap 

The tilemap is a 2D array, that consists of 32 bit data chunks with the following format:

```
| Byte 3 | Byte 2 | Byte 1 | Byte 0 |
|76543210|76543210|76543210|76543210|
|ZRVHPPPP|PPPPPPPP|SSSSSSSS|SSSSSSSS|
```

Or:

* 16 bits of tile selector, 0xFF_FF equals with empty tile. (S)
* * 12 bits of palette selector. (P)
* 1 bit for horizontal mirroring. (H)
* 1 bit for vertical mirroring. (V)
* 1 bit for X-Y axis rotate enable, using alongside of the mirroring flags, it enables 90 and 270º rotation among others. Will cause incorrect behavior with non 1:1 ratio tiles. (R)
* 1 bit for priority. If tile layer is linked with another one, they will be sharing tilemap and image information data. All of the tiles will be displayed on the primary tilelayer, unless this one is the to high, then it is sent to the secondary layer. (Z)
 
Examples:

* `0x0000_FFFF` is a transparent tile. The other half of the tile data will be ignored.
* `0x0004_0101` is a tile of ID `0101` using palette `04`, with priority value set to 0, and no mirroring or rotation.
* `0xD000_002c` is a tile of ID `002c` using palette `00`, with priority value set to 1, with horizontal mirroring and rotation.

#### Extensions

Tilemap extensions are provided for both graphics and logic, see `format/mapdata.md` for more information on the subject.

By general, graphics extensions are used to add shadow/highlight effects to the tiles and other objects

### Tilesheets

(NOTE TO SELF: insert example tilesheet here)

Tilesheets contain graphic elements that can be displayed on a tile layer. Each tile graphic is defined with a single x and y coordinate, as the rest can be 

# Sprites

Sprites are fully independently movable and transformable 2D objects on the screen. One or more sprites can be used to build up a game object that is freely movable. In the engine, sprites are so-called pseudoquads, and come with their own caveats in case of some transformatons.

## Spritesheets

(NOTE TO SELF: insert example spritesheet here)

A spritesheet contains multiple sprites on one texture, which can be displayed on the sprite layer. One sprite layer can handle multiple spritesheets without color depth or size restrictions. A spritesheet can even be a single sprite, as is done in the GUI subsystem, but should be avoided. A framebuffer also can be set as a spritesheet.

Each sprite are defined as follows:
- The spritesheet identifier.
- Shader program identifier.
- An `x` and `y` coordinate for the sprite origin.
- A `width` and `height` for the sprite sizes.
- Optionally a bitdepth value can be supplied.

### Managing spritesheets.

The function `pixelperfectengine.graphics.layers.base.Layer.addBitmapSource` can be used for adding a spritesheet to a sprite layer. `pixelperfectengine.graphics.layer.base.Layer.removeBitmapSource` removes said sprite sheet. `pixelperfectengine.graphics.layer.base.Layer.addTextureSource_GL` adds a texture directly, which can even be a framebuffer.

Function `pixelperfectengine.graphics.layers.interfaces.ISpriteLayer.createSpriteMaterial` can create a sprite material from a sheet, while `pixelperfectengine.graphics.layers.interfaces.ISpriteLayer.removeSpriteMaterial` removes said material without removing any associated sprites.

## Sprite manipulation

(NOTE TO SELF: Insert graphic here depicting sprite manipulations in some way of form)

In the engine sprites can be:
1) Moved
2) Rotated
3) Mirrored
4) Stretched
5) Recolored in various ways
6) Its material be replaced for e.g. animations

### Position-based transformations

Each sprite has four corners to define its positions.

Moving them all in once will move the sprite without applying any other translations.

However, we can also apply other affine transformations on the `pixelperfectengine.graphics.common.Quad` type using its helper functions, or even directly.

#### Pseudoquad limitations

The engine is using two triangles to create a quad, which makes it so that when only one corner is being pulled, it does not represent actual quad behaviors in that case, and depending on corner, it might only affect a portion of the underlying bitmap. It also cannot do the "quad twisting" effect at all.

### Color transformations

Sprites can be palette swapped and color math can be applied to them, see chapter "Palettes and color math" for more information on the topic.

# Colllisions

# Audio

# Scripting

The game engine is using WASM (WebAssembly - please note that despite its name, applications built with the game engine are not "Electron applications running in a browser", nor are necessarily ready for web export) for scripting, by using the wasmtime library, for multi-language compatibility and a lightweight scripting engine. There will be a C/C++ and a D binding soon.

**Differences from regular WASM:**

* No HTML functionality. However engine functionality for drawing and text formatting (ETML) are exposed instead.
* No WebGL or similar graphics API. Any low-level meddling with the graphics API should be done in low-level code.
* Same with any other web API.
* No built-in browser in the game engine.
* No Javascript is used on the engine side, `__externref_t` and `JSObj` are now refer to D classes on the backend instead.
* WASI is not used, instead it uses the engine's own logging system for the same purpose.
* The engine's API is being exposed instead.
* Custom functionality API can be exposed using appropriate wasmtime-d functions.

**Best practices:**

* WASM can still hurt performance, thus time-critical elements (physics, graphics, audio, etc.) should be handled low-level.
* Generally, scripts should be scripts and not general game logic, but target application might override this rule (e.g. heavy modding support).
