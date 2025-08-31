/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers.base module
 */

module pixelperfectengine.graphics.layers.base;

public import pixelperfectengine.graphics.bitmap;
public import pixelperfectengine.graphics.common;
public import pixelperfectengine.graphics.layers.interfaces;
package import pixelperfectengine.graphics.transformfunctions;
package import pixelperfectengine.system.etc;
//package import pixelperfectengine.system.platform;

package import std.bitmanip : bitfields;
public import pixelperfectengine.system.exc;
package import bindbc.opengl;
package import core.stdc.stdlib;
package import CPUblit.composing;
package import CPUblit.composing.specblt : xorBlitter;
package import CPUblit.colorlookup;
package import CPUblit.transform;

import inteli.emmintrin;

/**
 * The basis of all layer classes, containing function pointers for rendering.
 * Can be overloaded for user defined layers.
 */
abstract class Layer {
	
	///TODO: move bitflags and other options here.
	///Stores various states of this layer
	protected uint		flags;
	protected static enum	CLEAR_Z_BUFFER = 1<<0;		///Deprecated flag, current rendering algorithm does not use Z buffers
	protected static enum	LINKED_SECONDARY = 1<<1;	///Set when a layer is linked to another
	protected int		sX;		///Horizontal scroll position
	protected int		sY;		///Vertical scroll position
	protected int		rasterX;///Raster width (visible)
	protected int		rasterY;///Haster height (visible)
	protected ushort[4]	overscanAm;

	/**
	 * Sets up the layer for the current rasterizer.
	 * Params:
	 *   rX = Width of the raster.
	 *   rY = Height of the raster.
	 * Note: These values define the visible area that need to be worked with. Some overscan can be defined,
	 * and `updateRaster`'s `pitch` parameter defines the per-line stepping. Note that too much overscan can
	 * negatively impact performance.
	 */
	public void setRasterizer(int rX, int rY) @safe pure nothrow {
		rasterX=rX;
		rasterY=rY;
	}

