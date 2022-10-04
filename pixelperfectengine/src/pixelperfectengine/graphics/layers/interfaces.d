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
	 * Adds a new tile to the layer.
	 * Params: 
	 *  tile: the bitmap representing the tile. Must be the same size as all the others. Some tilelayers might require
	 * an exact format of tiles.
	 *  id: the character ID of the tile represented on the map.
	 *  paletteSh: palette shift amount, or how many bits are actually used of the bitmap. This enables less than 16 
	 * or 256 color chunks on the palette to be selected.
	 * Throws: TileFormatException if size or format is wrong.
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
public interface ITTL {
	public @property short A() @nogc @safe nothrow pure const;
	public @property short B() @nogc @safe nothrow pure const;
	public @property short C() @nogc @safe nothrow pure const;
	public @property short D() @nogc @safe nothrow pure const;
	public @property short x_0() @nogc @safe nothrow pure const;
	public @property short y_0() @nogc @safe nothrow pure const;
	public @property short A(short newval) @nogc @safe nothrow pure;
	public @property short B(short newval) @nogc @safe nothrow pure;
	public @property short C(short newval) @nogc @safe nothrow pure;
	public @property short D(short newval) @nogc @safe nothrow pure;
	public @property short x_0(short newval) @nogc @safe nothrow pure;
	public @property short y_0(short newval) @nogc @safe nothrow pure;
}
/**
 *General SpriteLayer interface.
 */
public interface ISpriteLayer {
	///Clears all sprite from the layer.
	public void clear() @safe nothrow;
	///Removes the sprite with the given ID.
	public void removeSprite(int n) @safe nothrow;
	/** 
	 * Moves the sprite to the exact location.
	 * Params:
	 *   n = The identifier of the sprite.
	 *   x = New x position of the sprite.
	 *   y = New y position of the sprite.
	 */
	public void moveSprite(int n, int x, int y) @safe nothrow;
	/** 
	 * Relatively moves the sprite by the given values.
	 * Params:
	 *   n = The identifier of the sprite.
	 *   x = New x position of the sprite.
	 *   y = New y position of the sprite.
	 */
	public void relMoveSprite(int n, int x, int y) @safe nothrow;
	///Gets the coordinate of the sprite.
	public Box getSpriteCoordinate(int n) @nogc @safe nothrow;
	/** 
	 * Creates a sprite from a bitmap with the given data, then places it to the display list. (New architecture)
	 * Params:
	 *   sprt = The bitmap to be used as the sprite.
	 *   n = Priority ID of the sprite. Both identifies the sprite and decides it's display priority. Larger numbers will be drawn first, 
	 * and thus will appear behind of smaller numbers, which also include negatives.
	 *   x = X position of the sprite (top-left corner).
	 *   y = Y position of the sprite (top-left corner).
	 *   paletteSel = Selects a given palette.
	 *   paletteSh = Determines how many bits are being used, and thus the palette size for selection.
	 *   alpha = The transparency of the sprite.
	 *   scaleHoriz = Horizontal scaling of the sprite. 1024 is the base value, anything less will stretch, greater will shrink the sprite.
	 *   scaleVert = Ditto for vertical.
	 *   renderMode = Determines the rendering mode of the sprite. By default, it's determined by the layer itself. Any of the default 
	 * other methods can be selected here, or a specially written rendering function can be specified with a different function.
	 * Returns: The current area of the sprite.
	 */
	public Box addSprite(ABitmap sprt, int n, int x, int y, ushort paletteSel = 0, ubyte paletteSh = 0, 
			ubyte alpha = ubyte.max, int scaleHoriz = 1024, int scaleVert = 1024, RenderingMode renderMode = RenderingMode.init) 
			@safe nothrow;
	/+
	/** 
	 * Places a new sprite onto the layer with the given parameters.
	 * Params:
	 *   s = The bitmap to be displayed as the sprite.
	 *   n = Priority ID. Lower number (including negatives) get to drawn last, thus appearing on top.
	 *   c = The box that sets the position of the sprite.
	 *   paletteSel = The ID of the selected palette.
	 *   scaleHoriz = Horizontal scaling.
	 *   scaleVert = Vertical scaling.
	 */
	public void addSprite(ABitmap s, int n, Box c, ushort paletteSel = 0, int scaleHoriz = 1024, 
			int scaleVert = 1024) @safe nothrow;
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, 
			int scaleVert = 1024) @safe nothrow;+/
	///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow;
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(ABitmap s, int n) @safe nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, int x, int y) @safe nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, Box c) @safe nothrow;
	///Returns the displayed portion of the sprite.
	public @nogc Box getSlice(int n) @safe nothrow;
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns the old one.
	public Box setSlice(int n, Box slice) @safe nothrow;
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