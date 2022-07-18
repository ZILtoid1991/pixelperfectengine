/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.base module
 */

module pixelperfectengine.graphics.layers.interfaces;

import pixelperfectengine.graphics.layers.base;

/**
 * Tile interface, defines common functions.
 */
public interface ITileLayer {
	/// Retrieves the mapping from the tile layer.
	/// Can be used to retrieve data, e.g. for editors, saving game states
	public MappingElement[] getMapping() @nogc @safe pure nothrow;
	/** 
	 * Reads the mapping element from the given area, while accounting for warp mode.
	 * Params:
	 *  x: x offset of the tile.
	 *  y: y offset of the tile.
	 * Returns: The tile at the given point.
	 */
	public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const;
	/**
	 * Writes the given element into the mapping at the given location.
	 * Params:
	 *  x: x offset of the tile.
	 *  y: y offset of the tile.
	 */
	public void writeMapping(int x, int y, MappingElement w) @nogc @safe pure nothrow;
	/** 
	 * Loads a mapping into the layer.
	 * Params:
	 *   x = width of the map.
	 *   y = height of the map.
	 *   mapping = an array representing the map.
	 * Throws: MapFormatException if width and height doesn't represent the map.
	 */
	public void loadMapping(int x, int y, MappingElement[] mapping) @safe pure;
	/// Removes the tile from the display list with the given ID.
	public void removeTile(wchar id) pure;
	/// .
	/** 
	 * Reads the mapping element from the given area, while accounting for warp mode.
	 * Params:
	 *  x: x offset of the tile.
	 *  y: y offset of the tile.
	 * Returns: The tile at the given point.
	 */
	public MappingElement tileByPixel(int x, int y) @nogc @safe pure nothrow const;
	/// Returns the width of the tiles.
	public int getTileWidth() @nogc @safe pure nothrow const;
	/// Returns the height of the tiles.
	public int getTileHeight() @nogc @safe pure nothrow const;
	/// Returns the width of the mapping.
	public int getMX() @nogc @safe pure nothrow const;
	/// Returns the height of the mapping.
	public int getMY() @nogc @safe pure nothrow const;
	/// Returns the total width of the tile layer.
	public size_t getTX() @nogc @safe pure nothrow const;
	/// Returns the total height of the tile layer.
	public size_t getTY() @nogc @safe pure nothrow const;
	/**
	 *
	 */
	public void addTile(ABitmap tile, wchar id, ubyte paletteSh = 0) pure;
	/// Returns the bitmap associated with the tile ID.
	public ABitmap getTile(wchar id) @nogc @safe pure nothrow;
	/// Sets the warp mode.
	/// Returns the new warp mode that is being used.
	public WarpMode setWarpMode(WarpMode mode) @nogc @safe pure nothrow;
	/// Returns the currently used warp mode.
	public WarpMode getWarpMode() @nogc @safe pure nothrow const;
	///Clears the tilemap
	public void clearTilemap() @nogc @safe pure nothrow;
}
/**
 *General SpriteLayer interface.
 */
public interface ISpriteLayer {
	///Clears all sprite from the layer.
	public void clear() @safe nothrow;
	///Removes the sprite with the given ID.
	public void removeSprite(int n) @safe nothrow;
	///Moves the sprite to the given location.
	public void moveSprite(int n, int x, int y) @safe nothrow;
	///Relatively moves the sprite by the given values.
	public void relMoveSprite(int n, int x, int y) @safe nothrow;
	///Gets the coordinate of the sprite.
	public Coordinate getSpriteCoordinate(int n) @nogc @safe nothrow;
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, Coordinate c, ushort paletteSel = 0, int scaleHoriz = 1024, 
			int scaleVert = 1024) @safe nothrow;
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, 
			int scaleVert = 1024) @safe nothrow;
	///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow;
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(ABitmap s, int n) @safe nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, int x, int y) @safe nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, Coordinate c) @safe nothrow;
	///Returns the displayed portion of the sprite.
	public @nogc Coordinate getSlice(int n) @safe nothrow;
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns the old one.
	public Coordinate setSlice(int n, Coordinate slice) @safe nothrow;
	///Returns the selected paletteID of the sprite.
	public @nogc ushort getPaletteID(int n) @safe nothrow;
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen
	public @nogc ushort setPaletteID(int n, ushort paletteID) @safe nothrow;
	///Scales bitmap horizontally
	public int scaleSpriteHoriz(int n, int hScl) @trusted nothrow;
	///Scales bitmap vertically
	public int scaleSpriteVert(int n, int vScl) @trusted nothrow;
	///Gets the sprite's current horizontal scale value
	public int getScaleSpriteHoriz(int n) @nogc @trusted nothrow;
	///Gets the sprite's current vertical scale value
	public int getScaleSpriteVert(int n) @nogc @trusted nothrow;
}