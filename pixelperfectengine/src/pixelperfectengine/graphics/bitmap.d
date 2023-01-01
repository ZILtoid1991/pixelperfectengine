/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * pixel Perfect Engine, graphics.bitmap module
 */

module pixelperfectengine.graphics.bitmap;
import std.bitmanip;
import pixelperfectengine.system.exc;
import bitleveld.reinterpret;
import bitleveld.datatypes;

//public import pixelperfectengine.system.advBitArray;
public import pixelperfectengine.graphics.common;

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
	public int width() pure @safe @property @nogc nothrow const {
		return _width;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	public int height() pure @safe @property @nogc nothrow const {
		return _height;
	}
	/**
	 * Returns the palette pointer.
	 * DEPRECATED!
	 */
	public deprecated Color* getPalettePtr() pure @trusted @property @nogc nothrow {
		return palettePtr;
	}
	/**
	 * Sets the palette pointer. Make sure that you set it to a valid memory location.
	 * DEPRECATED!
	 */
	public deprecated void setPalettePtr(Color* p) pure @safe @property @nogc nothrow {
		palettePtr = p;
	}
	/**
	 * Returns the wordlength of the type
	 */
	abstract string wordLengthByString() pure @safe @property @nogc nothrow const;
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
alias Bitmap1Bit = Bitmap!("b",size_t);
alias Bitmap2Bit = Bitmap!("QB",ubyte);
alias Bitmap4Bit = Bitmap!("HB",ubyte);
alias Bitmap8Bit = Bitmap!("B",ubyte);
alias Bitmap16Bit = Bitmap!("HW",ushort);
alias Bitmap32Bit = Bitmap!("W",Color);
/**
 * Implements a bitmap with variable bit depth. Use the aliases to initialize them.
 *
 * Note on 16 bit bitmaps: It's using the master palette, It's not implementing any 16 bit RGB or RGBA color space 
 * directly. Can implement such
 * colorspaces via proper lookup tables.
 *
 * Note on 4 bit bitmaps: It's width needs to be an even number (for rendering simplicity), otherwise it'll cause an 
 * exception.
 *
 * Note on 1 bit bitmaps: Uses size_t based paddings for more than one bit testing at the time in the future, through
 * the use of logic functions.
 */
public class Bitmap(string S,T) : ABitmap {
	protected size_t 	pitch;			///Total length of a line in bits
	static if (S == "b") { 
		BitArray 			pixelAccess;
		//bool				invertHoriz;	///Horizontal invertion for reading and writing
		//bool				invertVert;		///Vertical invertion for reading anr writing
	} else static if (S == "QB") {
		QuadArray			pixelAccess;
	} else static if (S == "HB") {
		NibbleArray			pixelAccess;
	}
	/**
	 * Image data.
	 */
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
		@nogc public T writePixel(int x, int y, T color) @safe pure {
			return pixels[x+(_width*y)]=color;
		}
		/**
		 * Returns a 2D slice (window) of the bitmap.
		 */
		public Bitmap!(S,T) window(int iX0, int iY0, int iX1, int iY1) @safe pure {
			T[] workpad;
			const int localWidth = (iX1 - iX0), localHeight = (iY1 - iY0);
			workpad.length  = localWidth * localHeight;
			for (int y ; y < localHeight ; y++) {
				for (int x ; x < localWidth ; x++) {
					workpad[x = (y * localWidth)] = pixels[iX0 + x + ((y + iY0) * _width)];
				}
			}
			return new Bitmap!(S,T)(workpad, localWidth, localHeight);
		}
	} else static if(S == "HB"){
		
		///Creates an empty bitmap.
		this(int w, int h) @safe pure{
			if (w & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=w;
			_height=h;
			pitch = _width / 2;
			pixels.length = pitch * _height;
			pixelAccess = NibbleArray(pixels, _width * _height);
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int w, int h) @safe pure{
			if (p.length * 2 != w * h || w & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=w;
			_height=h;
			pitch = _width / 2;
			pixels=p;
			pixelAccess = NibbleArray(pixels, _width * _height);
		}
		///Resizes the array behind the bitmap.
		public void resize(int x,int y) @safe pure {
			if(x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			pixels.length = (x / 2) * y;
			_width = x;
			_height = y;
		}
	} else static if(S == "QB") {
		///Creates an empty bitmap.
		this(int w, int h) @safe pure{
			if (w & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=w;
			_height=h;
			pitch = _width / 2;
			pixels.length = pitch * _height;
			pixelAccess = QuadArray(pixels, _width * _height);
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int w, int h) @safe pure{
			if (p.length * 4 != w * h || w & 3)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			_width=w;
			_height=h;
			pitch = _width / 2;
			pixels=p;
			pixelAccess = QuadArray(pixels, _width * _height);
		}
	} else static if(S == "b") {
		/**
		 * CTOR for 1 bit bitmaps with no preexisting source.
		 */
		public this(int w, int h) @trusted pure {
			_width = w;
			_height = h;
			pitch = w + (size_t.sizeof * 8 - (w % (size_t.sizeof * 8)));
			pixels.length = pitch / (size_t.sizeof * 8) * h;
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
		static if (size_t.sizeof == 8) {
			static enum SHAM = 6;
			static enum SHFLAG = 0x3F;
			static enum BITAM = 64;
		} else {
			static enum SHAM = 5;
			static enum SHFLAG = 0x1F;
			static enum BITAM = 32;
		}
		/** 
		 * Tests two collision models against each other.
		 * Params:
		 *   line = The first line to test against on the left hand side collision model.
		 *   lineAm = The amount of lines to be tested.
		 *   other = The right hand side collision model.
		 *   otherLine = The first line to test against on the right hand side collision model.
		 *   offset = The amount, which the right hand side collision model's left edge is away from the left hand
		 * side collision model's left edge.
		 *   overlapAm = The amount of overlap between the two objects.
		 * Returns: 
		 */
		public bool testCollision(int line, int lineAm, Bitmap1Bit other, int otherLine, const int offset, 
				const int overlapAm) @safe @nogc nothrow pure const {
			const int chOffset = offset>>SHAM;
			assert(overlapAm, "This function should not be called if `overlapAm == 0`");
			assert(lineAm, "This function should not be called if `lineAm == 0`");
			for ( ; lineAm > 0 ; lineAm--, line++, otherLine++) {
				int overlapCntr = overlapAm;
				int loffset = offset;
				int lchOffset = chOffset;
				if (testChunkCollision(line, chOffset, other, otherLine, loffset))
					return true;
				overlapCntr -= BITAM;
				loffset += BITAM;
				lchOffset++;
				for ( ; overlapCntr > 0 ; overlapCntr -= BITAM, loffset += BITAM, lchOffset++) {
					if (testChunkCollisionB(line, chOffset, other, otherLine, loffset))
						return true;
				}
			}
			return false;
		}
		/**
		 * Tests a single chunk of pixels between two 1 bit bitmaps for collision, using a single chunk (size_t) of 
		 * pixels.
		 * Params:
		 *   line: The (first) line, which is being tested in the current object.
		 *   other: The other object that this is being tested against.
		 *   otherLine: The (first) line, which is being tested in the other object.
		 *   offset: The horizontal offset of the other object to the right.
		 * Returns: True is collision has been detected.
		 */
		final protected bool testChunkCollision(int line, int chOffset, Bitmap1Bit other, int otherLine, int offset) 
				@safe @nogc nothrow pure const {
			if (pixels[chOffset + (line * (pitch>>SHAM))] & 
					(other.pixels[(offset>>SHAM) + ((other.pitch>>SHAM) * otherLine)]<<(offset & SHFLAG)))
				return true;
			return false;
		}
		/**
		 * Tests a single chunk of pixels between two 1 bit bitmaps for collision, using a single chunk (size_t) of 
		 * pixels, if other is wider than what size_t allows.
		 * Params:
		 *   line: The (first) line, which is being tested in the current object.
		 *   other: The other object that this is being tested against.
		 *   otherLine: The (first) line, which is being tested in the other object.
		 *   offset: The horizontal offset of the other object to the right.
		 * Returns: True is collision has been detected.
		 */
		final protected bool testChunkCollisionB(int line, int chOffset, Bitmap1Bit other, int otherLine, int offset) 
				@safe @nogc nothrow pure const {
			if (pixels[chOffset + (line * (pitch>>SHAM))] & 
					((other.pixels[(offset>>SHAM) + ((other.pitch>>SHAM) * otherLine)]<<(offset & SHFLAG)) |
					(other.pixels[((offset>>SHAM) - 1) + ((other.pitch>>SHAM) * otherLine)]>>(SHFLAG - (offset & SHFLAG)))))
				return true;
			return false;
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
	static if (S == "b" || S == "QB" || S == "HB") {
		/**
		 * Returns a 2D slice (window) of the bitmap.
		 */
		public Bitmap!(S,T) window(int iX0, int iY0, int iX1, int iY1) @safe pure {
			const int localWidth = (iX1 - iX0), localHeight = (iY1 - iY0);
			Bitmap!(S,T) result = new Bitmap!(S,T)(localWidth, localHeight);
			for (int y ; y < localHeight ; y++) {
				for (int x ; x < localWidth ; x++) {
					result.writePixel(x, y, readPixel(iX0 + x, iY0 + y));
				}
			}
			return result;
		}
	}
	static if (S == "QB" || S == "HB") {
		///Returns the pixel at the given position.
		@nogc public T readPixel(int x, int y) @trusted pure {
			assert (x >= 0 && x < _width && y >= 0 && y < _height);
			return pixelAccess[x + (y * pitch)];
		}
		///Writes the pixel at the given position.
	    @nogc public T writePixel(int x, int y, T val) @trusted pure {
			assert (x >= 0 && x < _width && y >= 0 && y < _height);
			return pixelAccess[x + (y * pitch)] = val;
		}}
	static if(S == "W"){
		/**
		 * Clears the Bitmap
		 */
		override void clear() @nogc @safe pure nothrow {
			for(int i ; i < pixels.length ; i++){
				pixels[i] = Color(0x0);
			}
		}
	}else{
		override void clear() @nogc @safe pure nothrow {
			for(int i ; i < pixels.length ; i++){
				pixels[i] = 0;
			}
		}
	}
	@nogc public T* getPtr() pure @trusted nothrow {
		return pixels.ptr;
	}
	override string wordLengthByString() @safe @nogc pure nothrow @property const {
		return S;
	}
	static if (S != "b") {
		/**
		 * Generates a standard collision model by checking against a transparency value (default vaule is T.init).
		 */
		Bitmap1Bit generateStandardCollisionModel(const T transparency = T.init) {
			Bitmap1Bit output = new Bitmap1Bit(width, height);
			for (int y ; y < height ; y++) {
				for (int x ; x < width ; x++) {
					output.writePixel(x, y, readPixel(x, y) != transparency);
				}
			}
			return output;
		}
	} else {
		///Returns the pixel at the given position.
		@nogc public bool readPixel(int x, int y) @trusted pure {
			assert (x >= 0 && x < _width && y >= 0 && y < _height);
			return pixelAccess[x + (y * pitch)];
		}
		///Writes the pixel at the given position.
	    @nogc public bool writePixel(int x, int y, bool val) @trusted pure {
			assert (x >= 0 && x < _width && y >= 0 && y < _height);
			return pixelAccess[x + (y * pitch)] = val;
		}
	}
}

/**
 * Defines Bitmap types
 */
public enum BitmapTypes : ubyte {
	Undefined,			///Can be used for error checking, e.g. if a tile was initialized or not
	Bmp1Bit,
	Bmp2Bit,
	Bmp4Bit,
	Bmp8Bit,
	Bmp16Bit,
	Bmp32Bit,
	Planar,				///Mainly used as a placeholder
}
