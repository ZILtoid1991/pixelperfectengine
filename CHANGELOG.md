# current

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