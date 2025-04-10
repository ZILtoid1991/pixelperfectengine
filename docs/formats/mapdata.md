```
+------------------+
|      HEADER      |
+------------------+
|                  |
|   Tilemap data   |
|                  |
+------------------+
|Graphics Attribute|
|     Extension    |
|    (Optional)    |
+------------------+
| Logic Attribute  |
|     Extension    |
|    (Optional)    |
+------------------+
```

# Header

## Layout

```
public struct MapDataHeader{
	public uint flags;		///Extra information in the form of binary flags
	public int sizeX;		///width of the map
	public int sizeY;		///Height of the map
}
```

### Notation

* `flags`: Stores extra information regarding the tilemap.
* `sizeX`: The width of the map.
* `sizeY`: The height of the map.

### Currently used flags

* bit 0: Field `p` in the binary chunks are repurposed as user data (old format), or that flags attribute extensions are present(new format).
* bit 1: Pield `S` in the binary chunks are repurposed as user data. NOTE: By default, this only works if all tiles are either 32 or 16 bit. Any 8 or 4 bit tile might cause an error, since the engine's tile layers use this field for 
palette-selection purposes.
* bit 2: Bit 10 in the chunk (bit 2 in the `attributes` field) is used to indicate if a tile's X and Y axes are interchanged for 90° rotation effects. If bit 0 is set, then the remaining 5 bits are used for other purposes.
* bit 3: If set, new format is being used.
* bit 4: If set, graphics attribute extensions are enabled.
* bit 8: Run-lenght encoding. See chapter "Compression" for more information.
* bit 9: LZW compression.
* bit 10: Zlib compression.
* bit 11: zstd compression.
* bit 16-17: Logic attribute extension size (L-L: 8 bits, L-H: 16 bits, H-L: 32 bits, H-H: 64 bits)

Bits 24-31 are user-definiable flags.

# Binary chunks

There's only one kind, so interpretation is quite easy.

Each chunk is 32 bit, and normally stored as a struct when loaded into the engine.

## Layout (old)

```
0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2|2|2|2|2|3|3
0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1
-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
C|C|C|C|C|C|C|C|C|C|C|C|C|C|C|C|p|p|p|p|p|p|V|H|S|S|S|S|S|S|S|S
```

or

```
public struct MappingElement {
	wchar tileID;				///Determines which tile is being used for the given instance
	BitmapAttrib attributes;	///General attributes, such as vertical and horizontal mirroring. The extra 6 bits can be used for various purposes
	ubyte paletteSel;			///Selects the palette for the bitmap if supported
}
```

All data is in little-endian order.

### Notation

* `C` or `tileID`: Selects the tile for the given cell. 0xFFFF means there's no tile for that cell.
* `p` or upper six bits of `attributes`: Unused by the engine at the moment, can be used to store extra data if needed 
as long as the given layer doesn't use it for other purposes.
* `V` or second bit of `attributes`: Vertical mirroring of the tile.
* `H` or first bit of `attributes`: Horizontal mirroring of the tile.
* `S` or `paletteSel`: Selects the palette for the tile. Not used by 32 and 16 bit tiles. If a tile uses palettes 
smaller than 256 color, then the number of accessible colors are less than 65536, and the upper ranges of the palettes
can be accessed by per-layer color shifting. Can be used to store extra data, but please be noted that this will only
work with 32 and 16 bit tiles

## Layout (new)

```
0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2|2|2|2|2|3|3
0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1
-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
C|C|C|C|C|C|C|C|C|C|C|C|C|C|C|C|S|S|S|S|S|S|S|S|S|S|S|S|H|V|I|p
```

### Notation:

* C/tileID: selects the tile to be used. Default value is 0xFFFF, which is transparent. 0x0000 is the same tile that repeats in warp mode `tileRepeat`.
* S/paletteSel:selects the palette to be used for the tile.
* H/hMirror: horizontally mirrors the tile.
* * V/vMirror: vertically mirrors the tile.
* I/xyInvert: inverts the X and Y axes, which can be used to implement 90 and 270 degree rotation effects. This effect might look wrong on tiles with non-square tiles.
* p/priority: if set, then the tile should be drawn on the second pass, over the sprites.
 
## Graphics attribute extension

The graphics attribute extension adds 6x4 additional fields for each tile, which can be used for lighting simulation, etc. The graphics attribute extension is never interleaved with the main tile data, and instead resides after the main map data and before the logic attribute extension.

### Layout:

* r: 8 bit unsigned, describes the red channel data, default value is 0x80.
* r: 8 bit unsigned, describes the green channel data, default value is 0x80.
* r: 8 bit unsigned, describes the blue channel data, default value is 0x80.
* r: 8 bit unsigned, describes the alpha channel data, default value is 0xFF.
* lX: 16 bit signed, describes the x direction of the lighting, default value is 0x00_00.
* lY: 16 bit signed, describes the y direction of the lighting, default value is 0x00_00.

There's four of these for each corner of the tiles, in the following order:
```
tile 0 upper-left ; tile 0 upper-right ; tile 0 lower-left ; tile 0 lower-right ; tile 1 upper-left
```

## Logic attribute extension

The logic attribute extension adds user-defined bitfields to the map, that can be used in the game logic. The data has a user defined size of 8, 16, 32, and 64 bits in size. It is never interleaved with any other data, and is instead resides after both the tilemap data and the graphics attribute extension.

# Compression

The format by default supports RLE (Run-Lenght Encoding) compression, but as of this version, it's unimplemented by the engine. RLE is indicated by bit 8 in the bitflags section of the header. Works similarly to TGA's own RLE compression format.

Each RLE block begins with an identifier byte. The most significant bit indicates whether the section is a literal (low), or an RLE (high) block, the remaining 7 bits identify he length of the block (1-128).