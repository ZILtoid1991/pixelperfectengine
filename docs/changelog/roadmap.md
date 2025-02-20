# Roadmap

## Reverb/Delay/Chorus/Flanger effect (Delaylines) 

* Status: Works, however initial architecture isn't well suited for modulation/type effects. Develop separate effector for that purpose.

### Modulation (Chorus/Flanger) effects

Not yet materialized

## Audio support

* Status: mostly works.
* Potential issue: hotplug support isn't implemented at iota's side.

### MIDI sequencer

* MIDI 1.0 status: done!
* MIDI 2.0 status: 
  * Custom MIDI 2.0 format drafted.
  * Assembler and VM works so far, needs more testing.
  * Implement binary format by 0.11.0!
  * Format renamed to IMBC due to M2 already existing.

### Audio development toolkit

* Status: MIDI sequencer needs implementation.
* Sample manager is mostly done.
* Make music editor for a later version (0.11.0?).

#### Music editor

Due to the capabilities of the new format the engine uses (~~M2~~ IMBC), a special editor will be needed, that can do some scripting, etc.

# Features planned for later

## Get a better scripting engine

Due to inability to get it working together with D in any meaningful way, the Lua engine had to be dropped.

At one point, I got it working for some part, but then it had issues with classes passed through LightUserData, once removed, the Lua code stopped compiling.

Currently, I have two options:
1. Look for another Lua engine, but most don't implement integers since "floating-point can represent them".
2. Look for another scripting language. Wren even has an official D port, but no integers. Same with most other scripting languages. Integer support with no floating-point would be preferable to the other way around. Some are not very D friendly either, and would introduce complicated build tools, which are extremely difficult to use.
3. Add a popular VM to allow many other languages, including D itself with some, but many are so bloated that their DLLs are larger than the whole project.
4. Port a pre-exiting one to D, that would otherwise involve complicated build processes. This would allow one popular Python implementation to be ported. However, this might need relicensing of my code, which I was thinking about already.
5. Write a lightweight VM myself. I already done something like that with M2, all I need is to add heap allocation support, support for function calls, etc. The harder part is to implement compilers for it, also it would take precious time from other parts of the engine, which is already suffering from feature creep relative to my time I can invest into it.

### Current status

~~Work on PingusVM have been started. At worst there will be an assembly-like scripting language, with options to write a compiler.~~ Dropped in favor of a binding to wasmtime.

## Path management

There's now some preliminary path management, more features will be added later on.

Potential users are being scared away by the engine's path system, and some stuff just outright tries to run the executable from random places where the `../system/` folder is not reachable.

### Current status

Implemented for the most part.

## GPU rendering (1.0.0)

It's likely possible to do pixel perfect graphics without resorting to compute. It needs the followings:

* Turn off texture filtering (possible at all OpenGL versions).
* Set rendering resolution (likely needs rendering to texture).
* Use a 256*256 texture for color lookup (likely possible in even the oldest GLSL versions).

Added benefits are speed (10 000+ objects per frame!), the possibility of low-res 3D graphics, and easy implementation of transformable sprites.

### Pre-requirements

Mostly finishing iota to a state it can replace the current SDL functionality. (DONE!)

### Things probably need to be changed before, through, or after the GPU transition

* Tile rendering needs to be figured out yet again. Either needs to stay on the CPU, completely offloaded to the GPU, or some hybrid approach. ~~The GPU approach would limit the scanline effects.~~ Scanline effects can be done with special shaders.
* ~~In order to better take advantage of the GPU, the Tile Format has to be rewritten, probably to 64 bit words. This would give the user extra bitflags, per-tile alpha channel, per-tile compositing function, flags for rotation, etc.~~ Basic tile format will be mostly kept as is, tile rotation will be added though to a flag, the rest of the bitfield will be used as priority. However, extra data can be assigned for per-vertex color data, which can be used for color calculation, either shared or per-tile.

### Complications

The Transformable Tile Layer likely cannot be done without either heavy compromises, or heavy restructuring, especially not without compute shaders (not available on all GPUs). Likely it will be still be done by the CPU, then streamed to the GPU as textures, which at "retro" resolutions, shouldn't be too taxing on lower-end hardware. (Likely will be dropped with regular tile layer getting some of its capabilities instead)

### Current status

* Heavy consideration of also implementing a vulkan rendering pipeline (nuvk?).

## Logging

Add a logger to record events and errors.

## Move away from the GC

With the use of `numem`, every new or rewritten system will be moved to a nogc system, to avoid potential pauses from garbage collection traces. At least numem allows operation alongside of Phobos and D's own GC (with some caveats).
