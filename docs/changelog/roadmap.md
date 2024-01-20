# Planned features for 0.10.0 final

## Reverb/Delay/Chorus/Flanger effect (Delaylines) 

* Status: in progress.

## Audio support

* Status: mostly works

### MIDI sequencer

* MIDI 1.0 status: done!
* MIDI 2.0 status: 
  * Custom MIDI 2.0 format drafted.
  * Write assembler and VM for it.

### Audio development toolkit

* Status: MIDI sequencer needs implementation.
* Sample manager is mostly done.
* Make music editor for a later version (0.11.0?).

# Features planned for later

## License change?

Should I relicense the engine to the MIT license?

## Get a better scripting engine

Due to inability to get it working together with D in any meaningful way, the Lua engine had to be dropped.

At one point, I got it working for some part, but then it had issues with classes passed through LightUserData, once removed, the Lua code stopped compiling.

Currently, I have two options:
1. Look for another Lua engine, but most don't implement integers since "floating-point can represent them".
2. Look for another scripting language. Wren even has an official D port, but no integers. Same with most other scripting languages. Integer support with no floating-point would be preferable to the other way around. Some are not very D friendly either, and would introduce complicated build tools, which are extremely difficult to use.
3. Add a popular VM to allow many other languages, including D itself with some, but many are so bloated that their DLLs are larger than the whole project.
4. Port a pre-exiting one to D, that would otherwise involve complicated build processes. This would allow one popular Python implementation to be ported. However, this might need relicensing of my code, which I was thinking about already.
5. Write a lightweight VM myself. I already done something like that with M2, all I need is to add heap allocation support, support for function calls, etc. The harder part is to implement compilers for it, also it would take precious time from other parts of the engine, which is already suffering from feature creep relative to my time I can invest into it.

## Path management

Do it by 0.11.0!

Potential users are being scared away by the engine's path system, and some stuff just outright tries to run the executable from random places where the `../system/` folder is not reachable.

## GPU rendering (1.0.0)

It's likely possible to do pixel perfect graphics without resorting to compute. It needs the followings:

* Turn off texture filtering (possible at all OpenGL versions).
* Set rendering resolution (likely needs rendering to texture).
* Use a 256*256 texture for color lookup (likely possible in even the oldest GLSL version).

Added benefits are speed (10 000+ objects per frame!), the possibility of low-res 3D graphics, and easy implementation of transformable sprites.

### Pre-requirements

Mostly finishing iota to a state it can replace the current SDL functionality.

### Things probably need to be changed before, through, or after the GPU transition

* Tile rendering needs to be figured out yet again. Either needs to stay on the CPU, completely offloaded to the GPU, or some hybrid approach. ~~The GPU approach would limit the scanline effects.~~ Scanline effects can be done with a special texture and rendering a larger size of the screen.
* In order to better take advantage of the GPU, the Tile Format has to be rewritten, probably to 64 bit words. This would give the user extra bitflags, per-tile alpha channel, per-tile compositing function, flags for rotation, etc.

### Complications

The Transformable Tile Layer likely cannot be done without either heavy compromises, or heavy restructuring, especially not without compute shaders (not available on all GPUs). Likely it will be still be done by the CPU, then streamed to the GPU as textures, which at "retro" resolutions, shouldn't be too taxing on lower-end hardware.

## Logging

Add a logger to record events and errors (Do it by 0.11.0!).