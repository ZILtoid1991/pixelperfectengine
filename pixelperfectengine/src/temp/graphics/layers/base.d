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
package import bindbc.sdl;
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

	// scrolling position
	//protected int sX, sY, rasterX, rasterY;
	protected int		sX;		///Horizontal scroll position
	protected int       sY;		///Vertical scroll position
	protected int		rasterX;///Raster width (visible)
	protected int		rasterY;///Haster height

	/// Sets the main rasterizer
	public void setRasterizer(int rX, int rY) @safe pure nothrow {
		rasterX=rX;
		rasterY=rY;
	}
	///Sets the rendering mode
	public void setRenderingMode(RenderingMode mode) @nogc @safe pure nothrow {
		renderMode = mode;
		mainRenderingFunction = getRenderingFunc(mode);
		//mainColorLookupFunction = &colorLookup!(ushort,uint);
		//mainHorizontalMirroringFunction = &flipHorizontal;
		//main8BitColorLookupFunction = &colorLookup!(ubyte,uint);
		//main4BitColorLookupFunction = &colorLookup4Bit!uint;
	}
	///Absolute scrolling.
	public void scroll(int x, int y) @safe pure nothrow {
		sX = x;
		sY = y;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public void relScroll(int x, int y) @safe pure nothrow {
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
	/// Override this to enable output to the raster
	public abstract void updateRaster(void* workpad, int pitch, Color* palette) @nogc ;
	///Standard algorithm for horizontal mirroring, used for tile mirroring
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
/**
 * Mostly used for internal communication.
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
 * Universal Mapping element, that is stored on 32 bit.
 */
public struct MappingElement {
	wchar tileID;				///Determines which tile is being used for the given instance
	BitmapAttrib attributes;	///General attributes, such as vertical and horizontal mirroring. The extra 6 bits can be used for various purposes
	ubyte paletteSel;			///Selects the palette for the bitmap if supported
	///Default constructor
	this(wchar tileID, BitmapAttrib attributes = BitmapAttrib(false, false), ubyte paletteSel = 0) @nogc @safe pure nothrow {
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