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

* bit 0: Field `p` in the binary chunks are repurposed as user data.
* bit 1: Pield `S` in the binary chunks are repurposed as user data. NOTE: By default, this only works if all tiles are
either 32 or 16 bit. Any 8 or 4 bit tile might cause an error, since the engine's tile layers use this field for 
palette-selection purposes.
* bit 2: Bit 10 in the chunk (bit 2 in the `attributes` field) is used to indicate if a tile's X and Y axes are 
interchanged for 90° rotation effects (not yet implemented). If bit 0 is set, then the remaining 5 bits are used for
other purposes.
* bit 8: Run-lenght encoding. See chapter "Compression" for more information.

Bits 24-31 are user-definiable flags.

# Binary chunks

There's only one kind, so interpretation is quite easy.

Each chunk is 32 bit, and normally stored as a struct when loaded into the engine.

## Layout

```
3|3|2|2|2|2|2|2|2|2|2|2|1|1|1|1|1|1|1|1|1|1|0|0|0|0|0|0|0|0|0|0
1|0|9|8|7|6|5|4|3|2|1|0|9|8|7|6|5|4|3|2|1|0|9|8|7|6|5|4|3|2|1|0
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

# Compression

The format by default supports RLE (Run-Lenght Encoding) compression, but as of this version, it's unimplemented by the
engine. RLE is indicated by bit 8 in the bitflags section of the header. Works similarly to TGA's own RLE compression
format.

Each RLE block begins with an identifier byte. The most significant bit indicates whether the section is a literal 
(low), or an RLE (high) block, the remaining 7 bits identify he length of the block (1-128).