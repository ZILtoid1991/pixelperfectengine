/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.base module
 */

module pixelperfectengine.graphics.layers.interfaces;

import pixelperfectengine.graphics.layers.base;

/**
 * Tile interface, defines common functions shared between tile layers.
 */
public interface ITileLayer {
	version (ppe_expglen) {
		/**
		 * Adds a new tile to the layer from the internal texture sources.
		 * Params: 
		 *  id = the character ID of the tile represented on the map.
		 *  page = selects which tilesheet page is the source of the tile (tilesheets begin at 0).
		 *  x = x offset of the tile on the sheet.
		 *  y = y offset of the tile on the sheet.
		 *  paletteSh = palette shift amount, or how many bits are actually used of the bitmap. This enables less than 16 
		 * or 256 color chunks on the palette to be selected.
		 */
		public void addTile(wchar id, int page, int x, int y, ubyte paletteSh = 0);
		/**
		 * Sets the rotation amount for the layer.
		 * Params:
		 *   theta = The amount of rotation for the layer, 0x1_00_00 means a whole round
		 * Note: This visual effect rely on overscan amount set correctly.
		 */
		public void rotate(ushort theta);
		/**
		 * Sets the horizontal scaling amount.
		 * Params:
		 *   amount = The amount of horizontal scaling, 0x10_00 is normal, anything 
		 * greater will minimize, lesser will magnify the layer. Negative values mirror 
		 * the layer.
		 */
		public void scaleHoriz(short amount);
		/**
		 * Sets the vertical scaling amount.
		 * Params:
		 *   amount = The amount of vertical scaling, 0x10_00 is normal, anything 
		 * greater will minimize, lesser will magnify the layer. Negative values mirror 
		 * the layer.
		 */
		public void scaleVert(short amount);
		/**
		 * Sets the transformation midpoint relative to the middle of the screen.
		 * Params:
		 *   x0 = x coordinate of the midpoint.
		 *   y0 = y coordinate of the midpoint.
		 */
		public void setTransformMidpoint(short x0, short y0);
		/**
		 * Writes to the transform lookup table.
		 * Params:
		 *   index = The index of the table, which correlates to the given line of the screen.
		 *   theta = Rotation amount. 0x10_00 means a whole rotation.
		 *   sX = Scrolling on the X axis.
		 *   sY = Scrolling on the Y axis.
		 *   x0 = x coordinate of the transformation midpoint.
		 *   y0 = y coordinate of the transformation midpoint.
		 *   sH = The amount of horizontal scaling, 0x10_00 is normal, anything 
		 * greater will minimize, lesser will magnify the layer. Negative values mirror 
		 * the layer.
		 *   sV = The amount of vertical scaling, 0x10_00 is normal, anything 
		 * greater will minimize, lesser will magnify the layer. Negative values mirror 
		 * the layer.
		 */
		public void writeTransformLookupTable(ushort index, ushort theta = 0, short sX = 0x00, short sY = 0x00, 
				short x0 = 0x00, short y0 = 0x00, short sH = 0x10_00, short sV = 0x10_00);
		/**
		 * Clears the transform lookup table.
		 */
		public void clearTransformLookupTable();
		/**
		 * Sets a color attribute table for the layer.
		 * Color attribute table can be per-tile, per-vertex, or unique to each vertex of 
		 * the tile, depending on the size of the table.
		 * Params:
		 *   table = the array containing the initial information. Length must be width * height
		 *   width = the width of the color attribute table.
		 *   height = the height of the color attribute table.
		 */
		public void setColorAttributeTable(Color[] table, int width, int height);
		/**
		 * Writes the color attribute table at the given location.
		 * Params:
		 *   x = X coordinate of the color attribute table.
		 *   y = Y coordinate of the color attribute table.
		 *   c = The color to be written at the selected loaction.
		 * Returns: the newly written color, or Color.init if color attribute table is not
		 * set.
		 */
		public Color writeColorAttributeTable(int x, int y, Color c);
		/**
		 * Reads the color attribute table at the given location.
		 * Params:
		 *   x = X coordinate of the color attribute table.
		 *   y = Y coordinate of the color attribute table.
		 * Returns: the color at the given location, or Color.init if color attribute 
		 * table is not set.
		 */
		public Color readColorAttributeTable(int x, int y);
		/**
		 * Clears the color attribute table and returns the table as a backup.
		 */
		public Color[] clearColorAttributeTable();
	}
	/// Retrieves the mapping from the tile layer.
	/// Can be used to retrieve data, e.g. for editors, saving game states
	public MappingElement[] getMapping() @nogc @safe pure nothrow;
	/** 
	 * Reads the mapping element from the given area, while accounting for warp mode.
	 * Params:
	 *   x = x offset of the tile.
	 *   y = y offset of the tile.
	 * Returns: The tile at the given point.
	 */
	public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const;
	/**
	 * Writes the given element into the mapping at the given location.
	 * Params:
	 *   x = x offset of the tile.
	 *   y = y offset of the tile.
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
	 *   x = x offset of the tile.
	 *   y = y offset of the tile.
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
/**
 * Defines functions specific to transformable tile layers.
 * All transform parameters (A, B, C, D) are 256-based "fractional integers".
 */
public interface ITTL {
    ///Returns the horizontal scaling amount.
    ///256 means no scaling, negative values flip everything horizontally.
	public @property short A() @nogc @safe nothrow pure const;
	///Returns the shearing amount on the X axis.
	///256 means one pixel moved downwards for each horizontal scanline.
	public @property short B() @nogc @safe nothrow pure const;
	///Returns the shearing amount on the Y axis.
	///256 means one pixel moved right for each vertical scanline.
	public @property short C() @nogc @safe nothrow pure const;
	///Returns the vertical scaling amount.
    ///256 means no scaling, negative values flip everything vertically.
	public @property short D() @nogc @safe nothrow pure const;
	///Returns the x origin point of the transformation relative to the screen.
	public @property short x_0() @nogc @safe nothrow pure const;
	///Returns the y origin point of the transformation relative to the screen.
	public @property short y_0() @nogc @safe nothrow pure const;
	///Sets the horizontal scaling amount.
    ///256 means no scaling, negative values flip everything horizontally.
	public @property short A(short newval) @nogc @safe nothrow pure;
	///Sets the shearing amount on the X axis.
	///256 means one pixel moved downwards for each horizontal scanline.
	public @property short B(short newval) @nogc @safe nothrow pure;
	///Sets the shearing amount on the Y axis.
	///256 means one pixel moved right for each vertical scanline.
	public @property short C(short newval) @nogc @safe nothrow pure;
	///Sets the vertical scaling amount.
    ///256 means no scaling, negative values flip everything vertically.
	public @property short D(short newval) @nogc @safe nothrow pure;
	///Returns the x origin point of the transformation relative to the screen.
	public @property short x_0(short newval) @nogc @safe nothrow pure;
	///Returns the y origin point of the transformation relative to the screen.
	public @property short y_0(short newval) @nogc @safe nothrow pure;
}
/**
 *General SpriteLayer interface.
 */
public interface ISpriteLayer {
	version (ppe_expglen) {
		/**
		 * Creates a sprite material for this layer.
		 * Params:
		 *   id = desired ID of the sprite material. Note that when updating a previously used one, sizes won't be updated for any displayed sprites.
		 *   page = identifier number of the sprite sheet being used.
		 *   area = the area on the sprite sheet that should be used as the source of the sprite material.
		 */
		public void createSpriteMaterial(int id, int page, Box area);
		/**
		 * Removes sprite material designated by `id`.
		 */
		public void removeSpriteMaterial(int id);
		/**
		 * Adds a sprite to the given location.
		 * Params:
		 *   sprt = Bitmap to be added as a sprite.
		 *   n = Priority ID of the sprite.
		 *   position = Determines where the sprite should be drawn on the layer.
		 *   paletteSel = Palette selector for indexed bitmaps.
		 *   paletteSh = Palette shift amount in bits.
		 *   alpha = Alpha channel for the whole of the sprite.
		 *   shaderID = Shader program identifier, zero for default.
		 */
		public Box addSprite(int sprt, int n, Quad position, ushort paletteSel = 0, ubyte paletteSh = 0, 
			ubyte alpha = ubyte.max, GLuint shaderID = 0) 
			@trusted nothrow;
		/**
		 * Adds a sprite to the given location.
		 * Params:
		 *   sprt = Bitmap to be added as a sprite.
		 *   n = Priority ID of the sprite.
		 *   position = Determines where the sprite should be drawn on the layer.
		 *   paletteSel = Palette selector for indexed bitmaps.
		 *   paletteSh = Palette shift amount in bits.
		 *   alpha = Alpha channel for the whole of the sprite.
		 *   shaderID = Shader program identifier, zero for default.
		 */
		public Box addSprite(int sprt, int n, Box position, ushort paletteSel = 0, ubyte paletteSh = 0, 
			ubyte alpha = ubyte.max, GLuint shaderID = 0) 
			@trusted nothrow;
		/**
		 * Adds a sprite to the given location.
		 * Params:
		 *   sprt = Bitmap to be added as a sprite.
		 *   n = Priority ID of the sprite.
		 *   position = Determines where the sprite should be drawn on the layer.
		 *   paletteSel = Palette selector for indexed bitmaps.
		 *   paletteSh = Palette shift amount in bits.
		 *   alpha = Alpha channel for the whole of the sprite.
		 *   shaderID = Shader program identifier, zero for default.
		 */
		public Box addSprite(int sprt, int n, Point position, ushort paletteSel = 0, ubyte paletteSh = 0, 
			ubyte alpha = ubyte.max, GLuint shaderID = 0) 
			@trusted nothrow;
	}
	///Clears all sprite from the layer.
	public void clear() @trusted nothrow;
	///Removes the sprite with the given ID.
	public void removeSprite(int n) @trusted nothrow;
	/** 
	 * Moves the sprite to the exact location.
	 * Params:
	 *   n = The identifier of the sprite.
	 *   x = New x position of the sprite.
	 *   y = New y position of the sprite.
	 */
	public void moveSprite(int n, int x, int y) @trusted nothrow;
	/** 
	 * Relatively moves the sprite by the given values.
	 * Params:
	 *   n = The identifier of the sprite.
	 *   x = New x position of the sprite.
	 *   y = New y position of the sprite.
	 */
	public void relMoveSprite(int n, int x, int y) @trusted nothrow;
	///Gets the coordinate of the sprite.
	public Box getSpriteCoordinate(int n) @nogc @trusted nothrow;
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
			@trusted nothrow;
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
	public RenderFunc setSpriteRenderingMode(int n, RenderingMode mode) @nogc @trusted pure nothrow;
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(ABitmap s, int n) @trusted nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, int x, int y) @trusted nothrow;
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, Box c) @trusted nothrow;
	///Returns the displayed portion of the sprite.
	public @nogc Box getSlice(int n) @trusted nothrow;
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns the old one.
	public Box setSlice(int n, Box slice) @trusted nothrow;
	///Returns the selected paletteID of the sprite.
	public @nogc ushort getPaletteID(int n) @trusted nothrow;
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen
	public @nogc ushort setPaletteID(int n, ushort paletteID) @trusted nothrow;
	///Scales bitmap horizontally
	public int scaleSpriteHoriz(int n, int hScl) @trusted nothrow;
	///Scales bitmap vertically
	public int scaleSpriteVert(int n, int vScl) @trusted nothrow;
	///Gets the sprite's current horizontal scale value
	public int getScaleSpriteHoriz(int n) @nogc @trusted nothrow;
	///Gets the sprite's current vertical scale value
	public int getScaleSpriteVert(int n) @nogc @trusted nothrow;
}