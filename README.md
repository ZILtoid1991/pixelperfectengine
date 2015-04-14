# VDP-engine ver 0.9.0
2D graphics engine written in D by László Szerémi (laszloszeremi@outlook.com)

Requied libaries:
Derelict SDL2		https://github.com/DerelictOrg/DerelictSDL2
emesx TGA		https://github.com/emesx/TGA

1) Changelog:

-ver: 0.9.0:

First really useable version

THIS VERSION OF THE ENGINE IS INCOMPATIBLE WITH THE PREVIOUS 0.1 VERSION! IF ANYONE ACTUALLY USED MY ENGINE (which I highly doubt), THEN MODIFY YOUR CODE TO WORK WITH THIS VERSION OF THE ENGINE.

REMOVED:
--Class color, due to the overhead it generated.
--AbstractSprite and its child classes. Generated too much overhead, only the Bitmap16Bit class left, and the sprite positions are now handled by the SpriteLayer.
--Per sprite transparency index.

ADDED:
--Input support for keyboard and joysicks.
--TGA file loader for sprites.
--Sound support via SDLMixer.
--Pixel precise collision detection.
--Preliminary background tester.

FIXED:
--Speed issues. Now it's capable of rendering hundreds of sprites without slowdown, due to removing all the overhead and changing the rendering method.

-ver: 0.1

Initial version

2) Known issues:

-The engine likes to slow down, when the rendering resolution is high on some processors. My desktop PC (Athlon 64 x2 2.7GHz, 512kB L2 cache, 4GB DDR2 800MHz Dual Channel, AMD HD7790) tends to get bottlenecked at the same resolution where my notebook (Pentium E4400 2.2GHz, 1MB L2 cache, 2GB DDR2 800MHz, Intel HD Graphics) runs perfectly, sprite number have no impact on the speed. Probably it can be fixed with further optimalization.

3) Contact:

Send the bug reports and complaints about my grammar here: laszloszeremi@outlook.com