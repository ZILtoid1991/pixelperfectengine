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

public class TileLayer : Layer, ITileLayer {
	/**
	 * Implements a single tile to be displayed.
	 * Is ordered in a BinarySearchTree for fast lookup. DEPRECATED!
	 */
	protected struct DisplayListItem {//DEPRECATED!
		ABitmap tile;			///reference counting only
		void* pixelDataPtr;		///points to the pixeldata
		//Color* palettePtr;		///points to the palette if present
		wchar ID;				///ID, mainly as a padding to 32 bit alignment
		ubyte wordLength;		///to avoid calling the more costly classinfo
		/**
		 * Sets the maximum accessable color amount by the bitmap.
		 * By default, for 4 bit bitmaps, it's 4, and it enables 256 * 16 color palettes.
		 * This limitation is due to the way how the MappingElement struct works.
		 * 8 bit bitmaps can assess the full 256 * 256 palette space.
		 * Lower values can be described to avoid wasting palettes space in cases when the
		 * bitmaps wouldn't use their full capability.
		 */
		ubyte paletteSh;		
		/** 
		 * Creates a tile-ID association.
		 * Params:
		 *   ID = The character ID of the tile.
		 *   tile = The bitmap to become the tile
		 *   paletteSh = 
		 */
		this(wchar ID, ABitmap tile, ubyte paletteSh = 0) pure @safe {
			//palettePtr = tile.getPalettePtr();
			//this.paletteSel = paletteSel;
			this.ID = ID;
			this.tile=tile;
			if (typeid(tile) is typeid(Bitmap2Bit)) {
				wordLength = 2;
				this.paletteSh = paletteSh ? paletteSh : 2;
				pixelDataPtr = (cast(Bitmap2Bit)(tile)).getPtr;
			} else if (typeid(tile) is typeid(Bitmap4Bit)) {
				wordLength = 4;
				this.paletteSh = paletteSh ? paletteSh : 4;
				pixelDataPtr = (cast(Bitmap4Bit)(tile)).getPtr;
			} else if (typeid(tile) is typeid(Bitmap8Bit)) {
				wordLength = 8;
				this.paletteSh = paletteSh ? paletteSh : 8;
				pixelDataPtr = (cast(Bitmap8Bit)(tile)).getPtr;
			} else if (typeid(tile) is typeid(Bitmap16Bit)) {
				wordLength = 16;
				pixelDataPtr = (cast(Bitmap16Bit)(tile)).getPtr;
			} else if (typeid(tile) is typeid(Bitmap32Bit)) {
				wordLength = 32;
				pixelDataPtr = (cast(Bitmap32Bit)(tile)).getPtr;
			} else {
				throw new TileFormatException("Bitmap format not supported!");
			}
		}
		string toString() const {
			import std.conv : to;
			string result = to!string(cast(ushort)ID) ~ " ; " ~ to!string(pixelDataPtr) ~ " ; " ~ to!string(wordLength);
			return result;
		}
	}
	struct TileDefinition {
		wchar id = 0xFFFF;
		ubyte paletteSh;
		ubyte page;
		int x;
		int y;
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			return (id > rhs) - (id < rhs);
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
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
	protected __m128d		textureRec;
	protected int			tileX;	///Tile width
	protected int			tileY;	///Tile height
	protected int			mX;		///Map width
	protected int			mY;		///Map height
	protected size_t		totalX;	///Total width of the tilelayer in pixels
	protected size_t		totalY;	///Total height of the tilelayer in pixels
	protected MappingElement[] mapping;///Contains the mapping data
	protected GraphicsAttrExt[] mapping_grExt;
	protected GLShader		shader;	///The main shader program used on the layer
	protected DynArray!TileVertex gl_displayList;
	protected DynArray!PolygonIndices gl_polygonIndices;
	protected DynArray!ubyte gl_textureData;
	protected OrderedArraySet!TileDefinition tiles;
	protected OrderedArraySet!PageDefinition pages;
	protected int			gl_textureWidth;
	protected int			gl_textureHeight;
	protected short			gl_texturePages;
	protected short			textureType;
	protected uint gl_vertexArray, gl_vertexBuffer, gl_vertexIndices;
	protected GLuint		gl_texture;
	//private wchar[] mapping;
	//private BitmapAttrib[] tileAttributes;
	protected Color[] 		src;		///Local buffer DEPRECATED!
	protected int			prevSX, prevSY;
	protected short			x0, x0P;
	protected short			y0, y0P;
	protected short			scaleH, scaleHP;
	protected short			scaleV, scaleVP;
	protected short			shearH, shearHP;
	protected short			shearV, shearVP;
	protected ushort		theta, thetaP;
	alias DisplayList = TreeMap!(wchar, DisplayListItem, true);//DEPRECATED!
	protected DisplayList displayList;	///displaylist using a BST to allow skipping elements DEPRECATED!
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
		glBindTexture(GL_TEXTURE_3D, gl_texture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_R, GL_CLAMP);
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
				if (is(bitmap == Bitmap8Bit)) textureType = 8;
				else if (is(bitmap == Bitmap32Bit)) textureType = 32;
				textureRec = _vect([1.0 / (gl_textureWidth - 1), 1.0 / (gl_textureHeight - 1)]);
			} else if (gl_textureWidth != bitmap.width() || gl_textureHeight != bitmap.height()) {
				return TextureUploadError.TextureSizeMismatch;
			}
			if (is(bitmap == Bitmap8Bit)) {
				if (textureType != 8) return TextureUploadError.TextureTypeMismatch;
				gl_textureData ~= (cast(Bitmap8Bit)bitmap).getRawdata();
			} else if (is(bitmap == Bitmap32Bit)) {
				if (textureType != 32) return TextureUploadError.TextureTypeMismatch;
				gl_textureData ~= cast(ubyte[])((cast(Bitmap32Bit)bitmap).getRawdata());
			}
			gl_texturePages++;
			glBindTexture(GL_TEXTURE_3D, gl_texture);
			glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, textureType == 8 ? GL_RED : GL_RGBA, gl_textureWidth, gl_textureHeight,
					gl_texturePages, 0, textureType == 8 ? GL_R8 : GL_RGBA8,  GL_UNSIGNED_BYTE, gl_textureData.ptr);
			pages.insert(PageDefinition(page, gl_texturePages));
		} catch (NuException e) {
			e.free;
			return TextureUploadError.OutOfMemory;
		} catch (Exception e) {

		}
		return 0;
	}
	public final void reprocessTilemap() @trusted @nogc nothrow {
		if (sX != prevSX || sY != prevSY || scaleH != scaleHP || scaleV != scaleVP || shearH != shearHP ||
				shearV != shearVP || x0 != x0P || y0 != y0P || theta != thetaP) {	//check if any transform parameters changed, if yes, move onto the next step
			//set all previous vals to the current ones
			prevSX = sX;
			prevSY = sY;
			x0P = x0;
			y0P = y0;
			scaleHP = scaleH;
			scaleVP = scaleV;
			shearHP = shearH;
			shearVP = shearV;
			thetaP = theta;
			//clear the display lists
			gl_displayList.length = 0;
			gl_polygonIndices.length = 0;
			//rebuild the display list
			const xFrom = sX - cast(int)(rasterX * overscanAm);
			const xTo = sX + cast(int)(rasterX * (overscanAm + 1));
			const yFrom = sY - cast(int)(rasterY * overscanAm);
			const yTo = sY + cast(int)(rasterY * (overscanAm + 1));
			__m128d screenSizeRec = _vect([2.0 / rasterX, -2.0 / rasterY]);
			immutable __m128d OGL_OFFSET = __m128d([-1.0, 1.0]);
			immutable float Z_REC = 1.0 / ubyte.max;
			const __m128d tileSize = _conv2ints(tileX, tileY) * screenSizeRec;
			const __m128d tileSizeText = _conv2ints(tileX, tileY) * textureRec;
			const pagesRec = 1.0 / gl_texturePages;
			for (int y = yFrom ; y <= yTo ; y += tileY) {
				for (int x = xFrom ; x <= xTo ; x += tileX) {
					MappingElement me = tileByPixel(x, y);
					if (me.tileID != 0xFFFF) {
						TileDefinition td = tiles.searchBy(me.tileID);
						if (td.id == 0xFFFF) continue;
						const p = cast(int)gl_displayList.length;
						const z = me.attributes.priority * Z_REC;
						const u = td.page * pagesRec;
						gl_polygonIndices ~= PolygonIndices(p + 0, p + 1, p + 2);
						gl_polygonIndices ~= PolygonIndices(p + 1, p + 3, p + 2);
						__m128d positionULC = _conv2ints(x, y) * screenSizeRec + OGL_OFFSET;
						__m128 pULC = _mm_cvtpd_ps(positionULC), pLRC = _mm_cvtpd_ps(positionULC + tileSize);
						__m128d tileULC = _conv2ints(td.x, td.y) * textureRec;
						__m128 tULC = _mm_cvtpd_ps(tileULC), tLRC = _mm_cvtpd_ps(tileULC * tileSizeText);
						const colorSelY = (me.paletteSel + paletteOffset)>>(8-td.paletteSh),
								colorSelX = (me.paletteSel + paletteOffset)&((1<<(8-td.paletteSh))-1);
						gl_displayList ~= TileVertex(pULC[0], pULC[1], z, 0.5, 0.5, 0.5, 1.0, tULC[0], tULC[1], u, 0.0, 0.0,
								colorSelX, colorSelY);
						gl_displayList ~= TileVertex(pULC[0], pLRC[1], z, 0.5, 0.5, 0.5, 1.0, tULC[0], tLRC[1], u, 0.0, 0.0,
								colorSelX, colorSelY);
						gl_displayList ~= TileVertex(pLRC[0], pULC[1], z, 0.5, 0.5, 0.5, 1.0, tLRC[0], tULC[1], u, 0.0, 0.0,
								colorSelX, colorSelY);
						gl_displayList ~= TileVertex(pLRC[0], pLRC[1], z, 0.5, 0.5, 0.5, 1.0, tLRC[0], tLRC[1], u, 0.0, 0.0,
								colorSelX, colorSelY);
					}
				}
			}
		}
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
		reprocessTilemap();
		//Constants begin
		//Calculate what area is in the display area with scrolling, will be important for checking for offscreen sprites
		const Box displayAreaWS = Box.bySize(sX + offsets[0], sY + offsets[1], sizes[2], sizes[3]);
		__m128d screenSizeRec = _vect([2.0 / sizes[0], -2.0 / sizes[1]]);	//Screen size reciprocal with vertical invert
		const __m128d OGL_OFFSET = __m128d([-1.0, 1.0]) + screenSizeRec * _vect([cast(double)offsets[0], cast(double)offsets[1]]);	//Offset to the top-left corner of the display area
		immutable __m128d LDIR_REC = __m128d([1.0 / short.max, 1.0 / short.max]);
		immutable __m128 COLOR_REC = __m128([1.0 / 255, 1.0 / 255, 1.0 / 255, 1.0 / 255]);
		immutable __m128 TRNS_PARAMS_REC = __m128([1.0 / 0x10_00, 1.0 / 0x10_00, 1.0 / 0x10_00, 1.0 / 0x10_00]);
		const __m128i scrollVec = _vect([sX, sY, 0, 0]), offsetsVec = _mm_loadu_si64(offsets.ptr);
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
		__m128 trnsParams = _conv4shorts(abcd.ptr) * TRNS_PARAMS_REC * rotateVec;
		//Render begin
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D_ARRAY, gl_texture);
		glUseProgram(shader);
		glUniform1i(glGetUniformLocation(shader, "mainTexture"), 0);
		glUniform1i(glGetUniformLocation(shader, "palette"), 1);
		glUniform1i(glGetUniformLocation(shader, "paletteMipMap"), 2);
		glUniform2fv(glGetUniformLocation(shader, "transformMatrix"), 4, trnsParams.ptr);
		glUniform2f(glGetUniformLocation(shader, "transformPoint"), x0, y0);

		glBindVertexArray(gl_vertexArray);

		glBindBuffer(GL_ARRAY_BUFFER, gl_vertexBuffer);
		glBufferData(GL_ARRAY_BUFFER, TileVertex.sizeof * gl_displayList.length, gl_displayList.ptr, GL_STREAM_DRAW);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_vertexIndices);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, PolygonIndices.sizeof * gl_polygonIndices.length, gl_polygonIndices.ptr,
				GL_STREAM_DRAW);

		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cast(int)(TileVertex.sizeof), cast(void*)0);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, cast(int)(TileVertex.sizeof), cast(void*)(TileVertex.r.offsetof));
		glEnableVertexAttribArray(2);
		glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, cast(int)(TileVertex.sizeof), cast(void*)(TileVertex.s.offsetof));
		glEnableVertexAttribArray(3);
		glVertexAttribPointer(3, 2, GL_FLOAT, GL_FALSE, cast(int)(TileVertex.sizeof), cast(void*)(TileVertex.lX.offsetof));
		glEnableVertexAttribArray(4);
		glVertexAttribPointer(4, 2, GL_FLOAT, GL_FALSE, cast(int)(TileVertex.sizeof), cast(void*)(TileVertex.selX.offsetof));

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
		tiles.insert(TileDefinition(id, paletteSh, cast(ubyte)pageNum, x, y));
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
		shearH = amount;
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
	///Gets the the ID of the given element from the mapping. x , y : Position.
	public MappingElement readMapping(int x, int y) @nogc @safe pure nothrow const {
		final switch (warpMode) with (WarpMode) {
			case Off:
				if(x < 0 || y < 0 || x >= mX || y >= mY){
					return MappingElement(0xFFFF);
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
					return MappingElement(0x0000);
				}
				break;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	public void writeMapping(int x, int y, MappingElement w) @nogc @safe pure nothrow {
		if(x >= 0 && y >= 0 && x < mX && y < mY)
			mapping[x + (mX * y)] = w;
	}
	/**
	 * Writes a text to the map.
	 * This function is a bit rudamentary, as it doesn't handle word breaks, and needs per-line writing.
	 * Requires the text to be in 16 bit format
	 */
	public void writeTextToMap(const int x, const int y, const ubyte color, wstring text, 
			BitmapAttrib atrb = BitmapAttrib.init) @nogc @safe pure nothrow {
		for (int i ; i < text.length ; i++) {
			writeMapping(x + i, y, MappingElement(text[i], atrb, color));
		}
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping) @safe pure {
		if (x * y != mapping.length)
			throw new MapFormatException("Incorrect map size!");
		mX=x;
		mY=y;
		this.mapping = mapping;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(ABitmap tile, wchar id, ubyte paletteSh = 0) {
		if(tile.width==tileX && tile.height==tileY) {
			displayList[id] = DisplayListItem(id, tile, paletteSh);
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Returns a tile from the displaylist
	public ABitmap getTile(wchar id) {
		return displayList[id].tile;
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id) {
		displayList.remove(id);
	}
	///Returns which tile is at the given pixel
	public MappingElement tileByPixel(int x, int y) @nogc @safe pure nothrow const {
		x = cast(uint)x / tileX;
		y = cast(uint)y / tileY;
		return readMapping(x, y);
	}
	public override LayerType getLayerType() @nogc @safe pure nothrow const {
		return LayerType.Tile;
	}
	public @nogc override void updateRaster(void* workpad, int pitch, Color* palette) {
		import std.stdio : printf;
		int sX0 = sX, sY0 = sY;
		if (hBlankInterrupt !is null)
			hBlankInterrupt(-1, sX0, sY0);

		for (int line  ; line < rasterY ; line++) {
			if (hBlankInterrupt !is null)
				hBlankInterrupt(line, sX0, sY0);
			if ((sY0 >= 0 && sY0 < totalY) || warpMode != WarpMode.Off) {
				int sXlocal = sX0;
				int sYAbs = sY0 & int.max;
				const sizediff_t offsetP = line * pitch;	// The offset of the line that is being written
				void* w0 = workpad + offsetP;
				const int offsetY = sYAbs % tileY;		//Offset of the current line of the tiles in this line
				const int offsetX0 = tileX - ((cast(uint)sXlocal + rasterX) % tileX);		//Scroll offset of the rightmost column
				const int offsetX = (cast(uint)sXlocal % tileX);		//Scroll offset of the leftmost column
				int tileXLength = offsetX ? tileX - offsetX : tileX;
				for (int col ; col < rasterX ; ) {
					//const int sXCurr = col && sX < 0 ? sXlocal - tileXLength : sXlocal;
					const MappingElement currentTile = tileByPixel(sXlocal, sYAbs);
					if (currentTile.tileID != 0xFFFF) {
						const DisplayListItem tileInfo = displayList[currentTile.tileID];
						const int offsetX1 = col ? 0 : offsetX;
						const int offsetY0 = currentTile.attributes.vertMirror ? tileY - offsetY - 1 : offsetY;
						if (col + tileXLength > rasterX) {
							tileXLength -= offsetX0;
						}
						switch (tileInfo.wordLength) {
							case 2:
								import CPUblit.colorlookup : colorLookup2Bit;
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + (offsetX1 + (offsetY0 * tileX)>>>2);
								colorLookup2Bit(tileSrc, cast(uint*)src, (cast(uint*)palette) + 
										(currentTile.paletteSel<<tileInfo.paletteSh) + paletteOffset, tileXLength, offsetX1 & 2);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 4:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + (offsetX1 + (offsetY0 * tileX)>>>1);
								main4BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + 
										(currentTile.paletteSel<<tileInfo.paletteSh) + paletteOffset, tileXLength, offsetX1 & 1);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 8:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								main8BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + 
										(currentTile.paletteSel<<tileInfo.paletteSh) + paletteOffset, tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 16:
								ushort* tileSrc = cast(ushort*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								mainColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette), tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(src);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								break;
							case 32:
								Color* tileSrc = cast(Color*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								if(!currentTile.attributes.horizMirror) {
									mainRenderingFunction(cast(uint*)tileSrc,cast(uint*)w0,tileXLength,masterVal);
								} else {
									copy(cast(uint*)tileSrc, cast(uint*)src, tileXLength);
									flipHorizontal(src);
									mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength,masterVal);
								}
								break;
							default: break;
						}

					}
					sXlocal += tileXLength;
					col += tileXLength;
					w0 += tileXLength<<2;

					tileXLength = tileX;
				}
			}
			sY0++;
		}
	}
	public MappingElement[] getMapping() @nogc @safe pure nothrow {
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
			mapping[i] = MappingElement.init;
		}
	}
}
