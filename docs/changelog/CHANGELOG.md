# 0.12.0-beta

## Full rework of rendering and move to OpenGL

CPU rendering is now mostly deprecated in favor of rendering on the GPU via OpenGL. This also means a massive refactoring of the rendering pipeline and associated API.

This comes with the following changes:

* Sprites are now defined as Quads, and any of their corners can be freely defined, mirroring and scaling is done as such. Rotation is now also available.
* The regular tile layer gained the ability of a limited transformation. The layer can be sheared and rotated, but per-scanline effects are no longer available, and is heavily dependent on the overscan to work correctly. In the future, a per-tile approach will be added.
* The transformable tile layer might get deprecated.
* Palettes are now stored in two 256x256 textures. the first one contains color, the second one contains normal mapping.
* Additional API has been added to Concrete do deal with the use of GPU textures.

To be done:

* Fix incorrect tile layer rotation and shearing, likely will mean reworking of shader architecture.
* Optimize sprite draws, with the use of Uniform Buffer Objects, and unify all draw calls if they're using the same texture and shader.
* Finalize API as much as possible.

## Collision detection rework

Collision detector has been reworked to work with arraymaps instead of treemaps, to improve performance. Collision detection is also been moved to the `physics` subsystem.

## Other improvements:

* (test1) work on sequencer has begun. (Preliminary, editing and displaying not work)
* (QM816) added portamento support. (Preliminary, is not fully implemented)

## Known bugs

* (Test1) Some IMBC files crash the application.
* (Concrete) Window downsizing is buggy, header buttons will fall outside of display area, will be fixed next version.

# 0.11.0

* SDL removed in favor of iota.
* Added fulscreen and resizable raster support.

# 0.11.0-beta

## IMBC

Due to a preexisting and similar format by the same name, M2 got renamed to IMBC, or Intelligent MIDI Bytecode.

### Bugfixes and changes

* Complete refactoring of the textual IMBC reader (now called assembler), this also carries with itself a lot of bugfixes, especially those related to instructions previously not tested.

### Known bugs

* Either the sequencer doesn't like multiple patterns at once, or the assembler is emitting incorrect command codes.

## Concrete

* Added resizable window support.
* Updated file dialog for better UX.

# 0.11.0-alpha.5

Fixed a bug related to submenus in popup menus, also a bug related to missing `onDraw` calls.

# 0.11.0-alpha.4

Fixed a critical bug regarding of the insert and edit function of ListView.

# 0.11.0-alpha.3

## Improvements upon the textparsing system

### Bugfixes

No more last line omitting bug, there's still some inconsistency with line breaking if the last word is followed by a space of not.

### Added and/or implemented features

* `justify` is now parsed and tested.
* Tag `insert` has been added, which inserts a a block into the text. (testcase for it currently not working).

## Configuration file parsing changes

* Made auxiliary tags easily accessible without class inheritance.
* Added tag `local`, and ways to accessing it.

## Fixes to example game "Snake"

It had a bug, that could cause the snake to lose its tail in case of rapid direction changes, also pressing up or down upon beginning was extremely buggy. These issues has been solved.

# 0.11.0-alpha.2

## New path handling system

Running the executable from a different path environment will no longer crash the application with "file not found" exceptions, as long as the adequate functions are being used to generate the paths. Later versions might expand on the capabilities of the path generation functions.

## Audio resampling

Now audio will always run at 44.1/48kHz. Also automatically sets the buffer size to the given frequency to avoid confusion with the underlying sampling frequency.

There's not much to gain from higher sampling frequencies in the audio quality department (QM816 is oversampling though at 55.5/60kHz), thus in order to make audio processing less CPU intensive.

## Insert and edit function for ListView

ListView now has a function to insert a new item, request focus, and put itself into editing mode. Some issues with how focus request and handling is being done is now fixed.

# 0.11.0-alpha

## Introduction of the M2 support

Due to the lack of an official (and unofficial) MIDI 2.0 capable file format, I decided to take the matters in my hand and implement my own. In addition to MIDI 2.0, it also has scripting support that could be used for adaptive soundtracks.

As of now, support is quite preliminary, with certain features not fully implemented and/or tested. In the future, external interaction with arrays and global registers, as well as external calls to patterns.

## Dropping the default Lua engine

Due to inability to get it working together with D in any meaningful way, the Lua engine had to be dropped.

At one point, I got it working for some part, but then it had issues with classes passed through LightUserData, once removed, the Lua code stopped compiling.

