# PixelPerfectEngine Extendible Map Format

NOTE: To be modified to the new resouce management system.

## Pre-requirements

* Knowledge of the XDL format (https://sdlang.org/)
* Basic knowledge of the engine architecture

This document is not finished, although I plan to minimize changes that would break a lot of things.

Currently the only changes since its initial version are:
* adding a constraint to tile IDs per layer, to avoid problems with ID collisions.  (1)
* polyline objects. (2)
* shared tile sources. (2)
* compression. (2)

Extensions: `.XMF` (Extendible Map Format) or `.ZMF` (Compressed Extendible Map format)

## Naming conventions

* PascalCase for tags and namespaces.
* camelCase for attributes.
* Use of namespaces in attributes should be avoided.

## Conventions with value vs. attribute usage

* Values are used for mandatory values.
* Attributes are used for optional values.

## Compression

NOTE: DataPak can compress multiple files together. In that case, uncompressed files should be used since multiple 
compression has diminishing returns, often resulting in bigger file sizes and slower access.

The first four bytes are compression algorithm identifiers. `ZLIB` are used for ZLib, and `ZSTD` are used for 
Zstandard. The rest is the compressed SDLang data.

# 'Metadata'

* Has no namespace
* Position restraint: in root tag, preferably the first tag in the file if the file doesn't start with a comment

Contains various metadata for the map.

### 'Version'

`Version 1 0`

Contains the format version information. `value[0]` is the major version, `value[1]` is the minor version.

### 'ExtType'

`ExtType "nameOfYourGame" 1 1 7`

Identifies what kind of extensions this file has. `value[0]` is universally a string, the other values are not bound,
can be used for eg. version information of the given extension.

### 'Software'

`Software "PixelPerfectEditor" 0 9 4`

Identifies the last software that was used to edit this file. `value[0]` is the name of the editor, values 1 through 3
are version numbers (major, minor, and revision).

### 'Resolution'

`Resolution 424 240`

Sets the resolution used to display the map.

### Other standardized tags that can appear in this chunk

All of these tags are single value, so they will have a shorter explanation. If any of these are null, then they 
should be absent.

* `Name`: Name of the map.
* `Comment`: A comment about the map.
* `Creator`: Name of the creator.
* `Team`: Name of the creator team.
* `DateOfCreation`: Date of creation.
* `DateOfLastModification`: Date of last modification.

# Namespace 'Layer'

* Position constraints: In root tag, preferably in order of display from bottom to top.

Contains data about the layers. First value is always the layer name, second value is always the priority.

## 'Tile'

Contains data related to tile layers.

As of version 1.0, TileLayers can have additional ancillary tags as long as they don't have a collision with others 
within a single layer. Within all those tags, there can be even more child tags with the same rule. Namespaces are 
restricted to internal use.

`Layer:Tile "Background 0" 0 32 32 256 256`

`value[0]` is the name of the layer, `value[2]` and `value[3]` are horizontal and vertical tile sizes, `value[4]` and 
`value[5]` are horizontal and vertical map sizes

## 'TransformableTile' (Deprecated)

`Layer:TransformableTile "Background 0" 0 32 32 256 256`

The same as tile, but can be transformed. Has power of two limitations on tile and map sizes.

### 'TransformParams'

`TransformParams 1.0 0.0 0.0 1.0 0 0`

or

`TransformParams 256 0 0 256 0 0`

Defines transform parameters for the whole layer. Parameters in order are: A, B, C, D, x₀, y₀.

First four can be either floating point or integer. See engine reference on Transformable tile layers for more info on
what those values do.

Per-scanline modification of the layer must be done in code.

## 'Sprite'

Contains data related to sprite layers.

As of version 1.0, SpriteLayers can have additional ancillary tags as long as they don't have a collision with others 
within a single layer. Within all those tags, there can be even more child tags with the same rule. Namespaces are 
restricted to internal use.

`Layer:Sprite "Playfield A" 1`

## Common subtags

### 'ShaderProgram'

`ShaderProgram "%SHADERS%/tile_%SHDRVER%.vert" "%SHADERS%/tile_%SHDRVER%.frag"`

Defines a single shader for the current layer.

### 'ShaderProgram32'

`ShaderProgram32 "%SHADERS%/tile_%SHDRVER%.vert" "%SHADERS%/tile32_%SHDRVER%.frag"`

Defines the 32 bit shader program for the layer if needed.

### 'RenderingMode'

`RenderingMode "AlphaBlend"`

Sets the rendering mode of the layer. Currently accepted values are: "Copy", "Blitter", "AlphaBlend", "Add", "AddBl", 
"Multiply", "MultiplyBl", "Subtract", "SubtractBl", "Diff", "DiffBl", "Screen", "ScreenBl", "AND", "OR", "XOR".

Will likely be deprecated in the future in favor of shader programs.

### 'RepeatMode'

`RepeatMode "SingleTile"`

Sets the repeat mode of the layer (only works on tile layers).

Possible values: "On", "Off", "SingleTile"

### 'ScrollRate#' X and Y

`ScrollRateX 0.325` and `ScrollRateY 0.25`

Sets the relative scrolling speed of the layers relative to the main one.

### 'TileFlagName#' 0 through 5

Names the tileflags for the tile editor.

## Reserved tags

* `EffectsLayer`
* `VectorizedTileLayer`
* `TransformableSpriteLayer`

# Namespace 'Embed'

* Position constraints: Within the tag of any layer and sometimes other tags, with no preferrence of order.

Specifies data that is embedded within this file. These can be: Mapping data, names and IDs of individual tiles, 
scripting files, etc.

## 'TileData'

`Embed:TileData`

Stores embedded tiledata. Should be within a `File:TileSource` tag.

Has a single kind of nameless tag in the given format:

`2 2 "sci-fi-tileset.tga0x0002"`

Explanations for values in order:

1) The ID of the tile. Must be between 0 and 65535. Each ID is unique per layer.
2) Determines which tile is requested from the sheet in left-to-right top-to-bottom order.
3) The name of the tile.

