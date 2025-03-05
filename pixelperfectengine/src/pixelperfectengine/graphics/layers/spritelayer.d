/*
 * PixelPerfectEngine - Sprite layer module
 *
 * Copyright 2015 - 2025
 * Licensed under the Boost Software License
 * Authors:
 *   László Szerémi
 */

module pixelperfectengine.graphics.layers.spritelayer;

public import pixelperfectengine.graphics.layers.base;
import pixelperfectengine.system.memory;
import pixelperfectengine.system.intrinsics;
import pixelperfectengine.graphics.shaders;
import pixelperfectengine.system.exc;

import collections.treemap;
import collections.sortedlist;
import std.bitmanip : bitfields;
import bitleveld.datatypes;
import inteli;
import bindbc.opengl : GLuint;
import numem;


/**
 * General-purpose sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteLayer {
	/**
	 * Helps to determine the displaying properties and order of sprites. DEPRECATED
	 */
	public struct DisplayListItem {
		Box		position;			/// Stores the position relative to the origin point. Actual display position is determined by the scroll positions.
		Box		slice;				/// To compensate for the lack of scanline interrupt capabilities, this enables chopping off parts of a sprite.
		void*	pixelData;			/// Points to the pixel data.
		/**
		 * From version 0.10.0 onwards, each sprites can have their own rendering function set up to
		 * allow different effect on a single layer.
		 * If not specified otherwise, the layer's main rendering function will be used instead.
		 * Custom rendering functions can be written by the user, it requires knowledge of writing
		 * pixel shader-like functions using fixed-point arithmetics. Use of vector optimizatons
		 * techniques (SSE2, AVX, NEON, etc) are needed for optimal performance.
		 */
		@nogc pure nothrow void function(uint* src, uint* dest, size_t length, ubyte value) renderFunc;
		int		width;				/// Width of the sprite
		int		height;				/// Height of the sprite
		int		scaleHoriz;			/// Horizontal scaling
		int		scaleVert;			/// Vertical scaling
		int		priority;			/// Used for automatic sorting and identification.
		/**
		 * Selects the palette of the sprite.
		 * Amount of accessable color depends on the palette access shifting value. A value of 8 enables 
		 * 256 * 256 color palettes, and a value of 4 enables 4096 * 16 color palettes.
		 * `paletteSh` can be set lower than what the bitmap is capable of storing at its maximum, this
		 * can enable the packing of more palettes within the main one, e.g. a `paletteSh` value of 7
		 * means 512 * 128 color palettes, while the bitmaps are still stored in the 8 bit "chunky" mode
		 * instead of 7 bit planar that would require way more processing power. However this doesn't 
		 * limit the bitmap's ability to access 256 colors, and this can result in memory leakage if
		 * the developer isn't careful enough.
		 */
		ushort	paletteSel;
		//ubyte	flags;				/// Flags packed into a single byte (bitmapType, paletteSh)
		mixin(bitfields!(
			ubyte, "paletteSh", 4,
			ubyte, "bmpType", 4,
		));
		ubyte	masterAlpha = ubyte.max;/// Sets the master alpha value of the sprite, e.g. opacity
		/** 
		 * Creates a display list item according to the newer architecture.
		 * Params:
		 *   x = X position of the sprite.
		 *   y = Y position of the sprite.
		 *   sprite = The bitmap to be used as the sprite.
		 *   pri = Priority identifier.
		 *   paletteSel = Selects a given palette.
		 *   paletteSh = Determines how many bits are being used.
		 *   alpha = The transparency of the sprite.
		 *   scaleHoriz = Horizontal scaling of the sprite. 1024 is the base value, anything less will stretch, greater will shrink the sprite.
		 *   scaleVert = Ditto for vertical.
		 */
		this(int x, int y, ABitmap sprite, int priority, ushort paletteSel = 0, ubyte paletteSh = 0, ubyte alpha = ubyte.max, 
				int scaleHoriz = 1024, int scaleVert = 1024) pure @trusted nothrow {
			this.width = sprite.width();
			this.height = sprite.height();
			this.position = Box.bySize(x, y, cast(int)scaleNearestLength(width, scaleHoriz), 
					cast(int)scaleNearestLength(height, scaleVert));
			this.priority = priority;
			this.paletteSel = paletteSel;
			this.scaleVert = scaleVert;
			this.scaleHoriz = scaleHoriz;
			slice = Box(0,0,sprite.width,sprite.height);
			if (typeid(sprite) is typeid(Bitmap2Bit)) {
				bmpType = BitmapTypes.Bmp2Bit;
				this.paletteSh = paletteSh ? paletteSh : 2;
				pixelData = (cast(Bitmap2Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				this.paletteSh = paletteSh ? paletteSh : 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				this.paletteSh = paletteSh ? paletteSh : 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		/**
		 * Resets the slice to its original position.
		 */
		void resetSlice() pure @nogc @safe nothrow {
			slice.left = 0;
			slice.top = 0;
			slice.right = position.width - 1;
			slice.bottom = position.height - 1;
		}
		/**
		 * Replaces the sprite with a new one.
		 * If the sizes are mismatching, the top-left coordinates are left as is, but the slicing is reset.
		 */
		void replaceSprite(ABitmap sprite) @trusted pure nothrow {
			//this.sprite = sprite;
			//palette = sprite.getPalettePtr();
			if(this.width != sprite.width || this.height != sprite.height){
				this.width = sprite.width;
				this.height = sprite.height;
				position.right = position.left + cast(int)scaleNearestLength(width, scaleHoriz);
				position.bottom = position.top + cast(int)scaleNearestLength(height, scaleVert);
				resetSlice();
			}
			if (typeid(sprite) is typeid(Bitmap2Bit)) {
				bmpType = BitmapTypes.Bmp2Bit;
				//paletteSh = 2;
				pixelData = (cast(Bitmap2Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap4Bit)) {
				bmpType = BitmapTypes.Bmp4Bit;
				//paletteSh = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap8Bit)) {
				bmpType = BitmapTypes.Bmp8Bit;
				//paletteSh = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap16Bit)) {
				bmpType = BitmapTypes.Bmp16Bit;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			} else if (typeid(sprite) is typeid(Bitmap32Bit)) {
				bmpType = BitmapTypes.Bmp32Bit;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		@nogc int opCmp(const DisplayListItem d) const pure @safe nothrow {
			return priority - d.priority;
		}
		@nogc bool opEquals(const DisplayListItem d) const pure @safe nothrow {
			return priority == d.priority;
		}
		@nogc int opCmp(const int pri) const pure @safe nothrow {
			return priority - pri;
		}
		@nogc bool opEquals(const int pri) const pure @safe nothrow {
			return priority == pri;
		}
		
		string toString() const {
			import std.conv : to;
			return "{Position: " ~ position.toString ~ ";\nDisplayed portion: " ~ slice.toString ~";\nPriority: " ~
				to!string(priority) ~ "; PixelData: " ~ to!string(pixelData) ~ 
				"; PaletteSel: " ~ to!string(paletteSel) ~ "; bmpType: " ~ to!string(bmpType) ~ "}";
		}
	}
	//alias DisplayList = TreeMap!(int, DisplayListItem);
	alias DisplayList = SortedList!(DisplayListItem, "a < b", false);
	protected DisplayList		allSprites;			///All sprites of this layer
	//protected OnScreenList		displayedSprites;	///Sprites that are being displayed
	protected Color[2048]		src;				///Local buffer for scaling


	protected GLShader defaultShader;
	protected TextureEntry[] gl_materials;
	protected uint gl_vertexArray, gl_vertexBuffer, gl_vertexIndices;
	protected Material[] materialList;
	protected DisplayListItem_Sprt[] displayList_sprt;
	protected DisplayListItem_GL gl_RenderOut;
	protected PolygonIndices[2] gl_PlIndices = [PolygonIndices(0, 1, 2), PolygonIndices(1, 3, 2)];
	//size_t[8] prevSize;
	///Default ctor DEPRECATED since OpenGL move
	public this(RenderingMode renderMode = RenderingMode.AlphaBlend) nothrow @safe {
		setRenderingMode(renderMode);
	}
	public this(GLShader defaultShader) @trusted @nogc nothrow {
		this.defaultShader = defaultShader;
		glGenVertexArrays(1, &gl_vertexArray);
		glGenBuffers(1, &gl_vertexBuffer);
		glGenBuffers(1, &gl_vertexIndices);
	}

	~this() {
		import bindbc.opengl;
		for (size_t i ; i < gl_materials.length ; i++) {
			glDeleteTextures(1, &gl_materials[i].glTextureID);
		}
		gl_materials.nogc_free();
		materialList.nogc_free();
		displayList_sprt.nogc_free();
	}


	protected struct Material {
		int materialID;
		uint pageID;
		ushort width;
		ushort height;
		float left;
		float top;
		float right;
		float bottom;
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			if (materialID < rhs) return -1;
			else if (materialID == rhs) return 0;
			else return 1;
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return materialID == rhs;
		}
		int opCmp(const ref Material rhs) @nogc @safe pure nothrow const {
			if (materialID < rhs.materialID) return -1;
			else if (materialID == rhs.materialID) return 0;
			else return 1;
		}
		bool opEquals(const ref Material rhs) @nogc @safe pure nothrow const {
			return materialID == rhs.materialID;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return materialID;
		}
	}
	protected struct TextureEntry {
		int id;
		uint glTextureID;
		ushort width;
		ushort height;
		ubyte paletteSh;
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			if (id < rhs) return -1;
			else if (id == rhs) return 0;
			else return 1;
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return id == rhs;
		}
		int opCmp(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			if (id < rhs.id) return -1;
			else if (id == rhs.id) return 0;
			else return 1;
		}
		bool opEquals(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			return id == rhs.id;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return id;
		}
	}
	protected struct DisplayListItem_GL {
		Vertex		ul;
		Vertex		ur;
		Vertex		ll;
		Vertex		lr;
	}
	protected @PPECFG_Memfix struct DisplayListItem_Sprt {
		int spriteID;
		int materialID;
		Quad position;
		float[4] slice;
		ushort palSel;
		ubyte palSh;
		ubyte pri;
		GLShader programID;
		///Contains attributes associated with each corner of the sprite
		///Order: upper-left ; upper-right ; lower-left ; lower-right
		GraphicsAttrExt[4] attr;
		this (int spriteID, int materialID, Quad position, float[4] slice, ushort palSel, ubyte palSh, ubyte pri,
				GLShader programID, GraphicsAttrExt[4] attr) @nogc @safe nothrow {
			this.spriteID = spriteID;
			this.materialID = materialID;
			this.position = position;
			this.slice = slice;
			this.palSel = palSel;
			this.palSh = palSh;
			this.pri = pri;
			this.programID = programID;
			this.attr = attr;
		}
		this (return ref scope DisplayListItem_Sprt rhs) @nogc @safe nothrow {
			this.spriteID = rhs.spriteID;
			this.materialID = rhs.materialID;
			this.position = rhs.position;
			this.slice = rhs.slice;
			this.palSel = rhs.palSel;
			this.palSh = rhs.palSh;
			this.pri = rhs.pri;
			this.programID = rhs.programID;
			this.attr = rhs.attr;
		}
		int opCmp(int rhs) @nogc @safe pure nothrow const {
			if (spriteID < rhs) return -1;
			else if (spriteID == rhs) return 0;
			else return 1;
		}
		bool opEquals(int rhs) @nogc @safe pure nothrow const {
			return spriteID == rhs;
		}
		int opCmp(const ref DisplayListItem_Sprt rhs) @nogc @safe pure nothrow const {
			if (spriteID < rhs.spriteID) return -1;
			else if (spriteID == rhs.spriteID) return 0;
			else return 1;
		}
		bool opEquals(const ref DisplayListItem_Sprt rhs) @nogc @safe pure nothrow const {
			return spriteID == rhs.spriteID;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return spriteID;
		}
	}

	/**
	 * Creates a sprite material for this layer.
	 * Params:
	 *   id = desired ID of the sprite material. Note that when updating a previously used one, sizes won't be updated for any displayed sprites.
	 *   page = identifier number of the sprite sheet being used.
	 *   area = the area on the sprite sheet that should be used as the source of the sprite material.
	 * Returns: Zero on success, or a specific error code
	 */
	public int createSpriteMaterial(int id, int page, Box area) @safe @nogc nothrow {
		TextureEntry te = gl_materials.searchBy(page);
		const double xStep = 1.0 / (te.width - 1), yStep = 1.0 / (te.height - 1);
		materialList.orderedInsert(Material(id, te.glTextureID, cast(ushort)area.width, cast(ushort)area.height,
				area.left * xStep, 1.0 - (area.top * yStep), area.right * xStep, 1.0 - (area.bottom * yStep)));
		return 0;
	}
	/**
	 * Removes sprite material designated by `id`.
	 */
	public void removeSpriteMaterial(int id) @safe @nogc nothrow {
		sizediff_t index = materialList.searchByI(id);
		if (index != -1) materialList.nogc_remove(id);
	}
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
	public Quad addSprite(int sprt, int n, Quad position, ushort paletteSel = 0, ubyte paletteSh = 0,
			ubyte alpha = ubyte.max, GLShader shaderID = GLShader(0))
			@trusted nothrow {
		import numem : nu_fatal;
		if (shaderID == 0) shaderID = defaultShader;
		GraphicsAttrExt gae = GraphicsAttrExt(0,0,0,alpha,0,0);
		if (!paletteSh) {
			paletteSh = 8;
			//paletteSh = gl_materials.searchBy(materialList.searchBy(sprt).pageID).paletteSh;
		}
		try {
			displayList_sprt.orderedInsert(DisplayListItem_Sprt(n, sprt, position, [0.0, 0.0, 0.0, 0.0], paletteSel, paletteSh,
					0, shaderID, [gae, gae, gae, gae]));
		} catch (NuException e) {
			try {
				e.free;
				return Quad.init;
			} catch (Exception e) {
				nu_fatal("Failing while failing!");
			}
		} catch (Exception e) {
			nu_fatal("Unknown error!");
		}
		return position;
	}
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
	public Quad addSprite(int sprt, int n, Box position, ushort paletteSel = 0, ubyte paletteSh = 0,
			ubyte alpha = ubyte.max, GLShader shaderID = GLShader(0))
			@trusted nothrow {
		return addSprite(sprt, n, Quad(position.cornerUL, position.cornerUR, position.cornerLL, position.cornerLR),
				paletteSel, paletteSh, alpha, shaderID);
	}
	/**
	 * Adds a sprite to the given location.
	 * Params:
	 *   sprt = Material source to be added as a sprite..
	 *   n = Priority ID of the sprite.
	 *   position = Determines where the sprite should be drawn on the layer.
	 *   paletteSel = Palette selector for indexed bitmaps.
	 *   paletteSh = Palette shift amount in bits.
	 *   alpha = Alpha channel for the whole of the sprite.
	 *   shaderID = Shader program identifier, zero for default.
	 */
	public Quad addSprite(int sprt, int n, Point position, ushort paletteSel = 0, ubyte paletteSh = 0,
			ubyte alpha = ubyte.max, GLShader shaderID = GLShader(0))
			@trusted nothrow {
		Material spriteMat = materialList.searchBy(sprt);
		return addSprite(sprt, n, Box.bySize(position.x, position.y, spriteMat.width, spriteMat.height), paletteSel,
				paletteSh, alpha, shaderID);
	}
	/**
	 * Adds a bitmap source to the layer.
	 * Params:
	 *   bitmap = the bitmap to be uploaded as a texture.
	 *   page = page identifier.
	 * Returns: Zero on success, or a specific error code.
	 */
	public override int addBitmapSource(ABitmap bitmap, int page) @nogc nothrow {
		import bindbc.opengl;
		void* pixelData;
		GLuint textureID;
		glGenTextures(1, &textureID);
		glBindTexture(GL_TEXTURE_2D, textureID);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
		ubyte palSh;
		if (typeid(bitmap) is typeid(Bitmap8Bit)) {
			pixelData = (cast(Bitmap8Bit)(bitmap)).getPtr;
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, bitmap.width, bitmap.height, 0, GL_RED, GL_UNSIGNED_BYTE, pixelData);
			palSh = 8;
		} else if (typeid(bitmap) is typeid(Bitmap32Bit)) {
			pixelData = (cast(Bitmap32Bit)(bitmap)).getPtr;
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bitmap.width, bitmap.height, 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8,
					pixelData);
		}
		{
			const ulong errCode = glGetError();
			if (errCode != GL_NO_ERROR) nu_fatal((cast(char*)&errCode)[0..8]);
		}
		if (!pixelData) return -1;
		gl_materials.orderedInsert(TextureEntry(page, textureID, cast(ushort)bitmap.width, cast(ushort)bitmap.height, palSh));
		return 0;
	}
	/**
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
		import bindbc.opengl;
		//Just stream display data to gl_RenderOut for now, we can always optimize it later if there's any options
		//Constants begin
		//Calculate what area is in the display area with scrolling, will be important for checking for offscreen sprites
		const Box displayAreaWS = Box.bySize(sX + offsets[0], sY + offsets[1], sizes[2], sizes[3]);
		__m128d screenSizeRec = _vect([2.0 / (sizes[0] - 1), -2.0 / (sizes[1] - 1)]);	//Screen size reciprocal with vertical invert
		const __m128d OGL_OFFSET = __m128d([-1.0, 1.0]) + screenSizeRec * _vect([offsets[0], offsets[1]]);	//Offset to the top-left corner of the display area
		immutable __m128d LDIR_REC = __m128d([1.0 / short.max, 1.0 / short.max]);
		immutable __m128 COLOR_REC = __m128([1.0 / 127, 1.0 / 127, 1.0 / 127, 1.0 / 255]);
		//Constants end
		//Stack prealloc block begin
		double[8] spriteLoc = void;
		float[16] spriteCl = void;
		//Stack prealloc block end
		//Select palettes
		// glBindTexture(GL_TEXTURE_2D, 0);
		// glBindFramebuffer(GL_FRAMEBUFFER, workpad);
		{
			const ulong errCode = glGetError();
			if (errCode != GL_NO_ERROR) nu_fatal((cast(char*)&errCode)[0..8]);
		}
		glViewport(0, 0, sizes[0], sizes[1]);

		if (flags & CLEAR_Z_BUFFER) glClear(GL_DEPTH_BUFFER_BIT);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, palette);
		if (palNM) {
			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, palNM);
		}
		foreach (ref DisplayListItem_Sprt sprt ; displayList_sprt) {	//Iterate over all sprites within the displaylist
			if (displayAreaWS.isBetween(sprt.position.topLeft) || displayAreaWS.isBetween(sprt.position.topRight) ||
					displayAreaWS.isBetween(sprt.position.bottomLeft) || displayAreaWS.isBetween(sprt.position.bottomRight)) {//Check whether the sprite is on the display area
					//get sprite material
				Material cm = materialList.searchBy(sprt.materialID);
				glBindTexture(GL_TEXTURE_2D, cm.pageID);
				glActiveTexture(GL_TEXTURE0);
				//Calculate and store sprite location on the display area
				spriteLoc = [sprt.position.topLeft.x - (sX - offsets[0]),
						sprt.position.topLeft.y - (sY - offsets[1]),
						sprt.position.topRight.x - (sX - offsets[0]),
						sprt.position.topRight.y - (sY - offsets[1]),
						sprt.position.bottomLeft.x - (sX - offsets[0]),
						sprt.position.bottomLeft.y - (sY - offsets[1]),
						sprt.position.bottomRight.x - (sX - offsets[0]),
						sprt.position.bottomRight.y - (sY - offsets[1])];
				_store2s(&gl_RenderOut.ul.x, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[0]) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.ur.x, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[2]) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.ll.x, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[4]) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.lr.x, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[6]) * screenSizeRec + OGL_OFFSET));
				//calculate and store Z values
				float zF = 0.0; /+= sprt.pri * (1.0 / 31);+/
				gl_RenderOut.ul.z = zF;
				gl_RenderOut.ur.z = zF;
				gl_RenderOut.ll.z = zF;
				gl_RenderOut.lr.z = zF;
				//calculate and store color values
				spriteCl = [sprt.attr[0].r, sprt.attr[0].g, sprt.attr[0].b, sprt.attr[0].a,
						sprt.attr[1].r, sprt.attr[1].g, sprt.attr[1].b, sprt.attr[1].a,
						sprt.attr[2].r, sprt.attr[2].g, sprt.attr[2].b, sprt.attr[2].a,
						sprt.attr[3].r, sprt.attr[3].g, sprt.attr[3].b, sprt.attr[3].a];
				_mm_storeu_ps(&gl_RenderOut.ul.r, _mm_load_ps(&spriteCl[0]) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.ur.r, _mm_load_ps(&spriteCl[4]) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.ll.r, _mm_load_ps(&spriteCl[8]) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.lr.r, _mm_load_ps(&spriteCl[12]) * COLOR_REC);
				//store texture mapping data
				gl_RenderOut.ul.s = cm.left + sprt.slice[0];
				gl_RenderOut.ul.t = cm.top + sprt.slice[1];
				gl_RenderOut.ur.s = cm.right + sprt.slice[2];
				gl_RenderOut.ur.t = cm.top + sprt.slice[1];
				gl_RenderOut.ll.s = cm.left + sprt.slice[0];
				gl_RenderOut.ll.t = cm.bottom + sprt.slice[3];
				gl_RenderOut.lr.s = cm.right+ sprt.slice[2];
				gl_RenderOut.lr.t = cm.bottom + sprt.slice[3];
				//calcolate and store lighting direction data
				spriteLoc = [sprt.attr[0].lX, sprt.attr[0].lY, sprt.attr[1].lX, sprt.attr[1].lY,
						sprt.attr[2].lX, sprt.attr[2].lY, sprt.attr[3].lX, sprt.attr[3].lY];
				_store2s(&gl_RenderOut.ul.lX, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[0]) * LDIR_REC));
				_store2s(&gl_RenderOut.ur.lX, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[2]) * LDIR_REC));
				_store2s(&gl_RenderOut.ll.lX, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[4]) * LDIR_REC));
				_store2s(&gl_RenderOut.lr.lX, _mm_cvtpd_ps(_mm_load_pd(&spriteLoc[6]) * LDIR_REC));
				glUseProgram(sprt.programID);
				glUniform1i(glGetUniformLocation(sprt.programID, "mainTexture"), 0);
				glUniform1i(glGetUniformLocation(sprt.programID, "palette"), 1);
				glUniform1i(glGetUniformLocation(sprt.programID, "paletteMipMap"), 2);
				const colorSelY = sprt.palSel>>(8-sprt.palSh), colorSelX = sprt.palSel&((1<<(8-sprt.palSh))-1);
				glUniform2f(glGetUniformLocation(sprt.programID, "paletteOffset"),colorSelX * (1.0 / 256),colorSelY * (1.0 / 256));
				// glUniform1f(glGetUniformLocation(gl_Program, "palLengthMult"), 1.0 / (9 - sprt.palSh));

				glBindVertexArray(gl_vertexArray);

				glBindBuffer(GL_ARRAY_BUFFER, gl_vertexBuffer);
				glBufferData(GL_ARRAY_BUFFER, DisplayListItem_GL.sizeof, &gl_RenderOut, GL_STATIC_DRAW);

				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_vertexIndices);
				glBufferData(GL_ARRAY_BUFFER, PolygonIndices.sizeof * 2, gl_PlIndices.ptr, GL_STATIC_DRAW);

				glEnableVertexAttribArray(0);
				glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)0);
				glEnableVertexAttribArray(1);
				glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(3 * float.sizeof));
				glEnableVertexAttribArray(2);
				glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(7 * float.sizeof));
				glEnableVertexAttribArray(3);
				glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(9 * float.sizeof));
				glBindVertexArray(gl_vertexArray);
				glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, gl_PlIndices.ptr);
			}
		}
		glClearColor(0.1f, 0.5f, 0.1f, 1.0f);
	}
	///Sets the overscan amount, on which some effects are dependent on.
	// public abstract void setOverscanAmount(float valH, float valV);

	/**
	 * Checks all sprites for whether they're on screen or not.
	 * Called every time the layer is being scrolled.
	 */
	public void checkAllSprites() @safe nothrow {
		foreach (key; allSprites) {
			checkSprite(key);
		}
	}
	/**
	 * Checks whether a sprite would be displayed on the screen, then updates the display list.
	 * Returns true if it's on screen.
	 */
	public bool checkSprite(int n) @safe nothrow {
		return checkSprite(allSprites[n]);
	}
	///Ditto.
	protected bool checkSprite(DisplayListItem sprt) @safe nothrow {
		//assert(sprt.bmpType != BitmapTypes.Undefined && sprt.pixelData, "DisplayList error!");
		if(sprt.slice.width && sprt.slice.height 
				&& (sprt.position.right > sX && sprt.position.bottom > sY && 
				sprt.position.left < sX + rasterX && sprt.position.top < sY + rasterY)) {
			//displayedSprites.put(sprt.priority);
			return true;
		} else {
			//displayedSprites.removeByElem(sprt.priority);
			return false;
		}
	}
	/**
	 * Searches the DisplayListItem by priority and returns it.
	 * Can be used for external use without any safety issues.
	 */
	public DisplayListItem getDisplayListItem(int n) @nogc pure @trusted nothrow {
		return allSprites[n];
	}
	/*
	 * Searches the DisplayListItem by priority and returns it.
	 * Intended for internal use, as it returns it as a reference value.
	 
	protected final DisplayListItem* getDisplayListItem_internal(int n) @nogc pure @safe nothrow {
		return allSprites.searchByPtr(n);
	}*/
	/+override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
	}+/
	///Returns the displayed portion of the sprite.
	public Coordinate getSlice(int n) @nogc pure @trusted nothrow {
		return getDisplayListItem(n).slice;
	}
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns Coordinate.init.
	public Coordinate setSlice(int n, Coordinate slice) @trusted nothrow {
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(sprt) {
			sprt.slice = slice;
			checkSprite(*sprt);
			return sprt.slice;
		} else {
			return Coordinate.init;
		}
	}
	///Returns the selected paletteID of the sprite.
	public ushort getPaletteID(int n) @nogc pure @trusted nothrow {
		return allSprites.searchBy(n).paletteSel;
	}
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen during 
	public ushort setPaletteID(int n, ushort paletteID) @nogc pure @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.paletteSel = paletteID;
	}
	/** 
	 * Returns the sprite rendering function.
	 * Params:
	 *   n = Sprite priority ID.
	 */
	public RenderFunc getSpriteRenderingFunc(int n) @nogc @trusted pure nothrow {
		return allSprites[n].renderFunc;
	}
	/** 
	 * Sets the sprite's rendering function from a predefined ones.
	 * Params:
	 *   n = Sprite priority ID.
	 *   mode = The rendering mode. (init for layer default)
	 * Returns: The new rendering function.
	 */
	public RenderFunc setSpriteRenderingMode(int n, RenderingMode mode) @nogc @trusted pure nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return null;
		return item.renderFunc = mode == RenderingMode.init ? mainRenderingFunction : getRenderingFunc(mode);
	}
	/** 
	 * Sets the sprite's rendering function. Can be a custom one.
	 * Params:
	 *   n = Sprite priority ID.
	 *   mode = The rendering mode. (init for layer default)
	 * Returns: The new rendering function.
	 */
	public RenderFunc setSpriteRenderingFunc(int n, RenderFunc func) @nogc @trusted pure nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return null;
		return item.renderFunc = func;
	}
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
			@safe nothrow {
		DisplayListItem d = DisplayListItem(x, y, sprt, n, paletteSel, paletteSh, alpha, scaleHoriz, scaleVert);
		if (renderMode == RenderingMode.init)
			d.renderFunc = mainRenderingFunction;
		else
			d.renderFunc = getRenderingFunc(renderMode);
		//synchronized{
		allSprites.put(d);
		//checkSprite(d);
		//}
		return d.position;
	}
	/**
	 * Adds a sprite to the layer.
	 */
	/+public void addSprite(ABitmap s, int n, Box c, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(c, s, n, paletteSel, scaleHoriz, scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}+/
	///Ditto
	/+public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, 
				int scaleVert = 1024) @safe nothrow {
		DisplayListItem d = DisplayListItem(Box.bySize(x, y, cast(int)scaleNearestLength(s.width, scaleHoriz), 
					cast(int)scaleNearestLength(s.height, scaleVert)), s, n, paletteSel, scaleHoriz, 
				scaleVert);
		d.renderFunc = mainRenderingFunction;
		synchronized
			allSprites[n] = d;
		checkSprite(d);
	}+/
	/**
	 * Replaces the bitmap of the given sprite.
	 */
	public void replaceSprite(ABitmap s, int n) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, int x, int y) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
		item.position.move(x, y);
	}
	///Ditto with move
	public void replaceSprite(ABitmap s, int n, Coordinate c) @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return;
		item.replaceSprite(s);
		item.position = c;
	}
	/**
	 * Removes a sprite from both displaylists by priority.
	 */
	public void removeSprite(int n) @safe nothrow {
		allSprites.removeBy(n);
	}
	///Clears all sprite from the layer.
	public void clear() @safe nothrow {
		allSprites = DisplayList.init;
	}
	/**
	 * Moves a sprite to the given position.
	 */
	public Quad moveSprite(int n, int x, int y) @nogc @trusted nothrow {
		const sizediff_t pos = displayList_sprt.searchByI(n);
		if (pos == -1) return Quad.init;
		displayList_sprt[pos].position.move(x, y);
		return displayList_sprt[pos].position;
	}
	/**
	 * Moves a sprite by the given amount.
	 */
	public Quad relMoveSprite(int n, int x, int y) @nogc @trusted nothrow {
		const sizediff_t pos = displayList_sprt.searchByI(n);
		if (pos == -1) return Quad.init;
		displayList_sprt[pos].position.relMove(x, y);
		return displayList_sprt[pos].position;
		//checkSprite(*sprt);
	}
	/* ///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		item.renderFunc = getRenderingFunc(mode);
	} */
	public Quad getSpriteCoordinate(int n) @nogc @trusted nothrow {
		const sizediff_t pos = displayList_sprt.searchByI(n);
		if (pos == -1) return Quad.init;
		return displayList_sprt[pos].position;
	}
	///Scales sprite horizontally. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteHoriz(int n, int hScl) @trusted nothrow { 
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(!sprt) return -2;
		else if(!hScl) return -1;
		else {
			sprt.scaleHoriz = hScl;
			const int newWidth = cast(int)scaleNearestLength(sprt.width, hScl);
			sprt.slice.right = newWidth;
			sprt.position.right = sprt.position.left + newWidth;
			checkSprite(*sprt);
			return newWidth;
		}
	}
	///Scales sprite vertically. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public int scaleSpriteVert(int n, int vScl) @trusted nothrow {
		DisplayListItem* sprt = allSprites.searchByPtr(n);
		if(!sprt) return -2;
		else if(!vScl) return -1;
		else {
			sprt.scaleVert = vScl;
			const int newHeight = cast(int)scaleNearestLength(sprt.height, vScl);
			sprt.slice.bottom = newHeight;
			sprt.position.bottom = sprt.position.top + newHeight;
			checkSprite(*sprt);
			return newHeight;
		}
	}
	///Gets the sprite's current horizontal scale value
	public int getScaleSpriteHoriz(int n) @nogc @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.scaleHoriz;
	}
	///Gets the sprite's current vertical scale value
	public int getScaleSpriteVert(int n) @nogc @trusted nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		return item.scaleVert;
	}
	public override LayerType getLayerType() @nogc @safe pure nothrow const {
		return LayerType.Sprite;
	}
	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette) {
		/*
		 * BUG 1: If sprite is wider than 2048 pixels, it'll cause issues (mostly memory leaks) due to a hack. (Fixed!)
		 * BUG 2: Obscuring the top part of a sprite when scaleVert is not 1024 will cause glitches. (Fixed!!!)
		 * TO DO: Replace AVL tree with an automatically sorting array with keying abilities.
		 */
		foreach (i ; allSprites) {
			if(!(i.slice.width && i.slice.height 
					&& (i.position.right > sX && i.position.bottom > sY && 
					i.position.left < sX + rasterX && i.position.top < sY + rasterY))) continue;
			const int left = i.position.left + i.slice.left;
			const int top = i.position.top + i.slice.top;
			const int right = i.position.left + i.slice.right;
			const int bottom = i.position.top + i.slice.bottom;
			int offsetXA = sX > left ? sX - left : 0;//Left hand side offset, zero if not obscured
			const int offsetXB = sX + rasterX < right ? right - (sX + rasterX) : 0; //Right hand side offset, zero if not obscured
			const int offsetYA = sY > top ? sY - top : 0;		//top offset of sprite, zero if not obscured
			const int offsetYB = sY + rasterY < bottom ? bottom - (sY + rasterY) + 1 : 1;	//bottom offset of sprite, zero if not obscured
			const int sizeX = i.slice.width();		//total displayed width after slicing
			const int offsetX = left - sX;
			const int length = sizeX - offsetXA - offsetXB - 1; //total displayed width after considering screen borders
			const int offsetY = sY < top ? (top-sY)*pitch : 0;	//used if top portion of the sprite is off-screen
			const int scaleVertAbs = i.scaleVert * (i.scaleVert < 0 ? -1 : 1);	//absolute value of vertical scaling, used in various calculations
			const int scaleHorizAbs = i.scaleHoriz * (i.scaleHoriz < 0 ? -1 : 1);
			const int offsetYA0 = (offsetYA * scaleVertAbs)>>>10;		//amount of skipped lines in the bitmap source
			const int sizeXOffset = i.width * (i.scaleVert < 0 ? -1 : 1);
			int offsetTarget;													//the target fractional lines
			int offset = (offsetYA * scaleVertAbs) & 1023;						//the current amount of fractional lines, also contains the fractional offset bias by defauls
			//const size_t p0offset = (i.scaleHoriz > 0 ? offsetXA : offsetXB); //determines offset based on mirroring
			//const int scalelength = i.position.width < 2048 ? i.width : 2048;	//limit width to 2048, the minimum required for this scaling method to work
			void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
			final switch (i.bmpType) with (BitmapTypes) {
				case Bmp2Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>2);
					const size_t _pitch = i.width>>>2;
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						/+horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, offsetXA & 1,
								i.scaleHoriz);+/
						horizontalScaleNearestAndCLU(QuadArray(p0[0.._pitch], i.width), src.ptr, palette + (i.paletteSel<<i.paletteSh), 
								length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += _pitch;
					}
					break;
				case Bmp4Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>1);
					const size_t _pitch = i.width>>>1;
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						/+horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, offsetXA & 1,
								i.scaleHoriz);+/
						horizontalScaleNearestAndCLU(NibbleArray(p0[0.._pitch], i.width), src.ptr, palette + (i.paletteSel<<i.paletteSh), 
								length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += _pitch;
					}
					break;
				case Bmp8Bit:
					ubyte* p0 = cast(ubyte*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						//horizontalScaleNearestAndCLU(p0, src.ptr, palette + (i.paletteSel<<i.paletteSh), scalelength, i.scaleHoriz);
						horizontalScaleNearestAndCLU(p0[0..i.width], src.ptr, palette + (i.paletteSel<<i.paletteSh), length, i.scaleHoriz,
								offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp16Bit:
					ushort* p0 = cast(ushort*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						//horizontalScaleNearestAndCLU(p0, src.ptr, palette, scalelength, i.scaleHoriz);
						horizontalScaleNearestAndCLU(p0[0..i.width], src.ptr, palette, length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB ; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					break;
				case Bmp32Bit:
					Color* p0 = cast(Color*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
					for (int y = offsetYA ; y < i.slice.height - offsetYB ; ) {
						horizontalScaleNearest(p0[0..i.width], src, length, i.scaleHoriz, offsetXA * scaleHorizAbs);
						offsetTarget += 1024;
						for (; offset < offsetTarget && y < i.slice.height - offsetYB; offset += scaleVertAbs) {
							y++;
							i.renderFunc(cast(uint*)src.ptr, cast(uint*)dest, length, i.masterAlpha);
							dest += pitch;
						}
						p0 += sizeXOffset;
					}
					//}
					break;
				case Undefined, Bmp1Bit, Planar:
					break;
			}

			//}
		}
		//foreach(int threadOffset; threads.parallel)
			//free(src[threadOffset]);
	}
	///Absolute scrolling.
	public override void scroll(int x, int y) @safe nothrow {
		sX = x;
		sY = y;
		//checkAllSprites;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public override void relScroll(int x, int y) @safe nothrow {
		sX += x;
		sY += y;
		//checkAllSprites;
	}
}