Currently, I have two options:
1. Look for another Lua engine, but most don't implement integers since "floating-point can represent them".
2. Look for another scripting language. Wren even has an official D port, but no integers. Same with most other scripting languages. Integer support with no floating-point would be preferable to the other way around. Some are not very D friendly either, and would introduce complicated build tools, which are extremely difficult to use.
3. Add a popular VM to allow many other languages, including D itself with some, but many are so bloated that their DLLs are larger than the whole project.
4. Port a pre-exiting one to D, that would otherwise involve complicated build processes. This would allow one popular Python implementation to be ported. However, this might need relicensing of my code, which I was thinking about already.
5. Write a lightweight VM myself. I already done something like that with M2, all I need is to add heap allocation support, support for function calls, etc. The harder part is to implement compilers for it, also it would take precious time from other parts of the engine, which is already suffering from feature creep relative to my time I can invest into it.

## Bug fixes

* Fix to popup menus. Event class now contains the number of selected item, previously due to an overlooked bug, it returned the mouse position.
* Fix to file dialogs. Now they can exit the root directory.

## Known issues

* Test 3: Button "Filedialog" does nothing as of now.

# 0.10.6

* Fixed a bug in `PopUpMenu.passMCE`.
* Testcase for scripting mostly done (does not work correctly, see roadmap!).

# 0.10.5

* Fixed a bug that caused out of bounds reads when downscaling 32 bit sprites, and also when they're being upscaled but only a small portion of them will be visible.
* Fixed layer-order bug.

# 0.10.4

* Added separators for pop up menus.
* Removed some ancient code from the pop up menu rendering and input handling.
* Some minor work on the scripting engine (still not in testing phase).

# 0.10.3

* Added code of conduct, and branding guidelines.
* Fixed the offscreen popup issue by adding some additional calculations to the popup placement.

# 0.10.2

Fixed loading of 24 bit bitmaps as sprites.

# 0.10.1

## Fixed bitmap slicing with sprites

Should no longer create the previous issue of either sprite sheets not getting detected, or bitmap slicing causing the application to crash.

## Text parsing tested and working, multiline text drawing implemented

Text parsing wasn't tested previously, now it's working. Multiline texts also working now.

I haven't implemented the full ETML specification yet, as even this level is more than useful.

KNOWN ISSUE: Not ending lines with `<br />` at end of each text chunk and paragraphs will result in some lines missing and random `[cr][lf]` whitespace. Will be fixed later on.

# 0.10.0

## Fixed function getLayerType for all layers

Certain layers had the bug of me not rewriting the function `getLayerType` when copying.

## QM816

### MIDI CC fix

Lower portion of MIDI 1.0 CC has been fixed.

## Other audio features

* Added `DelayLines` for implementing certain time-based effects (delay, reverb, etc.).
* Added sample slicing capabilities to the module API.

## Test1/PixelPerfectEngine Audio Development Kit

* Added Sample manager and loader.
* Added MIDI router.
* Added basic graphical user interface for sequencer.

# 0.10.0-beta10

## PCM8 sample playback fix

The sample playback of the PCM8 module has been fixed. Looping is currently untested.

A bug caused skips in the frequency of sample decode calls, now it should work as should.

## QM816

### Channel fixes

Some functions calculated the operator numbers incorrectly, now all channels work as intended.

### Change to filtering structure

Low-pass filtering is now done before resampling, so there should be a bit less artifacting from that, and will make it possible to upgrade the linear interpolation to something better (that can run live).

### Replacing the linear interpolation with Cubic Lagrange

Cubic Lagrange interpolation returns a more accurate result than linear interpolation while also having low latency.

## Removal of function isInteger

`isInteger` was created to avoid exception handling, but due to issues I decided to remove it, and subtitute it with exception handling.

## Fix to ListView draw algorithm

Added some safety checks to the cursor drawing, now it should not cause issues.

# 0.10.0-beta9

## Suspendable timer

The timer now can be suspended for pausing, etc.

## Implemented pitch bending for PCM8

The functionality was there mostly, but just forgot to implement it fully.

## Object data serialization