## 'MapData'

`Embed:MapData []`

Stores embedded mapdata encoded in BASE64.

## 'Palette'

`Embed:Palette [] offset=768`

Stores palette embedded as BASE64 code. Can have the attribute `offset`, which determines where the palette should be 
loaded in the raster. Should be a root tag.

## 'Script'

`Embed:Script [] lang="lua"`

Stores a script for a layer or an object.

# Namespace 'Shared'

Points to another layer/other to share embedded data between multiple layers, etc.

A `Shared:TileData` will share tiledata between two layers, a `Shared:MapData` will share tilemap data.

`Shared:TileData 0`

`value[0]` points to the source layer's priority ID.

# Namespace 'File'

Defines external file sources for the map.

Tags in the `File` namespace can have the `dataPakSrc` attribute, which specifies the datapak file the file is in.

## 'BOM'

`File:BOM "../assets/cityenv.bom" use=63`

Links to shared Image Loading Data (`.BOM`) files. The `use` attribute will select the used tilesheet, etc. ID, 
otherwise every relevant data will be pulled from it.

## 'MapData'

`File:MapData "64.map"`

Determines where the map file of the layer can be found. Must be part of a `Layer:Tile` tag.

## 'Palette'

`File:Palette "../assets/sci-fi-tileset.tga" palShift=5 offset=32`

Specifies the bitmap file that contains a palette needs to be loaded. Attribute `palShift` limits the size of the 
palette to avoid overwriting a previously loaded palette that comes after it, `offset` sets where the palette should be
stored on the raster.

## 'TileSource'

`File:TileSource "../assets/sci-fi-tileset.tga" palShift=5`

Specifies the bitmap file that contains the tiles. Must be part of a `Layer:Tile` tag. Can contain the `Embed:TileInfo`
tag if the file doesn't have some extension to contain the tileinfo. Attribute `palShift` sets the amount of palette 
shift for all imports from that file.

## 'SpriteSource'

`File:SpriteSource 32 "../assets/dlangman.tga" name="dlangman" horizOffset=0 vertOffset=0 width=32 height=32` or 
`File:SpriteSource 32 "../assets/sprites.tga" name="dlangman" sprite="dlangman"` if file has sprite sheet or tile 
extensions.

Specifies the bitmap for a sprite. 1st value contains the material ID, 2nd value contains the filename. The `name` 
attribute names the sprite. If the file doesn't have sprite sheet or tile extensions, then the attributes 
`horizOffset`, `vertOffset`, `width`, and `height` can specify such things; otherwise `sprite` attribute can be used 
with a name. 

## 'SpriteSheet'

`File:SpriteSheet "../assets/sprites.tga"`

Imports a whole spritesheet. If the target file doesn't have sprite or tile extensions, then this tag must have child
tag(s) to describe the sprites, also can be used to override the file's own extension.

### 'SheetData'

`SheetData id=56 name="Spritesheet"`

The `id` attribute sets the ID of the sheet (otherwise it's zero), the `name` sets the name of the spritesheet. Can be 
left out if not needed.

The tag must have at least one unnamed child tag to describe sprites.

`32 16 16 32 32 name="dlangman"`

Value notation:

1) Sprite ID. Must be unique per layer.
2) X position where the sprite begins.
3) Y position where the sprite begins.
4) Width of the sprite.
5) Height of the sprite.

`name` sets the name of the sprite, otherwise a generated name will be used in the editor.

