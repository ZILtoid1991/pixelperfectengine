# PixelPerfectEngine Image Loading Data Format

## Prerequirements

* Knowledge of SDLang (https://sdlang.org/)
* Basic knowledge of the engine architecture

This document is not finished, although I plan to minimize changes that would break a lot of things.

Extensions: `.BOM`

## Naming conventions

* PascalCase for tags and namespaces.
* camelCase for attributes.
* Use of namespaces in attributes should be avoided.

## Conventions with value vs. attribute usage

* Values are used for mandatory values.
* Attributes are used for optional values.

## Rationale

* To streamline sprite/tile loading, especially with many shared objects.
* To store sprite animation data in a human readable format, rather than being embedded into another file format.

# Common Attributes

# SheetData

`SheetData 56 "../assets/sprites.tga" name="Spritesheet"`

Contains spritesheet data. First value is spritesheed identifier, the second one is file source.

## Nameless subtags

`32 16 16 32 32 name="dlangman"`

Value notation:

1) Sprite ID. Must be unique.
2) X position where the sprite begins.
3) Y position where the sprite begins.
4) Width of the sprite.
5) Height of the sprite.

`name` sets the name of the sprite, otherwise a generated name will be used in the editor.

# AnimationData

`AnimationData 51 "../assets/sprites.tga" name="PlayerWalk" unit="msec" loop=true`

Contains animation data. First value is spritesheed identifier, the second one is file source.

## Nameless subtags

`100 0 0 16 16`

Value notation:

1) Frame duration in the unit described in parent tag, or 1/60th of seconds if not.
2) X position where the sprite begins.
3) Y position where the sprite begins.
4) Width of the sprite.
5) Height of the sprite.