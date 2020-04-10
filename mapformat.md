Prerequirements:

* Knowledge of SDLang (https://sdlang.org/)
* Basic knowledge of the engine architecture

This document is not finished, although I plan to minimize changes that would break a lot of things.

Extension: `.XMF` (Extendible Map Format)

# Metadata

* Has no namespace
* Position restraint: in root tag, preferrably the first tag in the file if the file doesn't start with a comment

Contains various metadata for the map.

### Version

`Version 1 0`

Contains the format version information. `value[0]` is the major version, `value[1]` is the minor version.

### ExtType

`ExtType "nameOfYourGame" 1 1 7`

Identifies what kind of extensions this file has. `value[0]` is universally a string, the other values are not bound, can be used for eg. version information of the given extension.

### Software

`Software "PixelPerfectEditor" 0 9 4`

Identifies the last software that was used to edit this file. `value[0]` is the name of the editor, values 1 through 3 are version numbers (major, minor, and revision).

### Resolution

`Resolution 424 240`

Sets the resolution used to display the map.

### Other standardized tags that can appear in this chunk

All of these tags are single value, so they will have a shorter explanation. If any of these are null, then they should be absent.

* `Name`: Name of the map.
* `Comment`: A comment about the map.
* `Creator`: Name of the creator.
* `Team`: Name of the creator team.
* `DateOfCreation`: Date of creation.
* `DateOfLastModification`: Date of last modification.

# Namespace 'Layer'

* Position constraints: In root tag, preferrably in order of display from bottom to top.

Contains data about the layers. First value is always the layer name, second value is always the priority.

## Tile

Contains data related to tile layers.

As of version 1.0, TileLayers can have additional ancillary tags as long as they don't have a collision with others within a single layer. Within all those tags, there can be even more child tags with the same rule. Namespaces are restricted to internal use.

`Layer:Tile "Background 0" 0 32 32 256 256`

`value[0]` is the name of the layer, `value[2]` and `value[3]` are horizontal and vertical tile sizes, `value[4]` and `value[5]` are horizontal and vertical map sizes

### RenderingMode

`RenderingMode "AlphaBlending"`

Sets the rendering mode of the layer. Currently accepted values are: "Copy", "Blitter", "AlphaBlending", "Add", "Subtract", "Multiply", "Diff", "Screen", "ABAdd", "ABSub", "ABMult", "ABDiff", "ABScrn", "AND", "OR", "XOR".

## Sprite

Contains data related to sprite layers.

As of version 1.0, SpriteLAyers can have additional ancillary tags as long as they don't have a collision with others within a single layer. Within all those tags, there can be even more child tags with the same rule. Namespaces are restricted to internal use.

`Layer:Sprite "Playfield A" 1`

`value[0]` is the name of the layer.


### RenderingMode

`RenderingMode "AlphaBlending"`

Sets the rendering mode of the layer. Currently accepted values are: "Copy", "Blitter", "AlphaBlending", "Add", "Subtract", "Multiply", "Diff", "Screen", "ABAdd", "ABSub", "ABMult", "ABDiff", "ABScrn", "AND", "OR", "XOR". Current engine version only supports the first three values.

# Namespace 'Embed'

* Position constraints: Within the tag of any layer, with no preferrence of order.

Specifies data that is embedded within this file. These can be: Mapping data, names and IDs of individual tiles, scripting files, etc.

## Tiledata

`embed:tiledata`

Stores embedded tiledata.

## Mapdata

`embed:mapdata`

Stores embedded mapdata encoded in BASE64.

# Namespace 'Object'

* Position constraints: Within the tag of any layer, with no preferrence of order.

Contains data related to a single object. These objects can be used for collision detection, events, sprites (only on sprite layers), etc.

First value is a string, the name of the instance, the second one is a priority ID (must be unique per layer!). Third value is usually the identifier of source.

Ancilliary tags are currently handled differently than in layers, meaning that more complex tag structure can be used. Processing of those should be done by the end user.

## Box

`Object:Box "nameOfObject" 15 position:left=22 position:top=22 position:right=32 position:bottom=30`

Defines a box object. Can be used for various purposes, e.g. event markdown, clipping on tile layers towards sprites, etc.

## Sprite

`Object:Sprite "playerObject" 0 0 x=200 y=200 scaleHoriz=1024 scaleVert=1024`

Defines a sprite object. Only can be used

# Namespace 'File'
