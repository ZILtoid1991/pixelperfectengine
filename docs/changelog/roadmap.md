# Planned features for 0.10.0 final

## Reverb/Delay/Chorus/Flanger effect (Delaylines) 

* Status: in progress.

## Audio support

* Status: mostly works

### MIDI sequencer

* MIDI 1.0 status: written, needs implementation and testing.
* MIDI 2.0 status: for later versions (0.11.0?).

### Audio development toolkit

* Status: MIDI sequencer needs implementation.
* Sample manager is mostly done.
* Make music editor for a later version (0.11.0?).

# Features planned for later

## GPU rendering

It's likely possible to do pixel perfect graphics without resorting to compute. It needs the followings:

* Turn off texture filtering (possible at all OpenGL versions).
* Set rendering resolution (likely needs rendering to texture).
* Use a 256*256 texture for color lookup (likely possible in even the oldest GLSL version).

Added benefits are speed (10 000+ objects per frame!), the possibility of low-res 3D graphics, and easy implementation of transformable sprites.

## Logging

Add a logger to record events and errors.