	/**
	 * Scrolls the layer to the given position.
	 * Params:
	 *   x = Horizontal coordinate.
	 *   y = Vertical coordinate.
	 */
	public void scroll(int x, int y) @safe nothrow {
		sX = x;
		sY = y;
	}
	/**
	 * Relatively scrolls the layer by the given amount.
	 * Formula is:
	 * `[sX,sY] = [sX,sY] + [x,y]`
	 * Params:
	 *   x = Horizontal amount.
	 *   y = Vertical amount.
	 */
	public void relScroll(int x, int y) @safe nothrow {
		sX += x;
		sY += y;
	}
	///Getter for the X scroll position.
	public int getSX() @nogc @safe pure nothrow const {
		return sX;
	}
	///Getter for the Y scroll position.
	public int getSY() @nogc @safe pure nothrow const {
		return sY;
	}
	/**
	 * Renders the layer's output to the raster. Function is called sequentially for all layers. Layers with higher
	 * priority number will render to the raster in a later time. Function is marked as @nogc, as render-time 
	 * allocation has negative impact on performance. For errors, either use asserts for unrecoverable errors, or 
	 * errorcodes for less severe cases.
	 * Params:
	 *   workpad = The pointer to the workpad's first pixel to be shown. Does not have to be equal with the actual
	 * first pixel of the workpad.
	 *   pitch = The difference between lines in the amount of bytes. Must also contain any padding bytes, e.g.
	 * pixels, etc.
	 *   palette = Pointer to the first element on the palette.
	 * NOTES:
	 * - Due to the nature of how rendering functions work on vector extensions, arrays are not as feasible as
	 * in other places, so that's why pointers are used instead.
	 * DEPRECATED, no longer used for rendering.
	 */
	public abstract void updateRaster(void* workpad, int pitch, Color* palette) @nogc;
	/**
	 * Adds a bitmap source to the layer.
	 * Params:
	 *   bitmap = the bitmap to be uploaded as a texture.
	 *   page = page identifier.
	 * Returns: Zero on success, or a specific error code.
	 */
	public abstract int addBitmapSource(ABitmap bitmap, int page, ubyte palSh = 8) @trusted @nogc nothrow;
	/**
	 * Removes the seleced bitmap source and optionally runs the appropriate destructor code. Can remove bitmap
	 * sources made by functions `addBitmapSource` and `addTextureSource_GL`.
	 * Params:
	 *   page = the page identifier of the to be removed texture.
	 *   runDTor = if true, the texture will be deleted from the GPU memory. Normally should be true.
	 * Returns: 0 on success, or -1 if page entry not found.
	 */
	public abstract int removeBitmapSource(int page, bool runDTor = true) @trusted @nogc nothrow;
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
	public abstract int addTextureSource_GL(GLuint texture, int page, int width, int height, ubyte palSh = 8)
			@trusted @nogc nothrow;
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
	public abstract void renderToTexture_gl(GLuint workpad, GLuint palette, GLuint palNM, int[4] sizes, int[2] offsets)
			@nogc nothrow;
	///Sets the tendency to whether clear the Z buffer when this layer is drawn or not.
	public void setClearZBuffer(bool val) @nogc nothrow {
		if (val) flags |= CLEAR_Z_BUFFER;
		else flags &= ~CLEAR_Z_BUFFER;
	}
	///Sets the overscan amount, on which some effects are dependent on.
	public final ushort[4] setOverscanAmount(ushort[4] amount) @nogc @safe nothrow pure {
		overscanAm = amount;
		return overscanAm;
	}
	/**
	 * Updates the display list of the layer: finalizes all changes made to the layer before displaying, and keeps the
	 * changes until this function is called yet again.
	 */
	public abstract void updateDisplayList() @trusted @nogc nothrow;
	///Returns the type of the layer.
	///Useful with certain scripting languages.
	public abstract LayerType getLayerType() @nogc @safe pure nothrow const;
	///Standard algorithm for horizontal mirroring, used for tile mirroring
	///To be deprecated after move to OpenGL completed
}
/**
 * Defines a layer, that can be used during the rendering of other layers in the shader,
 * usually for "color math" purposes.
 */
abstract class MaskLayer {
	protected int		rasterW;///Raster width (visible)
	protected int		rasterH;///Haster height (visible)
	public void setRasterSize(int rasterW, int rasterH) @safe @nogc nothrow pure {
		this.rasterW = rasterW;
		this.rasterH = rasterH;
	}
	public abstract uint getTexture_GL() @nogc nothrow;
	public abstract void renderToTexture_gl() @nogc nothrow;
}
///Defines potential texture upload error codes
public enum TextureUploadError {
	init						=	0,		///No error
	TextureFormatNotSupported	=	-1,
	TextureTooBig				=	-2,		///Bitmap is larger than what the GPU can handle
	OutOfMemory					=	-3,
	TextureSizeMismatch			=	-4,		///Bitmap does not match the requested size
	TextureTypeMismatch			=	-5		///Bitmap does not match the requested type
}
/**
 * Mostly used for internal communication and scripting.
 */
public enum LayerType {
	init,
	Tile,
	TransformableTile,
	Sprite,
	Effects,
}
/**
 * Sets the WarpMode for any tile layer.
 */
public enum WarpMode : ubyte {
	Off,				/// Content shown only once.
	MapRepeat,			/// Tilemap is repeated on the layer.
	TileRepeat			/// Out of bounds areas repeat tile 0x0000. Tile 0xFFFF is still reserved as transparency.
}
/**
 * Mapping element, that is used on most if not all layers in this engine.
 * It reserves:
 * * 16 bits for tile selection.
 * * 6 bits for extra purposes (can be user defined if the layer doesn't use it for anything else).
 * * 1 bit for vertical mirroring.
 * * 1 bit for horizontal mirroring.
 * * 8 bits for palette selection (can be used for user-defined purposes if tiles are either 16 or 32 bit).
 * User defined purposes may include marking tiles with special purpose for the game logic.
 * Deprecated: Will be slowly replaced with MappingElement2 instead.
 */