Implemented missing object data serialization, so now it should work. (Hope I don't have to debug it in the editor).

## ListView

Added the ability to set the scroll speed of ListView, to avoid painfully laborous scrolls. Also added a function to 
jump an exact scroll location.

# 0.10.0-beta8

## Added some basic object handling and loading, and full sprite layer support to mapformat

Originally, I wanted to work on the editor, but since the engine lacked some critical features, I had to go back and 
add them. Fortunately didn't took too much time.

## Collision detection bugfix

The ObjectCollisionDetector had some kind of weird bug, which I had to fix by changing how the tested area is being 
calculated. This might also bring some minimal performance improvements, since the new one can be substituted with some
conditional moves.

## Made the MIDI sequencer workable

If you're lucky, it'll work right out of the box. See `gameapp.d` template for example usage.

## Other changes:

* CPUblit upgraded to 0.6.1

# 0.10.0-beta7

## Added Random number generator

The engine now has its own RNG using a 64 bit Fibonacci LFSR.

## Preliminary scripting engine and text engine

A scripting engine using Lua, and a text formatting engine using XML has been added.

## WindowMaker

ListView header editor toolkit is added, also some fixes have been done to code generation.

## Tested and working under Raspberry Pi

So far, Raspberry Pi 400 is supported officially, regular 4B models should be also sufficient, and there's a good 
chance it can run on other single-board and/or low-cost computers.

However there are many caveats and precautions:

* One needs OpenGL support, this leaves out most boards with Mali GPUs, since ARM refuses to open-source their drivers,
and other single-board computer manufacturers don't have the money to license them. Community-driven open-source
drivers might work, especially since the engine don't need too many fancy features.
* So far, only 64 bit has been tested, especially as many NEON commands aren't available under 32 bit. It's unknown 
however how much the rendering would use them in actuality.
* 64 bit is still in experimental support in Raspberry Pi OS, however it's usable as long as legacy GPU drivers are
enabled.
* A5x CPUs might not have the cache nor the execution capability to sufficiently run the engine. The rendering is using
a method that is very CPU cache bound.

## MIDI input via iota

## Audio subsystem changes

* QM816: finetuning. Added high-pass filtering, artifacts from applying feedback eliminated.
* QM816: Fixes to previously untested functionality.
* QM816: Low-pass filtering resonance range change.
* QM816: Added "resonant mode" capable of "ring modulating" two oscillators connected in parallel.
* PCM8: Now it works!
* `@nogc` removed from all parameter recall functions, parameter editing functionality added.

### Audio configuration

An audio configuration file format has been added (see `docs/formats/modulesetup.md`) and a configuration/test tool has 
been created under the name "PixelPerfectEngine Audio Development Kit". Currently it's an early prototype, and as such
many capabilities are currently missing from it.

## Other changes

* The CoarseTimer's callback delegate now can be throwing, and passes a Duration called `jitter` that can be used to
correct jitter errors.
* SpriteLayer: New architecture for adding sprites added, all layer features are now exposed.
* ListView: Added "selectedItem" function that returns the selected item, and not just its number.

## Bug fixes

* SpriteLayer: When adding a scaled sprite to the layer, it didn't set the correct size. Now it does.
* ListView: Multicell editing bug fixed.

# 0.10.0-beta6

## Audio output via iota

There's now multi-threaded audio support for the engine, allowing me to finally test audio related functions.

## QM816 works and tested for the most part

Using phase modulation synthesis (often mislabeled as frequency modulation), QM816 generates sounds from both user-
supplied and pre-defined wavetables, by rapidly shifting the wavetable ofset (modulating the phase). Every channel has
two operators by default, but channels can be paired up individually to trade off some polyphony for more complex 
sounds.

Aux outputs, LFOs, and channel envelops are not tested as of now, and both ring modulation and LFO filtering are 
unimplemented.

## Other new features:

* Encoder: New GUI element in work, mainly for synths.

## Removed features

* PaletteManager: Was a bad idea to begin with.

# 0.10.0-beta5

## Fixed bugs

### Concrete

* Fixed some remaining graphical bugs with ListView and pattern blitting.
* Fixed scrollbar behavior in case of large values.

# 0.10.0-beta4

## Fixed bugs

### Bug causing Windowmaker to not work has been fixed

Due to lack of manpower on testing (pls help me!), I introduced a bug in the previous version, that disabled the
listview's editing capabilities through a constructor. This has been fixed now.

### Concrete

* Slider behavior has been fixed through moving some calculations to floating-point.
* Graphical glitches related to pattern blitting have been fixed.
* Graphical glitching and possible memory corruption when using ListViews have been fixed, also issue that disallowed 
the viewing of the last elements.

## Known issues

Due to the massive lack of usable audio libraries, I have to write my own, so the custom audio engine's debut will be
further delayed. However, this will also mean the beginning of finally deprecating SDL in favor of in-house (and 
better) solutions.

# 0.10.0-beta3

## Moving PixelPerfectEditor to a separate repository

The tilemap editor was moved to a separate project/repository, and will be updated on a different rate than the engine.
This one will still have some testcases and the window layout editor (WindowMaker for PPE/Concrete). Test cases are
added to test engine functionality.

The new repository can be found at: https://github.com/ZILtoid1991/pixelperfecteditor

## Fixed bugs

### No more sprite scaling issues!

The following sprite-scaling issues were present in the engine:

1) If the top portion of a sprite was obscured, it looked rather janky during movement when the top parts of it got 
obscured.
2) If a sprite ended up too wide (greater than 2048) , then it caused memory corruption.
3) If a sprite was too tall, then it caused memory corruption.

