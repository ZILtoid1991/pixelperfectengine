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

## Fix lua scripting

Current state of Lua scripting:

* Initialization works.
* Automatic deinitialization works through D garbage collection.
* Passing class references as light userdata works.
* Class references can be recovered from light userdata.
* Calling class member functions from said class references have no effect, neither by hand-writing said functions, nor by using the class member binding template. Also does not create any errors on D side.
* LuaVar seems to work. However the metaprogramming used to make it useful either resets it to zero, some extra steps I don't know are missing, or undetected memory leakage happens to it. Once in the template functions, everything goes wrong!

### Candidate 3rd party library 'Lumars'

The biggest pro for it is it's a very nice to use library. However, it only supports the now obsolete 5.1 version of Lua, which only has floating point numbers instead of fixed point, which makes a lot of things in my engine hard to support and account for.

Also it's under the MIT license. I can relicense my engine to MIT (was thinking about it), but Boost would be the best.

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

* Tile rendering needs to be figured out yet again. Either needs to stay on the CPU, completely offloaded to the GPU, or some hybrid approach. The GPU approach would limit the scanline effects.
* In order to better take advantage of the GPU, the Tile Format has to be rewritten, probably to 64 bit words. This would give the user extra bitflags, per-tile alpha channel, per-tile compositing function, flags for rotation, etc.

### Complications

The Transformable Tile Layer likely cannot be done without either heavy compromises, or heavy restructuring, especially not without compute shaders (not available on all GPUs). Likely it will be still be done by the CPU, then streamed to the GPU as textures, which at "retro" resolutions, shouldn't be too taxing on lower-end hardware.

## Logging

Add a logger to record events and errors.