# What do you need for developing with the engine

## Familiarity with the D language

The engine was developed using the D language, which is a C-style language with extra functions making it better for 
general use. Many are criticizing its garbage collector, which in some opinions makes it less appropriate for real-time
applications such as games, however it can be regulated to not scan functions that don't memory allocate, and badly 
managed memory under C or C++ can also cause performance hits, mainly by continously allocating new memory for single 
elements. In addition, D has a few tricks up its own sleeve:

* Support for pure functions, which makes multi-threading much easier, and can offset the marginal performance loss by 
utilizing multiple CPU cores.
* Powerful metaprogramming capabilities, which are leagues above what C or C++ can offer.
* 100% compatibility with C, partial compatibility with C++, this enables the direct use of libraries written in those
languages.

Once added, scripting languages such ad QScript could be used for various tasks, e.g. embedding them into maps to 
trigger events.

## Familiarity with the engine's rendering method

Most engines used for games with retro-inspired looks are multi-purpose, like the Unity or Godot, and as such are using
polygonal rendering for this task. This makes it much faster to render as it offloads this process completely to the 
GPU, however pixel-locking is a bit-difficult, and makes it easy to miss. Sometimes assets made for such games have
"baked-in" pixels, indicating what kind of resolution they attempt to emulate. Special effects such as sprite-scaling 
and rotation, and transformable tile layers almost always ignore the resolution, and instead go up as far as the system
enables them.

On the other hand, this engine emulates the look of old graphics using old techniques optimized for modern hardware, 
such as using the CPU's vector capabilities. All at low-resolution. This makes pixel-locking part of the 
rendering-pipeline, enables palette-swap effects (even without reallocating the same sprite multiple times). On even
the first 64 bit CPUs, it shouldn't be a massive performance issue, and now that we don't have to emulate things like
planar-lookup, CPU timings, etc, we have even more resources for rendering than emulators do. I even implemented some
extra rendering functions that were not widespread on old systems and/or blitters, such as multiply and screen 
functions, that could be used for shadow and light effects, all without sticking out too much.

This also means, you can't mix resolutions (currently, I plan an era-correct solution, primarily for texts in 
East-Asian languages), or be amazed by high-res Mode7 layers. Or high-res shrinking sprites.

Your artists must be familiar with using indexed images, the limitations of a given layer (some have size limitations),
and to yse the zoom tool in their editor of choice for previews.

## Familiarity with tile layers

Back in the old days, backgrounds and levels often were built using characters, better known as tiles, often by 
repurposing text-modes of graphics chips for that purpose. This ensures that the background building blocks all have
the same size (or at least per layer), while also doubling as a form of graphics compression.

Instead of whole level's worth of graphics, you only have to supply a bunch of tiles and the map layout for a single
level. And the best thing is that you can reuse the tiles for multiple levels.

Your level editors must be familiar with how tile layers in the engine work, the data structure of each tile, and the 
editor of the engine. The editor will have it's own little manual soon.

## Other, less obvious things

* Talent

* Passion

* Original assets

* Seriously, even if you're not a good artist and poor, just find someone who's willing to work for exposure and 
creative control! They might not be the best, but everybody have to gain experience.

* If you still plan to use unoriginal assets, then don't sell your game for money!

* If you sell your game with flipped assets, and you didn't have any talents, then don't sue game journalists!

# List of currently implemented engine features

## Tile Layers

Tiles solved many problems around graphics memory in the old days, now they simplify level design. One does not have to
paint or draw a whole level worth of graphics, instead a level can be built with smaller building blocks, making the
whole process much easier, not to mention it's easier to course correct if e.g. you design a platform to be too far
apart. Larger objects could be still created, by simply placing multiple tiles together.

The layer is capable of emulating some horizontal blank interrupt effects, namely scrolling effects. Palette 
modification during lines are technically possible, but could result in terrible bugs, not to mention the engine's
per-layer/per-sprite rendering approach instead of the per-scanline approach many system did.

All tiles on a single layer must share the same sizes. Every tile layer supports horizontal and vertical mirroring,
palette swapping, etc. There's one master alpha value and rendering function.

## Transformable Tile Layers

Transformable tile layers can be sheared, rotated, and resized, even on a per-line basis, which can be used to render
some pseudo-3D graphics.

All tiles on a single layer must share the same sizes, the sizes must be either 8, 16, 32, or 64; and the tilemap must
have sizes of power of two.

## Sprite Layers

Sprite layers contain individually movable graphics objects that can represent many things, such as a player, bullets, 
enemies, objects to interact with, etc.

Sprites on this layer have no size limits, can be horizontally and vertically resized, and even using other layers as 
sprites are possible using certain tricks. All sprite layers will have the ability for individual rendering functions,
and master alpha values, as well as palette swapping. Sadly, per-line effects are not supported yet, as it would
overcomplicate the calculation of out of bounds areas.