## 'Script'

`File:Script "../script/something" lang="lua"`

Specifies a script for a layer or object.

# Namespace 'Object'

* Position constraints: Within the tag of any layer, with no preference of order.

Contains data related to a single object. These objects can be used for collision detection, events, sprites (only on 
sprite layers), etc.

First value is a string, the name of the instance, the second one is a priority ID (must be unique per layer!). Third 
value is usually the identifier of source.

Ancillary tags are currently handled differently than in layers, meaning that more complex tag structure can be used. 
Processing of those should be done by the end user.

## 'Box'

`Object:Box "nameOfObject" 15 22 22 32 30`

Defines a box object. Can be used for various purposes, e.g. event markdown, clipping on tile layers towards sprites, 
etc.

Value notation:

1) The name of the object.
2) Unique ID that belongs to the object.
3) Left.
4) Top,
5) Right,
6) and Bottom coordinates of the object.

### 'ToCollision'

Marks object to be added to collision detection.

## 'Quad'

`Object:Quad "nameOfObject" 16 0 0 15 0 0 15 15 15`

Defines a Quad object, can be used for various purposes.

Value notation:

1) Name of the object.
2) Unique ID.
3) Top-left X coordinate.
4) Top-left Y coordinate.
5) Top-right X coordinate.
6) Top-right Y coordinate.
7) Bottom-left X coordinate.
8) Bottom-left Y coordinate.
9) Bottom-right X coordinate.
10) Bottom-right Y coordinate.

## 'Polyline'

`Object:Polyline "nameOfObject" 9`

Defines a polyline object. Can be either open, or closed.

Value notation:

1) The name of the object.
2) Unique ID that belongs to the object.

This tag must have at least two point-defining child tags to define the object, in drawing order.

### 'Begin'

`Begin 2534 365`

The first point must always be a `Begin` tag. Values are x and y coordinates respectively. Should only have point-
related extra data tags.

### 'Segment'

`Segment 8646 3214`

All other points are named as `Segment`. Values are x and y coordinates respectively. Can have both point- and line-
related extra data tags.

Standardized segment-related extra tags:

#### 'Bezier'

`Bezier 864 213`

or

`Bezier0 87 84; Bezier1 84 87`

`Bezier` defines 3-point a bezier curve, and the `Bezier0` and `Bezier1` pairs define a 4-point bezier curve.

Values are x and y coordinates.

### 'Close'

`Close`

An optional final segment that is ensured to be connected to the first segment, or closes the polyline object. Can have
both point- and line-related extra data tags.

## 'Sprite' and 'QuadSprite'

`Object:Sprite "playerObject" 0 0 200 200 hMirror=true vMirror=true masterAlpha=250`

`Object:QuadSprite "playerObject" 0 0 200 200 250 200 200 250 250 250`

Defines a sprite object. Only can be used on sprite layers.

Value notation ('Sprite'):

1) The name of the object.
2) Unique sprite ID with priority in mind.
3) Sprite source identificator.
4) X coordinate of the upper-left corner.
5) Y coordinate of the upper-left corner.

Value notation ('QuadSprite'):

1) The name of the object.
2) Unique sprite ID with priority in mind.
3) Sprite source identificator.
4) X coordinate of the upper-left corner.
5) Y coordinate of the upper-left corner.
6) X coordinate of the upper-right corner.
7) Y coordinate of the upper-right corner.
8) X coordinate of the lower-left corner.
9) Y coordinate of the lower-left corner.
10) X coordinate of the lower-right corner.
11) Y coordinate of the lower-right corner.

Attributes:

- `scaleHoriz` and `scaleVert` sets the horizontal and vertical scaling values with 1024 (1.0) being the default one (deprecated).
- `hMirror` and `vMirror` mirrors the sprite either horizontally or vertically.
- `lrCornerX` and `lrCornerY` define the lower-right corner of a sprite, which is now the preferred way of implementing scaling. Can also mirror sprites if this corner is on the other side of the upper-left corner previously discussed.
- `masterAlpha` sets the master alpha value for rendering to the raster. `palSel` selects the palette, and `palShift` 
sets the length of the selected palette.

### 'ShaderProgram'

### 'RenderingMode'

`RenderingMode "AlphaBlend"`

Sets the rendering mode of the sprite. Currently accepted values are: "Copy", "Blitter", "AlphaBlend", "Add", "AddBl", 
"Multiply", "MultiplyBl", "Subtract", "SubtractBl", "Diff", "DiffBl", "Screen", "ScreenBl", "AND", "OR", "XOR".

Deprecated for shaders.

### 'ToCollision'

Marks object to be added to collision detection.

Can have the attribute `shape`, which will specify an ID to a 1 bit bitmap containing the shape.
