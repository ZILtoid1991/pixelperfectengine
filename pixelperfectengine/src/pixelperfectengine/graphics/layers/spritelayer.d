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
 * General-purpose sprite controller and renderer, used for all kinds of sprites, including windowing.
 * Bugs:
 *   It doesn't like non power of two sprites, likely a workaround is needed.
 */
public class SpriteLayer : Layer, ISpriteLayer {
	/**
	 * Defines a singular sprite material for the current layer instance to be used.
	 * Bugs:
	 *   [Severe] Ordering issue when used in an arraymap
	 */
	protected struct Material {
		int materialID;	/// The material ID, which is also used for ordering.
		uint pageID;	/// Identifies which texture is being used for the material.
		ushort left;	/// Defines the left-edge of the sprite on the texture
		ushort top;		/// Defines the top-edge of the sprite on the texture
		ushort right;	/// Defines the right-edge of the sprite on the texture
		ushort bottom;	/// Defines the bottom-edge of the sprite on the texture
		this(int materialID,uint pageID,ushort left,ushort top,ushort right,ushort bottom) @nogc @safe pure nothrow {
			this.materialID = materialID;
			this.pageID = pageID;
			this.left = left;
			this.top = top;
			this.right = right;
			this.bottom = bottom;
		}
		this(int materialID) @nogc @safe pure nothrow {
			this.materialID = materialID;
		}
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
		int width() @nogc @safe pure nothrow const {
			return right - left + 1;
		}
		int height() @nogc @safe pure nothrow const {
			return bottom - top + 1;
		}
	}
	/// Defines a texture item for the layer.
	protected struct TextureEntry {
		int id;				/// Local name identifier
		uint glTextureID;	/// OpenGL texture identifier
		ushort width;		/// width of the texture
		ushort height;		/// height of the texture
		ubyte paletteSh;
		int opCmp(const int rhs) @nogc @safe pure nothrow const {
			return (id > rhs) - (id < rhs);
		}
		bool opEquals(const int rhs) @nogc @safe pure nothrow const {
			return id == rhs;
		}
		int opCmp(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			return (id > rhs.id) - (id < rhs.id);
		}
		bool opEquals(const ref TextureEntry rhs) @nogc @safe pure nothrow const {
			return id == rhs.id;
		}
		size_t toHash() @nogc @safe pure nothrow const {
			return id;
		}
	}
	/// Defines a displaylist item for the layer.
	protected @PPECFG_Memfix struct DisplayListItem_Sprt {
		int spriteID;		/// Sprite identifier
		int materialID;		/// Material identifier, contains the OpenGL texture identifier
		Quad position;		/// Defines the position of the sprite on the 2D plane
		float[4] slice;		/// Defines the position of the material on the texture
		ushort palSel;		/// Selects the palette for the given sprite, see chapter on palettes in manual for more information.
		ubyte palSh;		/// Defines how the palette selection works, see chapter on palettes in manual for more information.
		ubyte pri;			/// Priority value, used for Z buffering.
		GLShader programID;	/// Contains the shader program ID for the sprite.
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
			return (spriteID < rhs) - (spriteID > rhs);
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
	protected OrderedArraySet!(TextureEntry) gl_materials;
	/// Used for drawing the polygons to the screen.
	protected uint gl_vertexArray, gl_vertexBuffer, gl_vertexIndices;
	/// Contains all material data associated with the layer.
	/// See struct `Material` for more information.
	protected OrderedArraySet!Material materialList;
	/// Contains the displayed sprites in order of display.
	/// See struct `DisplayListItem_Sprt` for more information.
	protected OrderedArraySet!DisplayListItem_Sprt displayList_sprt;
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
		gl_materials.free();
		materialList.free();
		displayList_sprt.free();
		glDeleteBuffers(1, &gl_vertexIndices);
		glDeleteBuffers(1, &gl_vertexBuffer);
		glDeleteVertexArrays(1, &gl_vertexArray);
	}
	/**
	 * Defines the verticles used for displaying a sprite.
	 */
	protected struct DisplayListItem_GL {
		SpriteVertex		ul;
		SpriteVertex		ur;
		SpriteVertex		ll;
		SpriteVertex		lr;
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
		materialList.insert(Material(id, te.glTextureID,
				cast(ushort)area.left, cast(ushort)area.top, cast(ushort)area.right, cast(ushort)area.bottom));
		return 0;
	}
	/**
	 * Creates a sprite material for this layer using the whole page area.
	 * Params:
	 *   id = desired ID of the sprite material. Note that when updating a previously used one, sizes won't be updated for any displayed sprites.
	 *   page = identifier number of the sprite sheet being used.
	 * Returns: Zero on success, or a specific error code
	 */
	public int createSpriteMaterial(int id, int page) @safe @nogc nothrow {
		TextureEntry te = gl_materials.searchBy(page);
		materialList.insert(Material(id, te.glTextureID, 0, 0, te.width, te.height));
		return 0;
	}
	/**
	 * Removes sprite material designated by `id`.
	 */
	public void removeSpriteMaterial(int id) @safe @nogc nothrow {
		sizediff_t index = materialList.searchIndexBy(id);
		if (index != -1) materialList.remove(id);
	}
	/**
	 * Adds a sprite to the given location.
	 * Params:
	 *   sprt = Bitmap to be added as a sprite.
	 *   n = Priority ID of the sprite.
	 *   position = Determines where the sprite should be drawn on the layer.
	 *   paletteSel = Palette selector for indexed bitmaps.
	 *   paletteSh = Palette shift amount in bits. Please note that it may affect
	 *   alpha = Alpha channel for the whole of the sprite.
	 *   shaderID = Shader program identifier, zero for default.
	 */
	public Quad addSprite(int sprt, int n, Quad position, ushort paletteSel = 0, ubyte paletteSh = 0,
			ubyte alpha = ubyte.max, GLShader shaderID = GLShader(0))
			@trusted nothrow {
		import numem : nu_fatal;
		GraphicsAttrExt gae = GraphicsAttrExt(128,128,128,alpha,0,0);
		if (!paletteSh) {
			const pageID = materialList.searchBy(sprt).pageID;
			foreach (TextureEntry te ; gl_materials) {
				if (te.glTextureID == pageID) {
					paletteSh = te.paletteSh;
					break;
				}
			}
			if (!paletteSh) paletteSh = 8;
		}
		if (shaderID == 0) {
			if (paletteSh == 32) shaderID = defaultShader32;
			else shaderID = defaultShader;
		}
		try {
			displayList_sprt.insert(DisplayListItem_Sprt(n, sprt, position, [0.0, 0.0, 0.0, 0.0], paletteSel, paletteSh,
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
		// position.right += 1;
		// position.bottom += 1;
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
		const sizediff_t exists = gl_materials.searchIndexBy(page);
		//glDeleteTextures(1, &gl_materials[exists].glTextureID);
		void* pixelData;
		GLuint textureID;
		if (exists != -1) textureID = gl_materials[exists].glTextureID;
		else glGenTextures(1, &textureID);
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

		if (!pixelData) return -1;
		if (exists == -1) {
			gl_materials.insert(TextureEntry(page, textureID, cast(ushort)bitmap.width, cast(ushort)bitmap.height, palSh));
		} else {
			gl_materials[exists] = TextureEntry(page, textureID, cast(ushort)bitmap.width, cast(ushort)bitmap.height, palSh);
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
		const sizediff_t exists = gl_materials.searchIndexBy(page);
		if (exists == -1) return -1;
		if (runDTor) glDeleteTextures(1, &gl_materials[exists].glTextureID);
		gl_materials.remove(exists);
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
		const sizediff_t exists = gl_materials.searchIndexBy(page);
		if (exists != -1) {
			gl_materials.insert(TextureEntry(page));
			return 0;
		}
		return -12;
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
		const __m128i scrollVec = _vect([sX, sY, sX, sY]);
		//Constants end
		//Select palettes
		//if (flags & CLEAR_Z_BUFFER) glClear(GL_DEPTH_BUFFER_BIT);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, palette);
		if (palNM) {
			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, palNM);
		}
		GLuint prevPrg;
		GLuint prevTexture;
		GLint paletteOffset;
		GLint mainTexture;
		foreach_reverse (ref DisplayListItem_Sprt sprt ; displayList_sprt) {	//Iterate over all sprites within the displaylist
			if (displayAreaWS.isBetween(sprt.position.topLeft) || displayAreaWS.isBetween(sprt.position.topRight) ||
					displayAreaWS.isBetween(sprt.position.bottomLeft) || displayAreaWS.isBetween(sprt.position.bottomRight)) {//Check whether the sprite is on the display area
					//get sprite material
				GLuint prg = sprt.programID.shaderID;
				Material cm = materialList.searchBy(sprt.materialID);
				if (prevTexture != cm.pageID){
					prevTexture = cm.pageID;
					glActiveTexture(GL_TEXTURE0);
					glBindTexture(GL_TEXTURE_2D, cm.pageID);
				}
				//Calculate and store sprite location on the display area
				__m128i ulur = _mm_loadu_si64(&sprt.position.topLeft) |
						_mm_slli_si128!8(_mm_loadu_si64(&sprt.position.topRight));
				__m128i lllr = _mm_loadu_si64(&sprt.position.bottomLeft) |
						_mm_slli_si128!8(_mm_loadu_si64(&sprt.position.bottomRight));
				short8 tppck = cast(short8)_mm_packs_epi32(ulur - scrollVec, lllr - scrollVec);
				gl_RenderOut.ul.x = tppck[0];
				gl_RenderOut.ul.y = tppck[1];
				gl_RenderOut.ur.x = tppck[2];
				gl_RenderOut.ur.y = tppck[3];
				gl_RenderOut.ll.x = tppck[4];
				gl_RenderOut.ll.y = tppck[5];
				gl_RenderOut.lr.x = tppck[6];
				gl_RenderOut.lr.y = tppck[7];
				//Store sprite material position
				gl_RenderOut.ul.s = cm.left;
				gl_RenderOut.ul.t = cm.top;
				gl_RenderOut.ur.s = cm.right;
				gl_RenderOut.ur.t = cm.top;
				gl_RenderOut.ll.s = cm.left;
				gl_RenderOut.ll.t = cm.bottom;
				gl_RenderOut.lr.s = cm.right;
				gl_RenderOut.lr.t = cm.bottom;
				//Store sprite attributes
				gl_RenderOut.ul.attributes = sprt.attr[0];
				gl_RenderOut.ur.attributes = sprt.attr[1];
				gl_RenderOut.ll.attributes = sprt.attr[2];
				gl_RenderOut.lr.attributes = sprt.attr[3];
				if (prevPrg != prg) {
					prevPrg = prg;
					glUseProgram(prg);
					glUniform1i(glGetUniformLocation(prg, "palette"), 1);
					glUniform1i(glGetUniformLocation(prg, "paletteMipMap"), 2);
					glUniform2f(glGetUniformLocation(prg, "stepSizes"), screenSizeRec[0], screenSizeRec[1]);
					paletteOffset = glGetUniformLocation(prg, "paletteOffset");
					mainTexture = glGetUniformLocation(prg, "mainTexture");
				}
				const colorSelY = sprt.palSel>>(8-sprt.palSh), colorSelX = sprt.palSel&((1<<(8-sprt.palSh))-1);
				glUniform2f(paletteOffset,colorSelX * (1.0 / 256),colorSelY * (1.0 / 256));
				glUniform1i(mainTexture, 0);
				// glUniform1f(glGetUniformLocation(gl_Program, "palLengthMult"), 1.0 / (9 - sprt.palSh));
				// bind vertex arrays
				glBindVertexArray(gl_vertexArray);

				glBindBuffer(GL_ARRAY_BUFFER, gl_vertexBuffer);
				glBufferData(GL_ARRAY_BUFFER, DisplayListItem_GL.sizeof, &gl_RenderOut, GL_STREAM_DRAW);

				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_vertexIndices);
				glBufferData(GL_ELEMENT_ARRAY_BUFFER, 4 * 6, gl_PlIndices.ptr, GL_STREAM_DRAW);

				glEnableVertexAttribArray(0);
				glVertexAttribIPointer(0, 2, GL_SHORT, cast(int)(SpriteVertex.sizeof), cast(void*)0);
				glEnableVertexAttribArray(1);
				glVertexAttribIPointer(1, 2, GL_UNSIGNED_SHORT, cast(int)(SpriteVertex.sizeof), cast(void*)SpriteVertex.s.offsetof);
				glEnableVertexAttribArray(2);
				glVertexAttribIPointer(2, 4, GL_UNSIGNED_BYTE, cast(int)(SpriteVertex.sizeof),
						cast(void*)SpriteVertex.attributes.offsetof);
				glEnableVertexAttribArray(3);
				glVertexAttribIPointer(3, 2, GL_SHORT, cast(int)(SpriteVertex.sizeof),
						cast(void*)(SpriteVertex.attributes.offsetof + GraphicsAttrExt.lX.offsetof));
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
		sizediff_t index = displayList_sprt.searchIndexBy(n);
		if (index == -1) return 0;
		return displayList_sprt[n].palSel;
	}
	/**
	 * Removes a sprite from the displaylist by priority.
	 */
	public void removeSprite(int n) @nogc @safe nothrow {
		try {
			const sizediff_t pos = displayList_sprt.searchIndexBy(n);
			if (pos != -1) displayList_sprt.remove(pos);
		} catch (Exception e) {
			fatal_trusted(e.msg);
		}
	}
	///Clears all sprite from the layer.
	public void clear() @safe nothrow {
		try {
			displayList_sprt.length = 0;
		} catch (Exception e) {
			fatal_trusted(e.msg);
		}
	}
	/**
	 * Moves a sprite to the given position.
	 */
	public Quad moveSprite(int n, int x, int y) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchIndexBy(n);
		if (i == -1) return Quad.init;
		displayList_sprt[i].position.move(x, y);
		return displayList_sprt[i].position;
	}
	/**
	 * Moves a sprite by the given amount.
	 */
	public Quad relMoveSprite(int n, int x, int y) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchIndexBy(n);
		if (i == -1) return Quad.init;
		displayList_sprt[i].position.relMove(x, y);
		return displayList_sprt[i].position;
		//checkSprite(*sprt);
	}
	public void setSpriteShader(int n, GLShader shader) @nogc @safe nothrow {
		const sizediff_t i = displayList_sprt.searchIndexBy(n);
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
		const sizediff_t i = displayList_sprt.searchIndexBy(n);
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
		const sizediff_t i = displayList_sprt.searchIndexBy(n);
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
