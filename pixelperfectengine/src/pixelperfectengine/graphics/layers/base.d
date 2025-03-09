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
alias RenderFunc = @nogc pure nothrow void function(uint* src, uint* dest, size_t length, ubyte value);
/// For generating a blitter function with value modifier
@nogc pure nothrow void localBlt(uint* src, uint* dest, size_t length, ubyte value) {
	blitter!uint(src, dest, length);
}
/// For generating a copy function with value modifier
@nogc pure nothrow void localCpy(uint* src, uint* dest, size_t length, ubyte value) {
	copy!uint(src, dest, length);
}
/// For generating a XOR blitter function with value modifier
@nogc pure nothrow void localXOR(uint* src, uint* dest, size_t length, ubyte value) {
	xorBlitter!uint(src, dest, length);
}
/**
 * The basis of all layer classes, containing function pointers for rendering.
 * Can be overloaded for user defined layers.
 */
abstract class Layer {
	protected RenderFunc mainRenderingFunction;		///Used to implement changeable renderers for each layers
	/+protected @nogc pure nothrow void function(ushort* src, uint* dest, uint* palette, size_t length) 
			mainColorLookupFunction;+/
	//protected @nogc void function(uint* src, int length) mainHorizontalMirroringFunction;
	/+protected @nogc pure nothrow void function(ubyte* src, uint* dest, uint* palette, size_t length) 
			main8BitColorLookupFunction;+/
	/+protected @nogc pure nothrow void function(ubyte* src, uint* dest, uint* palette, size_t length, int offset) 
			main4BitColorLookupFunction;+/
	alias mainColorLookupFunction = colorLookup!(ushort,uint);
	alias main8BitColorLookupFunction = colorLookup!(ubyte,uint);
	alias main4BitColorLookupFunction = colorLookup4Bit!uint;
	protected RenderingMode renderMode;
	///TODO: move bitflags and other options here.
	///Stores various states of this layer
	protected uint		flags;
	protected static enum	CLEAR_Z_BUFFER = 1<<0;
	protected int		sX;		///Horizontal scroll position
	protected int		sY;		///Vertical scroll position
	protected int		rasterX;///Raster width (visible)
	protected int		rasterY;///Haster height

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
	 * Sets the global rendering mode for this layer.
	 * Params:
	 *   mode = The enumerator that describes built-in rendering functions.
	 */
	public void setRenderingMode(RenderingMode mode) @nogc @safe pure nothrow {
		renderMode = mode;
		mainRenderingFunction = getRenderingFunc(mode);

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
	 * Note: Due to the nature of how rendering functions work on vector extensions, arrays are not as feasible as
	 * in other places, so that's why pointers are used instead.
	 */
	public abstract void updateRaster(void* workpad, int pitch, Color* palette) @nogc ;

	///Amount of virtual overscan, certain effects might rely on this.
	protected float overscanAm;
	/**
	 * Adds a bitmap source to the layer.
	 * Params:
	 *   bitmap = the bitmap to be uploaded as a texture.
	 *   page = page identifier.
	 * Returns: Zero on success, or a specific error code.
	 */
	public abstract int addBitmapSource(ABitmap bitmap, int page);
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
	public abstract void renderToTexture_gl(GLuint workpad, GLuint palette, GLuint palNM, int[4] sizes, int[2] offsets) @nogc nothrow;
	///Sets the tendency to whether clear the Z buffer when this layer is drawn or not.
	public void setClearZBuffer(bool val) @nogc nothrow {
		if (val) flags |= CLEAR_Z_BUFFER;
		else flags &= ~CLEAR_Z_BUFFER;
	}
	///Sets the overscan amount, on which some effects are dependent on.
	// public abstract void setOverscanAmount(float valH, float valV);

	///Returns the type of the layer.
	///Useful with certain scripting languages.
	public abstract LayerType getLayerType() @nogc @safe pure nothrow const;
	///Standard algorithm for horizontal mirroring, used for tile mirroring
	///To be deprecated after move to OpenGL completed
	protected void flipHorizontal(T)(T[] target) @nogc pure nothrow {
		//sizediff_t j = target.length - 1;
		for (sizediff_t i, j = target.length - 1 ; i < j ; i++, j--) {
			const T s = target[i];
			target[i] = target[j];
			target[j] = s;
			//j--;
		}
	}
}
public enum TextureUploadError {
	init,
	TextureFormatNotSupported	=	-1,
	TextureTooBig				=	-2,
	OutOfMemory					=	-3,
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
 * Defines how the layer or sprite will be rendered.
 * See each value's documentation individually for more information on each mode.
 */
public enum RenderingMode : ubyte {
	init,			///Rendering mode is not set
	Copy,			///Copies the pixels without any transparencies. The fastest as it only reads once. Best use is either GUI or lowest-layer.
	Blitter,		///Copies the pixels to the target using simple transparency. No effect from master-alpha values. Can be faster on less memory-bound machines.
	AlphaBlend,		///Blends the source onto the target, using both per-pixel alpha and master alpha. 
	Multiply,		///Multiplies pixel channel values, then stores it in the destination.
	MultiplyBl,		///Multiply with alpha used as a blend between the original and target value.
	Screen,			///Composes the source to the destination using the following formula: 1 - (1 - dest) * (1 - src)
	ScreenBl,		///Screen with alpha used as a blend between the original and target value.
	Add,			///Adds with saturation the source to the destination.
	AddBl,			///Add with alpha used as a blend between the original and target value.
	Subtract,		///Subtracts with saturation the source from the destination.
	SubtractBl,		///Subtracts with saturation the source from the destination. Alpha determines how much of the source's other channels is used.
	Diff,			///Calculates the difference between the source and destination.
	DiffBl,			///Calculates the difference between the source and destination. Alpha determines how much of the source's other channels is used.
	AND,			///Logically ANDs the source to the destination. Alpha value is ignored.
	OR,				///Logically ORs the source to the destination. Alpha value is ignored.
	XOR,			///Logically XORs the source to the destination. Alpha value is ignored.
}
/**
 * Returns the rendering function that belongs to the enumeration value.
 */
public RenderFunc getRenderingFunc (RenderingMode mode) @nogc @safe pure nothrow {
	final switch (mode) with (RenderingMode) {
		case init:
			return null;
		case Copy:
			return &localCpy;
		case Blitter:
			return &localBlt;
		case AlphaBlend:
			return (uint* src, uint* dest, size_t length, ubyte value) {alphaBlendMV(src, dest, length, value);};
		case Multiply:
			return (uint* src, uint* dest, size_t length, ubyte value) {multMV(src, dest, length, value);};
		case MultiplyBl:
			return (uint* src, uint* dest, size_t length, ubyte value) {multMVBl(src, dest, length, value);};
		case Screen:
			return (uint* src, uint* dest, size_t length, ubyte value) {screenMV(src, dest, length, value);};
		case ScreenBl:
			return (uint* src, uint* dest, size_t length, ubyte value) {screenMVBl(src, dest, length, value);};
		case Add:
			return (uint* src, uint* dest, size_t length, ubyte value) {addMV!(false)(src, dest, length, value);};
		case AddBl:
			return (uint* src, uint* dest, size_t length, ubyte value) {addMV!(true)(src, dest, length, value);};
		case Subtract:
			return (uint* src, uint* dest, size_t length, ubyte value) {subMV!(false)(src, dest, length, value);};
		case SubtractBl:
			return (uint* src, uint* dest, size_t length, ubyte value) {subMV!(true)(src, dest, length, value);};
		case Diff:
			return (uint* src, uint* dest, size_t length, ubyte value) {diffMV(src, dest, length, value);};
		case DiffBl:
			return (uint* src, uint* dest, size_t length, ubyte value) {diffMVBl(src, dest, length, value);};
		case AND:
			return null;
		case OR:
			return null;
		case XOR:
			return &localXOR;
	}
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
 */
public struct MappingElement {
	wchar tileID;				///Determines which tile is being used for the given instance. 0xFFFF is reserved for transparency.
	BitmapAttrib attributes;	///General attributes, such as vertical and horizontal mirroring. The extra 6 bits can be used for various purposes
	ubyte paletteSel;			///Selects the palette for the bitmap if supported
	///Default constructor
	this(wchar tileID, BitmapAttrib attributes = BitmapAttrib(false, false), ubyte paletteSel = 0)
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
