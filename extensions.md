Note: all dataunits use D naming. Big endian formats like PNG store data in big endian, while little endian formats like TGA store it in little endian. Using embedded data in the files requires one to have some basic understanding how these files work, and how their extensions should be used (TGA has "Developer Area" for this purpose, PNG works similarly to RIFF, etc.).

# Tile extension

PNG ID: tILE

TGA ID: 0xFF00

Describes uniform sized objects within an image file, such as tiles. One image file should only contain one of this field.

### Layout

#### Header

* tileWidth: ubyte. Must be dividable with the width of the source image.

* tileHeight: ubyte. Must be dividable with the height of the source image.

#### Indexes

The following field contains indexes. The number of indexes are determined by the number of tiles can be stored in the file, which is calculated with the following formula:

```
N_indexes = (sourceWidth / tileWidth) * (sourceHeight / tileHeight)
```

Even if a tile isn't used, it must have an index.

* id: wchar. Identifies the tile being used on the screen. The type wchar is used by the engine, so unicode text can be displayed with some limitation.

* nameLength: ubyte. Determines how long the next field will be.

* (optional)name: char[]. If the previous is 0, this field isn't present. Contains the name of the tile

# Sheet extension

PNG ID: sHIT

TGA ID: 0xFF01

Describes different sized objects within an image file, such as sprites. One image can contain multiple of this fields as long as they have unique IDs.

### Layout

#### Header

* id: uint. Used for identification, can be set to zero if not needed.

* numOfIndexes: ushort. Describes the number of indexes within the field.

* nameLength: ubyte. Determines how long the next field will be.

* (optional)name: char[]. If the previous is 0, this field isn't present. Contains the name of the object

#### Indexes

The number of indexes are described in this field's header.

* id: uint. Used for identification. Must be unique within one index field.

* x: ushort(in TGA)/uint(in PNG). Describes where the given object begins (top-left corner).

* y: ushort(in TGA)/uint(in PNG). Describes where the given object begins (top-left corner).

* width: ubyte. The width of the object.

* height: ubyte. The height of the object.

* displayOffsetX: byte. Describes the offset compared to the average when the object needs to be displayed.

* displayOffsetY: byte. Describes the offset compared to the average when the object needs to be displayed.

* nameLength: ubyte. Determines how long the next field will be.

* (optional)name: char[]. If the previous is 0, this field isn't present. Contains the name of the object

# Adaptive Framerate Animation

PNG ID: aFRA

TGA ID: 0xFF02

Describes an animation that is tied to time of each frames rather than to a fixed framerate. Multiple ones can be in a single file.

### Layout

All times are in hundreds of microseconds (hμs) unless stated otherwise

#### Header

* id: uint. Identifier of the animation

* frames: uint. Number of individual frames of animation / indexes

* source: uint. Identifier of the object source. If tile extension is used instead of the sheet one, set it to zero.

* nameLength: ubyte. Determines how long the next field will be.

* (optional)name: char[]. If the previous is 0, this field isn't present. Contains the name of the animation

#### Indexes

* sourceID: uint. Identifier of the frame source.

* hold: uint. Duration of the frame.

* offsetX: byte. Horizontal offset for the frame.

* offsetY: byte. Vertical offset of the frame.
