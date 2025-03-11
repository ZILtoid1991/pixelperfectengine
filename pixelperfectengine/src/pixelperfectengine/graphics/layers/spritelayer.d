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
	 * Defines a singular sprite material for the current layer instance to be used.
	 */
	protected struct Material {
		int materialID;	/// The material ID, which is also used for ordering.
		uint pageID;	/// Identifies which texture is being used for the material.
		ushort width;	/// Defines the sprite's width
		ushort height;	/// Defines the sprite's height
		float left;		/// Defines the left-edge of the sprite on the texture
		float top;		/// Defines the top-edge of the sprite on the texture
		float right;	/// Defines the right-edge of the sprite on the texture
		float bottom;	/// Defines the bottom-edge of the sprite on the texture
		/// Used for sorting and accessing
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			return (materialID > rhs) - (materialID < rhs);
		}
		/// Used for sorting and accessing
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return materialID == rhs;
		}
		/// Used for sorting and accessing
		int opCmp(const ref Material rhs) @nogc @safe pure nothrow const {
			return (materialID > rhs.materialID) - (materialID < rhs.materialID);
		}
		/// Used for sorting and accessing
		bool opEquals(const ref Material rhs) @nogc @safe pure nothrow const {
			return materialID == rhs.materialID;
		}
		/// Used to shut up DLangServer
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
			return (id > rhs) - (id < rhs);
			// if (id > rhs) return -1;
			// else if (id == rhs) return 0;
			// else return 1;
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return id == rhs;
		}
		int opCmp(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			return (id > rhs.id) - (id < rhs.id);
			// if (id > rhs.id) return -1;
			// else if (id == rhs.id) return 0;
			// else return 1;
		}
		bool opEquals(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			return id == rhs.id;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return id;
		}
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
			return (spriteID > rhs) - (spriteID < rhs);
		}
		bool opEquals(int rhs) @nogc @safe pure nothrow const {
			return spriteID == rhs;
		}
		int opCmp(const ref DisplayListItem_Sprt rhs) @nogc @safe pure nothrow const {
			return (spriteID > rhs.spriteID) - (spriteID < rhs.spriteID);
		}
		bool opEquals(const ref DisplayListItem_Sprt rhs) @nogc @safe pure nothrow const {
			return spriteID == rhs.spriteID;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return spriteID;
		}
	}

	/// The default shader to be used on sprites with color lookup.
	protected GLShader defaultShader;
	/// The default shader to be used on sprites without color lookup.
	protected GLShader defaultShader32;
	/// Contains all textures used for this layer.
	protected TextureEntry[] gl_materials;
	/// Used for drawing the polygons to the screen.
	protected uint gl_vertexArray, gl_vertexBuffer, gl_vertexIndices;
	/// Contains all material data associated with the layer.
	/// See struct `Material` for more information.
	protected Material[] materialList;
	/// Contains the displayed sprites in order of display.
	/// See struct `DisplayListItem_Sprt` for more information.
	protected DisplayListItem_Sprt[] displayList_sprt;
	/// Contains the data needed to render the currently displayed sprite.
	protected DisplayListItem_GL gl_RenderOut;
	/// Contains the poligon indices for rendering, likely to be kept as a constant
	protected PolygonIndices[2] gl_PlIndices;// = [PolygonIndices(0, 1, 2), PolygonIndices(1, 3, 2)];
	//size_t[8] prevSize;
	
	public this(GLShader defaultShader, GLShader defaultShader32) @trusted @nogc nothrow {
		this.defaultShader = defaultShader;
		this.defaultShader32 = defaultShader32;
		glGenVertexArrays(1, &gl_vertexArray);
		glGenBuffers(1, &gl_vertexBuffer);
		glGenBuffers(1, &gl_vertexIndices);
		gl_PlIndices = [PolygonIndices(0, 1, 2), PolygonIndices(1, 3, 2)];
	}
	/// Manually finalizes any non-static data arrays.
	~this() {
		import bindbc.opengl;
		for (size_t i ; i < gl_materials.length ; i++) {
			glDeleteTextures(1, &gl_materials[i].glTextureID);
		}
		gl_materials.nogc_free();
		materialList.nogc_free();
		displayList_sprt.nogc_free();
	}
	
	
	
	
	protected struct DisplayListItem_GL {
		Vertex		ul;
		Vertex		ur;
		Vertex		ll;
		Vertex		lr;
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
				area.left * xStep, area.top * yStep, area.right * xStep, area.bottom * yStep));
		return 0;
	}
	public int createSpriteMaterial(int id, int page) @safe @nogc nothrow {
		TextureEntry te = gl_materials.searchBy(page);
		materialList.orderedInsert(Material(id, te.glTextureID, te.width, te.height,
				0.0, 0.0, 1.0, 1.0));
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
		GraphicsAttrExt gae = GraphicsAttrExt(128,128,128,alpha,0,0);
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
		// BUGFIX: without these, sprites will be look wobbly
		position.right += 1;
		position.bottom += 1;
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
	 * Adds a bitmap source to the layer. Overwites existing textures without upgrading material data.
	 * Params:
	 *   bitmap = the bitmap to be uploaded as a texture.
	 *   page = page identifier.
	 * Returns: Zero on success, or a specific error code.
	 */
	public override int addBitmapSource(ABitmap bitmap, int page, ubyte palSh = 8) @trusted @nogc nothrow {
		import bindbc.opengl;
		const sizediff_t exists = gl_materials.searchByI(page);
		if (exists != -1) glDeleteTextures(1, &gl_materials[exists].glTextureID);
		void* pixelData;
		GLuint textureID;
		glGenTextures(1, &textureID);
		glBindTexture(GL_TEXTURE_2D, textureID);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
		if (typeid(bitmap) is typeid(Bitmap8Bit)) {
			pixelData = (cast(Bitmap8Bit)(bitmap)).getPtr;
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, bitmap.width, bitmap.height, 0, GL_RED, GL_UNSIGNED_BYTE, pixelData);
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
		if (exists == -1) gl_materials.orderedInsert
			(TextureEntry(page, textureID, cast(ushort)bitmap.width, cast(ushort)bitmap.height, palSh));
		else gl_materials[exists] = TextureEntry(page, textureID, cast(ushort)bitmap.width, cast(ushort)bitmap.height, palSh);
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
		//BUG 1: Some wobbliness in graphics output, likely some calculation errors adding up. (FIXED!)
		//Constants begin
		//Calculate what area is in the display area with scrolling, will be important for checking for offscreen sprites
		const Box displayAreaWS = Box.bySize(sX + offsets[0], sY + offsets[1], sizes[2], sizes[3]);
		__m128d screenSizeRec = _vect([2.0 / sizes[0], -2.0 / sizes[1]]);	//Screen size reciprocal with vertical invert
		const __m128d OGL_OFFSET = __m128d([-1.0, 1.0]) + screenSizeRec * _vect([offsets[0], offsets[1]]);	//Offset to the top-left corner of the display area
		immutable __m128d LDIR_REC = __m128d([1.0 / short.max, 1.0 / short.max]);
		immutable __m128 COLOR_REC = __m128([1.0 / 255, 1.0 / 255, 1.0 / 255, 1.0 / 255]);
		const __m128i scrollVec = _vect([sX, sY, 0, 0]), offsetsVec = _mm_loadu_si64(offsets.ptr);
		//Constants end
		//Stack prealloc block begin

		//Stack prealloc block end
		//Select palettes
		// glBindTexture(GL_TEXTURE_2D, 0);
		// glBindFramebuffer(GL_FRAMEBUFFER, workpad);

		// glViewport(0, 0, sizes[0], sizes[1]);

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
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, cm.pageID);
				//Calculate and store sprite location on the display area
				// spriteLoc = [sprt.position.topLeft.x - (sX - offsets[0]),
						// sprt.position.topLeft.y - (sY - offsets[1]),
						// sprt.position.topRight.x - (sX - offsets[0]),
						// sprt.position.topRight.y - (sY - offsets[1]),
						// sprt.position.bottomLeft.x - (sX - offsets[0]),
						// sprt.position.bottomLeft.y - (sY - offsets[1]),
						// sprt.position.bottomRight.x - (sX - offsets[0]),
						// sprt.position.bottomRight.y - (sY - offsets[1])];
				_store2s(&gl_RenderOut.ul.x, _mm_cvtpd_ps(_mm_cvtepi32_pd(_mm_loadu_si64(&sprt.position.topLeft) -
						(scrollVec - offsetsVec)) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.ur.x, _mm_cvtpd_ps(_mm_cvtepi32_pd(_mm_loadu_si64(&sprt.position.topRight) -
						(scrollVec - offsetsVec)) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.ll.x, _mm_cvtpd_ps(_mm_cvtepi32_pd(_mm_loadu_si64(&sprt.position.bottomLeft) -
						(scrollVec - offsetsVec)) * screenSizeRec + OGL_OFFSET));
				_store2s(&gl_RenderOut.lr.x, _mm_cvtpd_ps(_mm_cvtepi32_pd(_mm_loadu_si64(&sprt.position.bottomRight) -
						(scrollVec - offsetsVec)) * screenSizeRec + OGL_OFFSET));
				//calculate and store Z values
				float zF = sprt.pri * (1.0 / 255);
				gl_RenderOut.ul.z = zF;
				gl_RenderOut.ur.z = zF;
				gl_RenderOut.ll.z = zF;
				gl_RenderOut.lr.z = zF;
				//calculate and store color values
				// spriteCl = [sprt.attr[0].r, sprt.attr[0].g, sprt.attr[0].b, sprt.attr[0].a,
						// sprt.attr[1].r, sprt.attr[1].g, sprt.attr[1].b, sprt.attr[1].a,
						// sprt.attr[2].r, sprt.attr[2].g, sprt.attr[2].b, sprt.attr[2].a,
						// sprt.attr[3].r, sprt.attr[3].g, sprt.attr[3].b, sprt.attr[3].a];
				_mm_storeu_ps(&gl_RenderOut.ul.r, _conv4ubytes(&sprt.attr[0].r) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.ur.r, _conv4ubytes(&sprt.attr[1].r) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.ll.r, _conv4ubytes(&sprt.attr[2].r) * COLOR_REC);
				_mm_storeu_ps(&gl_RenderOut.lr.r, _conv4ubytes(&sprt.attr[3].r) * COLOR_REC);
				//store texture mapping data
				__m128 sprtSliceCalc = _mm_loadu_ps(&cm.left) + _mm_loadu_ps(&sprt.slice[0]);
				gl_RenderOut.ul.s = sprtSliceCalc[0];
				gl_RenderOut.ul.t = sprtSliceCalc[1];
				gl_RenderOut.ur.s = sprtSliceCalc[2];
				gl_RenderOut.ur.t = sprtSliceCalc[1];
				gl_RenderOut.ll.s = sprtSliceCalc[0];
				gl_RenderOut.ll.t = sprtSliceCalc[3];
				gl_RenderOut.lr.s = sprtSliceCalc[2];
				gl_RenderOut.lr.t = sprtSliceCalc[3];
				//calcolate and store lighting direction data
				// spriteLoc = [sprt.attr[0].lX, sprt.attr[0].lY, sprt.attr[1].lX, sprt.attr[1].lY,
				// 		sprt.attr[2].lX, sprt.attr[2].lY, sprt.attr[3].lX, sprt.attr[3].lY];

				_store2s(&gl_RenderOut.ul.lX, _mm_cvtpd_ps(_conv2shorts(&sprt.attr[0].lX) * LDIR_REC));
				_store2s(&gl_RenderOut.ur.lX, _mm_cvtpd_ps(_conv2shorts(&sprt.attr[1].lX) * LDIR_REC));
				_store2s(&gl_RenderOut.ll.lX, _mm_cvtpd_ps(_conv2shorts(&sprt.attr[2].lX) * LDIR_REC));
				_store2s(&gl_RenderOut.lr.lX, _mm_cvtpd_ps(_conv2shorts(&sprt.attr[3].lX) * LDIR_REC));
				glUseProgram(sprt.programID);
				glUniform1i(glGetUniformLocation(sprt.programID, "mainTexture"), 0);
				glUniform1i(glGetUniformLocation(sprt.programID, "palette"), 1);
				glUniform1i(glGetUniformLocation(sprt.programID, "paletteMipMap"), 2);
				const colorSelY = sprt.palSel>>(8-sprt.palSh), colorSelX = sprt.palSel&((1<<(8-sprt.palSh))-1);
				glUniform2f(glGetUniformLocation(sprt.programID, "paletteOffset"),colorSelX * (1.0 / 256),colorSelY * (1.0 / 256));
				// glUniform1f(glGetUniformLocation(gl_Program, "palLengthMult"), 1.0 / (9 - sprt.palSh));

				glBindVertexArray(gl_vertexArray);

				glBindBuffer(GL_ARRAY_BUFFER, gl_vertexBuffer);
				glBufferData(GL_ARRAY_BUFFER, DisplayListItem_GL.sizeof, &gl_RenderOut, GL_STREAM_DRAW);

				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_vertexIndices);
				glBufferData(GL_ELEMENT_ARRAY_BUFFER, 4 * 6, gl_PlIndices.ptr, GL_STREAM_DRAW);

				glEnableVertexAttribArray(0);
				glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)0);
				glEnableVertexAttribArray(1);
				glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(3 * float.sizeof));
				glEnableVertexAttribArray(2);
				glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(7 * float.sizeof));
				glEnableVertexAttribArray(3);
				glVertexAttribPointer(3, 2, GL_FLOAT, GL_FALSE, cast(int)(11 * float.sizeof), cast(void*)(9 * float.sizeof));
				glBindVertexArray(gl_vertexArray);
				glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);
			}
		}
		// glClearColor(0.1f, 0.5f, 0.1f, 1.0f);
	}
	///Sets the overscan amount, on which some effects are dependent on.
	// public abstract void setOverscanAmount(float valH, float valV);
	///Returns the selected paletteID of the sprite.
	public ushort getPaletteID(int n) @nogc @trusted nothrow {
		return displayList_sprt.searchBy(n).palSel;
	}
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen during 
	public ushort setPaletteID(int n, ushort paletteID) @nogc @trusted nothrow {
		sizediff_t index = displayList_sprt.searchByI(n);
		if (index == -1) return 0;
		return displayList_sprt[n].palSel;
	}
	/**
	 * Removes a sprite from the displaylist by priority.
	 */
	public void removeSprite(int n) @nogc @safe nothrow {
		try {
			const sizediff_t pos = displayList_sprt.searchByI(n);
			if (pos == -1) displayList_sprt.nogc_remove(pos);
		} catch (Exception e) {
			fatal_trusted(e.msg);

		}
	}
	///Clears all sprite from the layer.
	public void clear() @safe nothrow {
		try {
			displayList_sprt.nogc_free();
		} catch (Exception e) {
			fatal_trusted(e.msg);
		}
	}
	/**
	 * Moves a sprite to the given position.
	 */
	public Quad moveSprite(int n, int x, int y) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchByI(n);
		if (i == -1) return Quad.init;
		displayList_sprt[i].position.move(x, y);
		return displayList_sprt[i].position;
	}
	/**
	 * Moves a sprite by the given amount.
	 */
	public Quad relMoveSprite(int n, int x, int y) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchByI(n);
		if (i == -1) return Quad.init;
		displayList_sprt[i].position.relMove(x, y);
		return displayList_sprt[i].position;
		//checkSprite(*sprt);
	}
	public void setSpriteShader(int n, GLShader shader) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchByI(n);
		if (i == -1) return;
		if(shader == 0) displayList_sprt[i].programID = defaultShader;
		else displayList_sprt[i].programID = shader;
	}
	public Quad moveSprite(int n, Box pos, bool hMirror = false, bool vMirror = false) @nogc @safe nothrow {
		pos.right += 1;
		pos.bottom += 1;
		Quad output;
		if (hMirror) {
			output.topRight.x = pos.left;
			output.bottomRight.x = pos.left;
			output.topLeft.x = pos.right;
			output.bottomLeft.x = pos.right;
		} else {
			output.topRight.x = pos.right;
			output.bottomRight.x = pos.right;
			output.topLeft.x = pos.left;
			output.bottomLeft.x = pos.left;
		}
		if (vMirror) {
			output.topRight.y = pos.bottom;
			output.bottomRight.y = pos.top;
			output.topLeft.y = pos.bottom;
			output.bottomLeft.y = pos.top;
		} else {
			output.topRight.y = pos.top;
			output.bottomRight.y = pos.bottom;
			output.topLeft.y = pos.top;
			output.bottomLeft.y = pos.bottom;
		}
		return moveSprite(n, pos);
	}
	public Quad moveSprite(int n, Quad pos) @nogc @trusted nothrow {
		const sizediff_t i = displayList_sprt.searchByI(n);
		if (i == -1) return Quad.init;
		displayList_sprt[i].position = pos;
		return pos;
	}
	/* ///Sets the rendering function for the sprite (defaults to the layer's rendering function)
	public void setSpriteRenderingMode(int n, RenderingMode mode) @safe nothrow {
		DisplayListItem* item = allSprites.searchByPtr(n);
		if (item is null) return 0;
		item.renderFunc = getRenderingFunc(mode);
	} */
	public Quad getSpriteCoordinate(int n) @nogc @trusted nothrow {
		const sizediff_t i = displayList_sprt.searchByI(n);
		if (i == -1) return Quad.init;
		return displayList_sprt[i].position;
	}

	public override LayerType getLayerType() @nogc @safe pure nothrow const {
		return LayerType.Sprite;
	}
	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette) {	//DEPRECATED

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