These all got fixed through a either some refinement of the architecture (horizontal scaling-related issues), or just
adding a few more checks (#3) and better math (#2). A floating-point calculation was also removed and instead replaced 
with integer.

### Edge collision detection fix

Due to some changes in the underlying architecture, collision detection was fine-tuned for the previous mode in which
the Box structure worked. That was changed in order to standardize things, but not everything was updated at once. This
issue got fixed now and should work properly.

Box corner collisions are not detected as of now, but that will require a bit more reworking, while keeping previous
functionality.

# 0.10.0-beta2

## New features

### Custom audio subsystem

The custom audio subsystem was recreated with the following principles:

* for the time being, only simple synths should be added.
* It has to use MIDI 2.0 instead of some fancier and custom command set.
* It has to be as simple as possible.

It's still a work in progress, and at this version it's also untested. Also note that currently there're no file
formats that are MIDI 2.0 capable, and a custom file format might need to be developed. 

There are two synth modules that are being developed.

* QM816, a quadrature modulation synth. It's algorithm is the same of what many digital FM synths used to have, and
will create almost similar output as long as the modulator is a sine wave. However it can use custom waveforms (128 in
total), and they don't need to be sine. It has 16 channels with 2 operators per channel and 2 algorithms, but channels
can be paired up for 4 algorithm sounds with 12 possible algorithms.
* PCM8, an eight channel PCM playback synth. Can play 8 and 16 bit linear PCM samples, but also Mu-Law and A-Law 
codecs, and is also capable of decoding Dialogic and IMA ADPCM streams.

### Timer

A simple timer in the form of `CoarseTimer` has been added. It checks the time in a given interval through a function,
then calls the registered delegate. It can be a bit inaccurate in many cases, like calling it on every VSYNC interval,
but should be sufficient for many applications. See documentation in source code for more info on the possible 
innacuracies.

### Concrete Enhancements

#### Text input restriction

Text inputs now can restricted to certain types. Currently only integer and decimal types are supported, TextBox can
however support any kind of character-based restriction as long as position is not important.

#### Final implementation of element disabling

Element disabling have been fully implemented. It was left unfinished for a while as I had to work on more important
things, but those have been now mostly done.

## Fixed bugs

* Drive button works again
* Layers now cannot be created before docs
* Materials cannot be created before layers
* Radiobuttons now update correctly in window headers. Turns out all it's problem was that the raster window didn't do
updates on every redraw - my bad.
* Scrollbar behavior fixed. Now they jump immediately at the correct approximate location it's expected.
* Memory leakage and corruption issues from blank `Bitmap1Bit` has been fixed.

## New editor features

* Selecting areas
* Clipboard
* Right-click context menu
* Tile and Layer renaming
* CSV import and export 
* Better control from keyboard

# 0.10.0-beta1
## New features

 * Added `hashCalc` function to `PixelPerfectEngine.system.etc`. It can calculate the MurmurhashV3/32 hash of a
standard string. Made with the intention of generating fast lookup tables on the fly with CTFE.
 * Added `min`, `max`, and `clamp` math functions to `PixelPerfectEngine.system.etc`.
 * Added text capabilities to `TileLayer`.
 * Added conversion ability for image loading.

Also see chapter "Massive refactoring of the GUI subsystem" for stuff related to the GUI subsystem.

## General changes

### Massive refactoring of the GUI subsystem

`concrete` got refactored, due to it became hard to maintain, and otherwise too complex to handle.

Features added:

 * The new `ListView` can do the same stuff as the old `ListBox`, but requires less rendering outputs, has now
 updated to use formatted texts, per-pixel scrolling, and on-screen editable fields.
 * Focusing capabilities to elements, which will enable other functions in the future.
 * Any kind of small button is placeable into a window's header now.
 * Currently unimplemented child window system.

### New input handling system

The old one got replaced with one that's not only better maintainable, but also uses a binary search tree for
input code binding lookup, which is faster than the previous linear search. Some testing still have to be done
however.

### Box width and height calculation differences

Box width and height is now calculated with lesser and greater coordinates are being first and last prelimiters,
and now sizes are calculated as `greater-lesser+1`. This was done to avoid architectural issues in the future,
and even now I have used some workarounds to accomodate this.

### Minor ones

 * `Coordinate` got renamed to `Box`. An alias is made to 
 * `Color` is now an external struct from the dimage library.

## Fixed bugs

## New bugs

### Unreactive radiobuttons in header
Radiobuttons in headers for some reason are not reacting correctly. They will show the correct output once the 
header needs a full redraw.

### Drive button doesn't work in FileDialog
Will be fixed next time.
