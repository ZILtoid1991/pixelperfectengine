Scripting library reference table

# Lua

Note: structs are returned and sent to the Lua side as a sequence of values, except a certain special cases (Color,
MappingElement). Objects are treated as lightweight userdata.

## MappingElement

Every MappingElement is treated in Lua as an integer, and is highly recommended to write them in 8 digit hexadecimal 
numbers, such as `0x000f0200`

Quick legends:

`0xCCCC0FSS`

* `CCCC`: "Character selector", or tile ID.
* `0`: Originally was intended for priority, but not used for anything currently. Can be repurposed to store 
game-related data, etc.
* `F`: Least significant two bits of this nibble stores flags for horizontal (first bit) and vertical mirroring 
(second bit), most significant two bits are ignored as of now, and can be used for user data with some caution (one bit
for tile axis inversion might be implemented later on for transformable tile layers). A quick cheat sheet is: 0 = no 
mirroring; 1 = horizontal mirroring; 2 = vertical mirroring; 3 = both horizontal and vertical mirroring
* `SS`: Palette selector for 4 and 8 bit bitmaps, not used by 16 and 32 bit tiles (repurposable for them).

## Color

Color is also treated in Lua as an integer base, with the following hexadecimal layout:

`0xBBGGRRAA`

Every non-transparent color must have 255 (`FF`) as an alpha (`A`) value.

## Enumerators

All enumerators are handled as case-insensitive strings except noted otherwise.

## Built-in layer and raster handling functions

### Raster handling functions

#### setPaletteIndex

Sets the palette color at the given index.

Params:

* n = The index of the color to be edited.
* c = The color code.

#### getPaletteIndex

Returns the color code at the given index.

Params:

* n = The color index.

#### getLayer

Returns the layer with the givel priority identifier.

Params:

* n = The priority identifier of the layer. Can have negative values.

### Shared layer functions

#### getLayerType

Returns the type of the layer. Return value is copy of enumerator `pixelperfectengine.graphics.layers.base.LayerType`

Params:

* l = The layer.

#### setLayerRenderingMode

Sets the rendering mode for the layer.

Params:

* l = The layer.
* mode = The rendering mode as a string. Copy of enumerator `pixelperfectengine.graphics.layers.base.RenderingMode`

#### scrollLayer

Scrolls the layer to the exact location.

Params:

* l = The layer.
* x = The exact location's x coordinate. Rounded to nearest integer.
* y = The exact location's y coordinate. Rounded to nearest integer.

#### relScrollLayer

Scrolls the layer by a given amount.

Params:

* l = The layer.
* x = The amount of scrolling on the x axis. Rounded to nearest integer.
* y = The amount of scrolling on the y axis. Rounded to nearest integer.

#### getLayerScrollX

Returns the X position of the layer.

Params:

* l = The layer.

#### getLayerScrollY

Returns the Y position of the layer.

Params:

* l = The layer.

### Tile layer specific functions

#### readMapping

Reads the mapping at the given element location.

Params:

* l = The tilelayer.
* x = The horizontal position of the tile.
* y = The vertical position of the tile.

#### tileByPixel

Reads the mapping at the given pixel location.

Params:

* l = The tilelayer.
* x = The horizontal position of the tile.
* y = The vertical position of the tile.

#### writeMapping

Writes the mapping at the given element location.

Params:

* l = The tilelayer.
* x = The horizontal position of the tile.
* y = The vertical position of the tile.
* val = The value to be written to the mapping.

#### getTileWidth

Returns the width of the tiles contained by the tilelayer.

Params:

* l = The tilelayer.

#### getTileHeight

Returns the height of the tiles contained by the tilelayer.

Params:

* l = The tilelayer.

#### getMapWidth

Returns the map width in tiles unit.

Params:

* l = The tilelayer.

#### getMapHeight

Returns the map height in tiles unit.

Params:

* l = The tilelayer.

#### getTileWidth

Returns the width of the tiles used by the layer.

Params:

* l = The tilelayer.

#### getTileHeight

Returns the height of the tiles used by the layer.

Params:

* l = The tilelayer.

#### clearTilemap

Clears the mapping of the tilelayer.

Params:

* l = The tilelayer.

#### addTile

Adds a tile to the tilelayer.

Params:

* l = The tilelayer.
* tile = The bitmap representing the tile. Must be the same size as all the others. Some tilelayers might require an 
exact format of tiles.
* id = The character ID of the tile represented on the map.
* palette shift amount, or how many bits are actually used of the bitmap. This enables less than 16 or 256 color chunks
on the palette to be selected.

#### getTile

Returns the bitmap associated with the tile ID.

Params:

* l = The tilelayer.
* id = The character ID of the tile represented on the map.

#### removeTile

Removes the tile from the display list with the given ID.

Params:

* l = The tilelayer.
* id = The character ID of the tile represented on the map.

### Transformable tile layer specific functions

#### ttl_setA
#### ttl_setB
#### ttl_setC
#### ttl_setD
#### ttl_setx_0
#### ttl_sety_0
#### ttl_getA
#### ttl_getB
#### ttl_getC
#### ttl_getD
#### ttl_getx_0
#### ttl_gety_0

### Sprite layer specific functions

#### moveSprite
#### relMoveSprite
#### getSpriteCoordinate
#### setSpriteSlice
#### getSpriteSlice
#### addSprite
#### removeSprite
#### getPaletteID
#### setPaletteID
#### scaleSpriteHoriz
#### scaleSpriteVert
#### getScaleSpriteHoriz
#### getScaleSpriteVert

## Bitmap handling functions

### Loading and unloading

### Bitmap properties and manipulation

#### getBitmapWidth
#### getBitmapHeight