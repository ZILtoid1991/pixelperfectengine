/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * pixel Perfect Engine, graphics.bitmap module
 */

module PixelPerfectEngine.graphics.bitmap;
import std.bitmanip;
import PixelPerfectEngine.system.exc;
import bitleveld.reinterpret;

//public import pixelPerfectEngine.system.advBitArray;
public import PixelPerfectEngine.graphics.common;

/**
 * Bitmap attributes, mainly for layers.
 */
public struct BitmapAttrib{
	mixin(bitfields!(
		bool, "horizMirror", 1,
		bool, "vertMirror", 1,
		ubyte, "priority", 6));
	public this(bool horizMirror, bool vertMirror, ubyte priority = 0) @nogc nothrow @safe pure{
		this.horizMirror = horizMirror;
		this.vertMirror = vertMirror;
		this.priority = priority;
	}
	string toString() const @safe pure nothrow{
		return "[horizMirror: " ~ horizMirror ~ " ; vertMirror: " ~ vertMirror ~ " ; priority: " ~ priority ~ "]";
	}
}

/**
 * Base bitmap functions, for enable the use of the same .
 */
abstract class ABitmap{
	private Color* palettePtr;		///Set this to either a portion of the master palette or to a self-defined place. Not used in 32 bit bitmaps. DEPRECATED!
    private int _width;
    private int _height;
	/**
	 * Returns the width of the bitmap.
	 */
	public int width() pure @safe @property @nogc nothrow {
		return _width;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	public int height() pure @safe @property @nogc nothrow {
		return _height;
	}
	/**
	 * Returns the palette pointer.
	 */
	public Color* getPalettePtr() pure @trusted @property @nogc nothrow {
		return palettePtr;
	}
	/**
	 * Sets the palette pointer. Make sure that you set it to a valid memory location.
	 * DEPRECATED!
	 */
	public void setPalettePtr(Color* p) pure @safe @property @nogc nothrow {
		palettePtr = p;
	}
	/**
	 * Returns the wordlength of the type
	 */
	abstract string wordLengthByString() pure @safe @property @nogc nothrow ;
	/**
	 * Clears the whole bitmap to a transparent color.
	 */
	abstract void clear() pure @safe @nogc nothrow;
}
/*
 * S: Wordlength by usage. Possible values:
 * - b: bit (for collision shapes)
 * - QB: QuarterByte or 2Bit (currently unimplemented)
 * - HB: HalfByte or 4Bit
 * - B: Byte or 8Bit
 * - HW: HalfWord or 16Bit
 * - W: Word or 32Bit
 * T: Type. Possible values:
 * - size_t: used for bitarrays
 * - ubyte: 8Bit or under
 * - ushort: 16Bit
 * - Color: 32Bit
 */
alias Bitmap1bit = Bitmap!("b",size_t);
alias Bitmap4Bit = Bitmap!("HB",ubyte);
alias Bitmap8Bit = Bitmap!("B",ubyte);
alias Bitmap16Bit = Bitmap!("HW",ushort);
alias Bitmap32Bit = Bitmap!("W",Color);
/**
 * Implements a bitmap with variable bit depth. Use the aliases to initialize them.
 * Note for 16Bit bitmap: It's using the master palette, It's not implementing any 16 bit RGB or RGBA color space directly. Can implement such
 * colorspaces via proper lookup tables.
 * Note for 4Bit bitmap: It's width needs to be an even number (for rendering simplicity), otherwise it'll cause an exception.
 */
public class Bitmap(string S,T) : ABitmap {
	static if (S == "b") { 
		BitArray 			pixelAccess;
		protected size_t 	pitch;	///Total length of a line in bits
		bool				invertHoriz;	///Horizontal invertion for reading and writing
		bool				invertVert;		///Vertical invertion for reading anr writing
	}
	T[] 					pixels;
	static if(S != "HB" && S != "QB" && S != "b"){
		/**
		 * Unified CTOR to create empty bitmap.
		 */
		public this(int w, int h) @safe pure {
			_width = w;
			_height = h;
			pixels.length = w * h;
		}
		/**
		 * Unified CTOR tor create bitmap from preexisting data.
		 */
		public this(T[] src, int w, int h) @safe pure {
			_width = w;
			_height = h;
			pixels = src;
			if(pixels.length != w * h)
				throw new BitmapFormatException("Bitmap size mismatch!");
		}
		/**
		 * Resizes the bitmap.
		 * NOTE: It's not for scaling.
		 */
		public void resize(int x, int y) @safe pure {
			pixels.length=x*y;
			_width = x;
			_height = y;
		}
		///Returns the pixel at the given position.
		@nogc public T readPixel(int x, int y) @safe pure {
			return pixels[x+(_width*y)];
		}
		///Writes the pixel at the given position.
		@nogc public void writePixel(int x, int y, T color) @safe pure {
			pixels[x+(_width*y)]=color;
		}
		/**
		 * Returns a 2D slice (window) of the bitmap.
		 */
		public Bitmap!(S,T) window(int iX0, int iY0, int iX1, int iY1) @safe pure {
			T[] workpad;
			const size_t localWidth = (iX1 - iX0), localHeight = (iY1 - iY0);
			workpad.length  = localWidth * localHeight;
			for (int y ; y < localHeight ; y++) {
				for (int x ; x < localWidth ; x++) {
					workpad[x = (y * localWidth)] = pixels[iX0 + x + ((y + iY0) * _width)];
				}
			}
			return new Bitmap!(S,T)(workpad, localWidth, localHeight);
		}
	} else static if(S == "HB"){
		///Creates an empty bitmap. DEPRECATED!
		this(int x, int y, Color* palettePtr) @safe pure {
			if(x & 1)
				x++;
			_width=x;
			_height=y;
			pixels.length=(x*y)/2;
			this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array. DEPRECATED!
		this(ubyte[] p, int x, int y, Color* palettePtr){
			if (p.length/2 < x * y || x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=x;
			_height=y;
			pixels=p;
			this.palettePtr = palettePtr;
		}
		///Creates an empty bitmap.
		this(int x, int y) @safe pure{
			if(x & 1)
				x++;
			_width=x;
			_height=y;
			pixels.length=(x*y)/2;
			//this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int x, int y) @safe pure{
			if (p.length/2 < x * y || x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=x;
			_height=y;
			pixels=p;
			//this.palettePtr = palettePtr;
		}
		///Returns the pixel at the given position.
		@nogc public ubyte readPixel(int x, int y) @safe pure{
			if(x & 1)
				return pixels[x>>1+(_width*y)] & 0x0F;
			else
				return (pixels[x>>1+(_width*y)])>>4;
		}
		///Writes the pixel at the given position.
	    @nogc public void writePixel(int x, int y, ubyte color) @safe pure {
			if(x & 1){
				pixels[x+(_width*y)]&= 0xF0;
				pixels[x+(_width*y)]|= color;
			}else{
				pixels[x+(_width*y)]&= 0x0F;
				pixels[x+(_width*y)]|= color<<4;
			}
		}
		
		///Resizes the array behind the bitmap.
		public void resize(int x,int y) @safe pure {
			if(x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			pixels.length=x*y;
			_width = x;
			_height = y;
		}

	} else static if(S == "b") {
		/**
		 * CTOR for 1 bit bitmaps with no preexisting source.
		 */
		public this(int w, int h) @trusted pure {
			_width = w;
			_height = h;
			pitch = w + (size_t.sizeof * 8 - (w % (size_t.sizeof * 8)));
			pixels.length = pitch / (size_t.sizeof * 8);
			pixelAccess = BitArray(pixels, pitch * height);
		}
		/**
		 * CTOR to convert 8bit aligned bitmaps to 32/64bit ones.
		 */
		public this(ubyte[] src, int w, int h) @trusted pure {
			_width = w;
			_height = h;
			pitch = w + (size_t.sizeof * 8 - (w % (size_t.sizeof * 8)));
			const size_t pitch0 = w + (8 - (w % 8));
			const size_t len = pitch / (size_t.sizeof * 8), len0 = pitch0 / 8;
			for (size_t i ; i < len0 * h; i+= len0) {
				ubyte[] workpad = src[i..i+len0];
				workpad.length = len;
				pixels ~= reinterpretCast!size_t(workpad);
			}
			pixelAccess = BitArray(pixels, pitch * height);
		}
		/**
		 * CTOR for 1 bit bitmaps with a preexisting source.
		 * Alignment and padding is for size_t (32 and 64 bit, on their respected systems)
		 */
		public this(size_t[] src, int w, int h) @trusted pure {
			_width = w;
			_height = h;
			pitch = w + (size_t.sizeof * 8 - (w % (size_t.sizeof * 8)));
			pixels = src;
			pixelAccess = BitArray(pixels, pitch * height);
		}
		///Returns the pixel at the given position.
		@nogc public bool readPixel(int x, int y) @trusted pure {
			return pixelAccess[(invertHoriz ? _width - x : x) + ((invertVert ? _height - y : y) * pitch)];
		}
		///Writes the pixel at the given position.
	    @nogc public bool writePixel(int x, int y, bool val) @trusted pure {
			return pixelAccess[(invertHoriz ? _width - x : x) + ((invertVert ? _height - y : y) * pitch)] = val;
		}
	}
	static if(S == "B" || S == "HW") {
		/**
		 * Offsets all indexes in the bitmap by a certain value. Keeps zeroth index (usually for transparency) if needed. Useful when converting bitmaps.
		 */
		public @nogc void offsetIndexes(ushort offset, bool keepZerothIndex = true) @safe pure{
			for(int i ; i < pixels.length ; i++){
				if(!(pixels[i] == 0 && keepZerothIndex)){
					pixels[i] += offset;
				}
			}
		}
	}
	static if(S == "W"){
		/**
		 * Generates a basic collision shape using
		 */
		public Bitmap1bit getBasicCollisionShape() @safe pure {
			return null;
		}
		override void clear() @nogc @safe pure nothrow {
			for(int i ; i < pixels.length ; i++){
				pixels[i] = Color(0x0);
			}
		}
	}else{
		/+override public AdvancedBitArray generateStandardCollisionModel(){	//REMOVE BY 0.10.0!
			AdvancedBitArray result = new AdvancedBitArray(_width * _height);
			for(int i ; i < _width * _height ; i++){
				T pixel = readpixel(i, 0);
				if(pixel != 0){
					result[i] = true;
				}
			}
			return result;
		}+/
		override void clear() @nogc @safe pure nothrow {
			for(int i ; i < pixels.length ; i++){
				pixels[i] = 0;
			}
		}
	}
	@nogc public T* getPtr() pure @trusted nothrow {
		return pixels.ptr;
	}
	override @nogc @property string wordLengthByString() @safe {
		return S;
	}

}


/**
 * Bypasses the transparency on color no.0, no.1 is set to red.
 */
/*static const Color[16] errorPalette;

public ABitmap generateDummyBitmap(int x, int y, wchar c){
	Color* p = errorPalette.ptr;
	Bitmap4Bit result = new Bitmap4Bit(x, y, p);

	return result;
}*/
