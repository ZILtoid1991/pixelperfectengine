/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.tilelayer module
 */

module pixelperfectengine.graphics.layers.tilelayer;

public import pixelperfectengine.graphics.layers.base;
public import pixelperfectengine.graphics.shaders;
import pixelperfectengine.system.memory;
import collections.treemap;
import bindbc.opengl;
import std.math;
import inteli.emmintrin;
import pixelperfectengine.system.intrinsics;

/**
 * Implements a tile layer with some basic transformation and lighting capabilities.
 * Bugs:
 *   Default shaders apply transformation on the screen size vectors, this causes
 * rotation and shearing to look odd. Don't know if it can be fixed from CPU side,
 * a shader-side issue, or I have to rething the whole pipeline.
 */
public class TileLayer : Layer, ITileLayer {
	/**
	 * Defines a tile material with an identifier and material position.
	 * Only defines the upper-left corner of the material, since the rest can be easily 
	 * calculated with some additional constants.
	 * Bugs:
	 *   Functions `opCmp` don't work as should, and a temporary hack has been done to mitigate it.
	 */
	struct TileDefinition {
		wchar id = 0xFFFF;	/// Character identifier of the tile.
		ubyte paletteSh;	/// Defines how many bits are useful information.
		ubyte page;			/// The page the tile is contained on the texture array.
		ushort x;			/// X coordinate of the top-left corner.
		ushort y;			/// Y coordinate of the top-left corner.
		int opCmp(const ref wchar rhs) @nogc @safe pure nothrow const {
			return (id > rhs) - (id < rhs);
		}
		bool opEquals(const ref wchar rhs) @nogc @safe pure nothrow const {
			return id == rhs;
		}
		int opCmp(const ref TileDefinition rhs) @nogc @safe pure nothrow const {
			return (id > rhs.id) - (id < rhs.id);
		}
		bool opEquals(const ref TileDefinition rhs) @nogc @safe pure nothrow const {
			return id == rhs.id;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return id;
		}
	}
	/**
	 * Defines a page in the texture array, purely used for the ID system.
	 */
	struct PageDefinition {
		int id;
		int page;
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			return (id > rhs) - (id < rhs);
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return id == rhs;
		}
		int opCmp(const ref PageDefinition rhs) @nogc @safe pure nothrow const {
			return (id > rhs.id) - (id < rhs.id);
		}
		bool opEquals(const ref PageDefinition rhs) @nogc @safe pure nothrow const {
			return id == rhs.id;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return id;
		}
	}
	protected TileLayer		linkedLayer;	/// Stores reference to the secondary layer if layer linking is used, null otherwise
	protected __m128d		textureRec;
	protected int			tileX;	/// Tile width
	protected int			tileY;	/// Tile height
	protected int			mX;		/// Map width
	protected int			mY;		/// Map height
	protected size_t		totalX;	/// Total width of the tilelayer in pixels
	protected size_t		totalY;	/// Total height of the tilelayer in pixels
	protected MappingElement2[] mapping;/// Contains the mapping data.
	protected GraphicsAttrExt[] mapping_grExt;/// Contains the extended mapping data.
	protected GLShader		shader;	/// The main shader program used on the layer.
	protected DynArray!TileVertex gl_displayList;	/// Contains the verticles to be displayed
	protected DynArray!PolygonIndices gl_polygonIndices;	/// Contains the verticle indexes of each tile
	protected DynArray!ubyte gl_textureData;	/// Contains the data for the texture
	/// Contains the tile definitions for the layer.
	protected OrderedArraySet!(TileDefinition/+, "a < b"+/) tiles;
	/// Contains the page definitions for the layer.
	protected OrderedArraySet!PageDefinition pages;
	protected int			gl_textureWidth;	/// Defines the width of the texture
	protected int			gl_textureHeight;	/// Defines the height of the texture
	protected short			gl_texturePages;	/// Defines the number of pages of the texture array
	protected short			textureType;		/// Defines the type of the texture
	/// Contains OpenGL buffer identifiers.
	protected uint gl_vertexArray, gl_vertexBuffer, gl_vertexIndices;
	protected GLuint		gl_texture;	/// Contains the OpenGL texture identifier.
	//private wchar[] mapping;
	//private BitmapAttrib[] tileAttributes;
	protected Color[] 		src;		///Local buffer DEPRECATED!
	protected short			x0;			///
	protected short			y0;
	protected short			scaleH = 0x01_00;
	protected short			scaleV = 0x01_00;
	protected short			shearH;
	protected short			shearV;
	protected ushort		theta;
	// protected int			sX0, sY0;

	/**
	 * Enables the TileLayer to access other parts of the palette if needed.
	 * Does not effect 16 bit bitmaps, but effects all 4 and 8 bit bitmap
	 * within the layer, so use with caution to avoid memory leakages.
	 */
	public ushort			paletteOffset;
	/**
	 * Sets the warp mode of the layer.
	 * Can repeat the whole layer, a single tile, or be turned off completely.
	 */
	public WarpMode			warpMode;
	public ubyte		masterVal;		///Sets the master alpha value for the layer
	///Emulates horizontal blanking interrupt effects, like per-line scrolling.
	///line no -1 indicates that no lines have been drawn yet.
	public @nogc void delegate(int line, ref int sX0, ref int sY0) hBlankInterrupt;//DEPRECATED!
	///Constructor. tX , tY : Set the size of the tiles on the layer. DEPRECATED
	this (int tX, int tY, GLShader shader = GLShader(0)) @nogc @trusted nothrow {
		tileX=tX;
		tileY=tY;
		this.shader = shader;
		gl_displayList.reserve(256);
		gl_polygonIndices.reserve(256);
		tiles.reserve(16);
		pages.reserve(4);
		glGenVertexArrays(1, &gl_vertexArray);
		glGenBuffers(1, &gl_vertexBuffer);
		glGenBuffers(1, &gl_vertexIndices);
		glGenTextures(1, &gl_texture);
		glBindTexture(GL_TEXTURE_2D_ARRAY, gl_texture);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_R, GL_CLAMP);
		masterVal = 0xFF;
	}
	~this() @nogc @trusted nothrow {
		glDeleteBuffers(1, &gl_vertexIndices);
		glDeleteBuffers(1, &gl_vertexBuffer);
		glDeleteVertexArrays(1, &gl_vertexArray);
		glDeleteTextures(1, &gl_texture);
		gl_displayList.free();
		gl_polygonIndices.free();
		tiles.free();
		pages.free();
		gl_textureData.free();
		mapping.nogc_free();
		mapping_grExt.nogc_free();
	}
	/**
	 * Adds a bitmap source to the layer.
	 * Params:
	 *   bitmap = the bitmap to be uploaded as a texture.
	 *   page = page identifier.
	 * Returns: Zero on success, or a specific error code.
	 */
	public override int addBitmapSource(ABitmap bitmap, int page, ubyte palSh = 8) @trusted @nogc nothrow {
		try {
			if (gl_textureData.length == 0) {
				gl_textureWidth = bitmap.width();
				gl_textureHeight = bitmap.height();
				if (typeid(bitmap) is typeid(Bitmap8Bit)) textureType = 8;
				else if (typeid(bitmap) is typeid(Bitmap32Bit)) textureType = 32;
				textureRec = _vect([1.0 / (gl_textureWidth - 1), 1.0 / (gl_textureHeight - 1)]);
				gl_textureData.reserve(bitmap.width * bitmap.height * (textureType / 8));
			} else if (gl_textureWidth != bitmap.width() || gl_textureHeight != bitmap.height()) {
				return TextureUploadError.TextureSizeMismatch;
			}
			if (typeid(bitmap) is typeid(Bitmap8Bit)) {
				if (textureType != 8) return TextureUploadError.TextureTypeMismatch;
				gl_textureData.appendAtEnd((cast(Bitmap8Bit)bitmap).getRawdata());
				glBindTexture(GL_TEXTURE_2D_ARRAY, gl_texture);
				glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RED, gl_textureWidth, gl_textureHeight, gl_texturePages + 1, 0, GL_RED,
						GL_UNSIGNED_BYTE, gl_textureData.ptr);
				pages.insert(PageDefinition(page, gl_texturePages));
			} else if (typeid(bitmap) is typeid(Bitmap32Bit)) {
				if (textureType != 32) return TextureUploadError.TextureTypeMismatch;
				gl_textureData.appendAtEnd(cast(ubyte[])((cast(Bitmap32Bit)bitmap).getRawdata()));
				glBindTexture(GL_TEXTURE_2D_ARRAY, gl_texture);
				glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA, gl_textureWidth, gl_textureHeight, gl_texturePages + 1, 0, GL_RGBA8,
						GL_UNSIGNED_INT_8_8_8_8, gl_textureData.ptr);
				pages.insert(PageDefinition(page, gl_texturePages));
			}

			gl_texturePages++;
		} catch (NuException e) {
			e.free;
			return TextureUploadError.OutOfMemory;
		} catch (Exception e) {

		}
		return 0;
	}
	/**
	 * Removes the seleced bitmap source and optionally runs the appropriate destructor code. Can remove bitmap
	 * sources made by functions `addBitmapSource` and `addTextureSource_GL`.
	 * Params:
	 *   page = the page identifier of the to be removed texture.
	 *   runDTor = if true, the texture will be deleted from the GPU memory. Normally should be true.
	 * Returns: 0 on success, or -1 if page entry not found.
	 */
	public override int removeBitmapSource(int page, bool runDTor = true) @trusted @nogc nothrow {
		return 0;
	}
	/**
	 * Adds an OpenGL texture source to the layer, including framebuffers.
	 * Params:
	 *   texture = The texture ID.
	 *   page = Page identifier.
	 *   width = Width of the texture in pixels.
	 *   height = Height of the texture in pixels.
	 *   palSh = Palette shift amount, 8 is used for 8 bit images/256 color palettes.
	 * Returns: Zero on success, or a specific error code.
	 */
	public override int addTextureSource_GL(GLuint texture, int page, int width, int height, ubyte palSh = 8) @trusted @nogc nothrow {
		return -10;
	}
	/// Reprocesses the display list for the tilemap and applies anz changes made since.
	public final void reprocessTilemap() @trusted @nogc nothrow {
		// sX0 = sX;
		// sY0 = sY;
		//clear the display lists
		gl_displayList.length = 0;
		gl_polygonIndices.length = 0;
		//rebuild the display list
		const xFrom = sX - overscanAm[0];
		const xTo = sX + overscanAm[2] + tileX + rasterX;
		const yFrom = sY - overscanAm[1];
		const yTo = sY + overscanAm[3] + tileY + rasterY;
		for (int y = yFrom, ty ; y <= yTo && ty <= 255 ; y += tileY, ty++) {
			for (int x = xFrom, tx ; x <= xTo && tx <= 255 ; x += tileX, tx++) {
				MappingElement2 me = tileByPixel(x, y);
				if (me.tileID != 0xFFFF) {
					TileDefinition td = tiles.searchBy(me.tileID);
					if (td.id == 0xFFFF) continue;
					const p = cast(int)gl_displayList.length;
					const h1 = me.hMirror ? tx + 1 : tx;
					const h2 = me.hMirror ? tx : tx + 1;
					const v1 = me.vMirror ? ty + 1 : ty;
					const v2 = me.vMirror ? ty : ty + 1;
					const xy11 = me.xyInvert ? td.x : td.x + tileX;
					const xy21 = me.xyInvert ? td.x + tileX : td.x;
					const xy12 = me.xyInvert ? td.y + tileY : td.y;
					const xy22 = me.xyInvert ? td.y : td.y + tileY;
					gl_polygonIndices ~= PolygonIndices(p + 0, p + 1, p + 2);
					gl_polygonIndices ~= PolygonIndices(p + 1, p + 3, p + 2);
					GraphicsAttrExt uniform;
					uniform.a = masterVal;
					gl_displayList ~= TileVertex(cast(ubyte)h1, cast(ubyte)v1,
							cast(ushort)((me.paletteSel<<td.paletteSh) + paletteOffset),
							PackedTextureMapping(td.x, td.y, td.page), uniform);
					gl_displayList ~= TileVertex(cast(ubyte)h2, cast(ubyte)v1,
							cast(ushort)((me.paletteSel<<td.paletteSh) + paletteOffset),
							PackedTextureMapping(xy11, xy12, td.page), uniform);
					gl_displayList ~= TileVertex(cast(ubyte)h1, cast(ubyte)v2,
							cast(ushort)((me.paletteSel<<td.paletteSh) + paletteOffset),
							PackedTextureMapping(xy21, xy22, td.page), uniform);
					gl_displayList ~= TileVertex(cast(ubyte)h2, cast(ubyte)v2,
							cast(ushort)((me.paletteSel<<td.paletteSh) + paletteOffset),
							PackedTextureMapping((td.x + tileX), (td.y + tileY), td.page), uniform);
				}
			}
		}
		//}
	}
	/**
	 * TODO: Start to implement to texture rendering once iota's OpenGL implementation is stable enough.
	 * Renders the layer's content to the texture target.
	 * Params:
	 *   workpad = The target texture.
	 *   palette = The texture containing the palette for color lookup.
	 *   palNM = Palette containing normal values for each index.
	 *   sizes = 0: width of the texture, 1: height of the texture, 2: width of the display area, 3: height of the display area
	 *   offsets = 0: horizontal offset of the display area, 1: vertical offset of the display area
	 */
	public override void renderToTexture_gl(GLuint workpad, GLuint palette, GLuint palNM, int[4] sizes, int[2] offsets)
			@nogc nothrow {
		// reprocessTilemap();
		//Constants begin
		__m128d screenSizeRec = _vect([2.0 / sizes[0], -2.0 / sizes[1]]);	//Screen size reciprocal with vertical invert

		immutable __m128 TRNS_PARAMS_REC = __m128([1.0 / 0x01_00, 1.0 / 0x01_00, 1.0 / 0x01_00, 1.0 / 0x01_00]);
		const sX0 = sX - overscanAm[0], sY0 = sY - overscanAm[1];
		const tXMod = sX0%tileX, tYMod = sY0%tileY;
		//Constants end
		if (flags & CLEAR_Z_BUFFER) glClear(GL_DEPTH_BUFFER_BIT);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, palette);
		if (palNM) {
			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, palNM);
		}
		//Calculate transform parameters
		short[4] abcd = [scaleH, shearH, shearV, scaleV];
		const double thetaF = PI * 2.0 * (theta * (1.0 / ushort.max));
		const __m128 rotateVec = _vect([cos(thetaF), -1.0 * sin(thetaF), sin(thetaF), cos(thetaF)]);
		const __m128 trnsParams = matrix22Mult(_conv4shorts(abcd.ptr), rotateVec) * TRNS_PARAMS_REC;
		//Render begin
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D_ARRAY, gl_texture);
		GLuint currshader = shader;
		glUseProgram(currshader);
		glUniform1i(glGetUniformLocation(currshader, "mainTexture"), 0);
		glUniform1i(glGetUniformLocation(currshader, "palette"), 1);
		glUniform1i(glGetUniformLocation(currshader, "paletteMipMap"), 2);
		glUniformMatrix2fv(glGetUniformLocation(currshader, "transformMatrix"), 1, GL_FALSE, &trnsParams[0]);
		glUniform2f(glGetUniformLocation(currshader, "transformPoint"), x0 * screenSizeRec[0], y0 * screenSizeRec[1]);
		glUniform2f(glGetUniformLocation(currshader, "bias"),
				screenSizeRec[0] * ((overscanAm[0]) + (tXMod) + (sX0 < 0 ? tileX - (tXMod ? 0 : tileX) : 0)),
				screenSizeRec[1] * ((overscanAm[1]) + (tYMod) + (sY0 < 0 ? tileY - (tYMod ? 0 : tileY) : 0)));
		glUniform2f(glGetUniformLocation(currshader, "tileSize"), screenSizeRec[0] * tileX, screenSizeRec[1] * tileY);

		glBindVertexArray(gl_vertexArray);

		glBindBuffer(GL_ARRAY_BUFFER, gl_vertexBuffer);
		glBufferData(GL_ARRAY_BUFFER, TileVertex.sizeof * gl_displayList.length, gl_displayList.ptr, GL_STATIC_DRAW);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_vertexIndices);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, PolygonIndices.sizeof * gl_polygonIndices.length, gl_polygonIndices.ptr,
				GL_STATIC_DRAW);

		glEnableVertexAttribArray(0);
		glVertexAttribIPointer(0, 2, GL_UNSIGNED_BYTE, cast(int)(TileVertex.sizeof), cast(void*)0);
		glEnableVertexAttribArray(1);
		glVertexAttribIPointer(1, 1, GL_UNSIGNED_SHORT, cast(int)(TileVertex.sizeof), cast(void*)TileVertex.palSel.offsetof);
		glEnableVertexAttribArray(2);
		glVertexAttribIPointer(2, 1, GL_UNSIGNED_INT, cast(int)(TileVertex.sizeof), cast(void*)TileVertex.ptm.offsetof);
		glEnableVertexAttribArray(3);
		glVertexAttribIPointer(3, 4, GL_UNSIGNED_BYTE, cast(int)(TileVertex.sizeof),
				cast(void*)TileVertex.attributes.offsetof);
		glEnableVertexAttribArray(4);
		glVertexAttribIPointer(4, 2, GL_SHORT, cast(int)(TileVertex.sizeof),
				cast(void*)(TileVertex.attributes.lX.offsetof + GraphicsAttrExt.lX.offsetof));

		glDrawElements(GL_TRIANGLES, cast(int)(gl_polygonIndices.length * 3), GL_UNSIGNED_INT, null);
	}
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
	public void addTile(wchar id, int page, int x, int y, ubyte paletteSh = 0) @nogc @safe {
		const pageNum = pages.searchBy(page).page;
		tiles.insert(TileDefinition(id, paletteSh, cast(ubyte)pageNum, cast(ushort)x, cast(ushort)y));
	}
	/**
	 * Sets the rotation amount for the layer.
	 * Params:
	 *   theta = The amount of rotation for the layer, 0x1_00_00 means a whole round
	 * Note: This visual effect rely on overscan amount set correctly.
	 */
	public void rotate(ushort theta) @nogc @safe pure nothrow {
		this.theta = theta;
	}
	/**
	 * Sets the horizontal scaling amount.
	 * Params:
	 *   amount = The amount of horizontal scaling, 0x10_00 is normal, anything
	 * greater will minimize, lesser will magnify the layer. Negative values mirror
	 * the layer.
	 */
	public void scaleHoriz(short amount) @nogc @safe pure nothrow {
		scaleH = amount;
	}
	/**
	 * Sets the vertical scaling amount.
	 * Params:
	 *   amount = The amount of vertical scaling, 0x10_00 is normal, anything
	 * greater will minimize, lesser will magnify the layer. Negative values mirror
	 * the layer.
	 */
	public void scaleVert(short amount) @nogc @safe pure nothrow {
		scaleV = amount;
	}
	public void shearHoriz(short amount) @nogc @safe pure nothrow {
		shearH = amount;
	}
	public void shearVert(short amount) @nogc @safe pure nothrow {
		shearV = amount;
	}
	/**
	 * Sets the transformation midpoint relative to the middle of the screen.
	 * Params:
	 *   x0 = x coordinate of the midpoint.
	 *   y0 = y coordinate of the midpoint.
	 */
	public void setTransformMidpoint(short x0, short y0) {
		this.x0 = x0;
		this.y0 = y0;
	}
	/**
	 * Sets a color attribute table for the layer.
	 * Color attribute table can be per-tile, per-vertex, or unique to each vertex of
	 * the tile, depending on the size of the table.
	 * Params:
	 *   table = the array containing the initial information. Length must be width * height * 4
	 *   width = the width of the color attribute table.
	 *   height = the height of the color attribute table.
	 */
	public void setAttributeTable(GraphicsAttrExt[] table, int width, int height) {
		assert(mX == width);
		assert(mY == height);
		assert(table.length == mX * mY * 4);
		mapping_grExt = table;
	}
	/**
	 * Writes the color attribute table at the given location.
	 * Params:
	 *   x = X coordinate of the color attribute table.
	 *   y = Y coordinate of the color attribute table.
	 *   c = The color to be written at the selected loaction.
	 * Returns: the newly written color, or Color.init if color attribute table is not
	 * set.
	 */
	public GraphicsAttrExt[4] writeAttributeTable(int x, int y, GraphicsAttrExt[4] c) {
		assert(x >= 0 && x < mX);
		assert(y >= 0 && y < mY);
		const size_t pos = (x + (y * mX)) * 4;
		mapping_grExt[pos..pos+4] = c;
		return c;
	}
	/**
	 * Reads the color attribute table at the given location.
	 * Params:
	 *   x = X coordinate of the color attribute table.
	 *   y = Y coordinate of the color attribute table.
	 * Returns: the color at the given location, or Color.init if color attribute
	 * table is not set.
	 */
	public GraphicsAttrExt[4] readAttributeTable(int x, int y) {
		if (!mapping_grExt) return [GraphicsAttrExt.init, GraphicsAttrExt.init, GraphicsAttrExt.init, GraphicsAttrExt.init];
		final switch (warpMode) with (WarpMode) {
			case Off, TileRepeat:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return [GraphicsAttrExt.init, GraphicsAttrExt.init, GraphicsAttrExt.init, GraphicsAttrExt.init];
				}
				break;
			case MapRepeat:
				//x *= x > 0 ? 1 : -1;
				x = cast(uint)x % mX;
				//y *= y > 0 ? 1 : -1;
				y = cast(uint)y % mY;
				break;
		}
		const pos = (x+(mX*y))*4;
		return [mapping_grExt[pos], mapping_grExt[pos + 1], mapping_grExt[pos + 2], mapping_grExt[pos + 3]];

	}
	/**
	 * Clears the color attribute table and returns the table as a backup.
	 */
	public GraphicsAttrExt[] clearAttributeTable() {
		GraphicsAttrExt[] result = mapping_grExt;
		mapping_grExt = null;
		return result;
	}
	public void createAttributeTable() @nogc @safe {
		if (!mapping_grExt) mapping_grExt = nogc_initNewArray!GraphicsAttrExt(mapping.length * 4);
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	public MappingElement2 readMapping(int x, int y) @nogc @safe pure nothrow const {
		final switch (warpMode) with (WarpMode) {
			case Off:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return MappingElement2(0xFFFF, 0x000);
				}
				break;
			case MapRepeat:
				//x *= x > 0 ? 1 : -1;
				x = cast(uint)x % mX;
				//y *= y > 0 ? 1 : -1;
				y = cast(uint)y % mY;
				break;
			case TileRepeat:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return MappingElement2(0x0000, 0x000);
				}
				break;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	public void writeMapping(int x, int y, MappingElement2 w) @nogc @safe pure nothrow {
		if(x >= 0 && y >= 0 && x < mX && y < mY)
			mapping[x + (mX * y)] = w;
	}
	/**
	 * Writes a text to the map.
	 * This function is a bit rudamentary, as it doesn't handle word breaks, and needs per-line writing.
	 * Requires the text to be in 16 bit format
	 */
	public void writeTextToMap(const int x, const int y, const ubyte color, wstring text, 
			bool hMirror = false, bool vMirror = false) @nogc @safe pure nothrow {
		for (int i ; i < text.length ; i++) {
			writeMapping(x + i, y, MappingElement2(text[i], color, hMirror, vMirror));
		}
	}
	///Loads a mapping from an array. (Legacy)
	///x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping) @nogc @safe {
		//if (x * y != mapping.length) throw new MapFormatException("Incorrect map size!");
		mX=x;
		mY=y;
		this.mapping = nogc_newArray!MappingElement2(mapping.length);
		for (size_t i ; i < mapping.length ; i++) {
			this.mapping[i] = MappingElement2(mapping[i]);
		}
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Loads a mapping from an array. (Legacy)
	///x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement2[] mapping) @nogc @safe {
		//if (x * y != mapping.length) throw new MapFormatException("Incorrect map size!");
		mX=x;
		mY=y;
		this.mapping = mapping;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id) {
		sizediff_t index = tiles.searchIndexBy(id);
		if (index != -1) tiles.remove(index);
	}
	///Returns which tile is at the given pixel
	public MappingElement2 tileByPixel(int x, int y) @nogc @safe pure nothrow const {
		x = cast(uint)x / tileX;
		y = cast(uint)y / tileY;
		return readMapping(x, y);
	}
	public override LayerType getLayerType() @nogc @safe pure nothrow const {
		return LayerType.Tile;
	}

	public MappingElement2[] getMapping() @nogc @safe pure nothrow {
		return mapping;
	}
	public int getTileWidth() @nogc @safe pure nothrow const {
		return tileX;
	}
	public int getTileHeight() @nogc @safe pure nothrow const {
		return tileY;
	}
	public int getMX() @nogc @safe pure nothrow const {
		return mX;
	}
	public int getMY() @nogc @safe pure nothrow const {
		return mY;
	}
	public size_t getTX() @nogc @safe pure nothrow const {
		return totalX;
	}
	public size_t getTY() @nogc @safe pure nothrow const {
		return totalY;
	}
	/// Sets the warp mode.
	/// Returns the new warp mode that is being used.
	public WarpMode setWarpMode(WarpMode mode) @nogc @safe pure nothrow {
		return warpMode = mode;
	}
	/// Returns the currently used warp mode.
	public WarpMode getWarpMode() @nogc @safe pure nothrow const {
		return warpMode;
	}
	public void clearTilemap() @nogc @safe pure nothrow {
		for (size_t i ; i < mapping.length ; i++) {
			mapping[i] = MappingElement2.init;
		}
	}
	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette) {	//DEPRECATED

	}
}