public struct MappingElement {
	wchar tileID;				///Determines which tile is being used for the given instance. 0xFFFF is reserved for transparency.
	BitmapAttrib attributes;	///General attributes, such as vertical and horizontal mirroring. The extra 6 bits can be used for various purposes
	ubyte paletteSel;			///Selects the palette for the bitmap if supported
	///Default constructor
	this(wchar tileID, BitmapAttrib attributes = BitmapAttrib(false, false, false), ubyte paletteSel = 0)
			@nogc @safe pure nothrow {
		this.tileID = tileID;
		this.attributes = attributes;
		this.paletteSel = paletteSel;
	}
	public string toString() const {
		import std.conv : to;
		return "[tileID:" ~ to!string(cast(int)tileID) ~ "; attributes:" ~ attributes.toString ~ "; paletteSel:" ~
				to!string(paletteSel) ~ "]";
	}
}
/**
 * Implements the newer mapping element for tile layers.
 * Changes:
 * - palette selector increased to 12 bits from 8 bits,
 * - tile attributes are now built in, including horizontal and vertical mirroring, and XY
 * invert,
 * - single-bit priority, noting that the selected tile must be drawn on a second round.
 */
public struct MappingElement2 {
	wchar tileID;		/// Selects which tile material will be used.
	ushort _bitfield;	/// Contains the palette selector and the tile attributes.
	this(wchar tileID, ushort paletteSel = 0, bool hMirror = false, bool vMirror = false,
			bool xyInvert = false, bool priority = false) @nogc @safe pure nothrow {
		this.tileID = tileID;
		this.paletteSel = paletteSel;
		this.hMirror = hMirror;
		this.vMirror = vMirror;
		this.xyInvert = xyInvert;
		this.priority = priority;
	}
	this(MappingElement other) @nogc @safe pure nothrow {
		this.tileID = other.tileID;
		this.paletteSel = other.paletteSel;
		this.hMirror = other.attributes.horizMirror;
		this.vMirror = other.attributes.vertMirror;
		this.xyInvert = other.attributes.xyRotate;
		this.priority = other.attributes.priority != 0;
	}
	ushort paletteSel() @nogc @safe pure nothrow const {
		return _bitfield & 0x0F_FF;
	}
	bool hMirror() @nogc @safe pure nothrow const {
		return (_bitfield & 0x10_00) != 0;
	}
	bool vMirror() @nogc @safe pure nothrow const {
		return (_bitfield & 0x20_00) != 0;
	}
	bool xyInvert() @nogc @safe pure nothrow const {
		return (_bitfield & 0X40_00) != 0;
	}
	bool priority() @nogc @safe pure nothrow const {
		return (_bitfield & 0x80_00) != 0;
	}
	ushort paletteSel(ushort val) @nogc @safe pure nothrow {
		_bitfield &= 0xF0_00;
		_bitfield |= val & 0x0F_FF;
		return _bitfield & 0x0F_FF;
	}
	bool hMirror(bool val) @nogc @safe pure nothrow {
		if (val) _bitfield |= 0x10_00;
		else _bitfield &= ~0x10_00;
		return (_bitfield & 0x10_00) != 0;
	}
	bool vMirror(bool val) @nogc @safe pure nothrow {
		if (val) _bitfield |= 0x20_00;
		else _bitfield &= ~0x20_00;
		return (_bitfield & 0x20_00) != 0;
	}
	bool xyInvert(bool val) @nogc @safe pure nothrow {
		if (val) _bitfield |= 0x40_00;
		else _bitfield &= ~0x40_00;
		return (_bitfield & 0X40_00) != 0;
	}
	bool priority(bool val) @nogc @safe pure nothrow {
		if (val) _bitfield |= 0x80_00;
		else _bitfield &= ~0x80_00;
		return (_bitfield & 0x80_00) != 0;
	}
}
