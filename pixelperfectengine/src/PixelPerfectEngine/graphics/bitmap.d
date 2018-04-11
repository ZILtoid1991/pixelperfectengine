/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.bitmap module
 */

module PixelPerfectEngine.graphics.bitmap;
import std.bitmanip;
import PixelPerfectEngine.system.exc;
public import PixelPerfectEngine.system.advBitArray;
public import PixelPerfectEngine.graphics.common;

/**
 * Bitmap attributes, mainly for layers.
 */
public struct BitmapAttrib{
	mixin(bitfields!(
		bool, "horizMirror", 1,
		bool, "vertMirror", 1,
		ubyte, "priority", 6));
	@nogc public this(bool horizMirror, bool vertMirror, ubyte priority = 0){
		this.horizMirror = horizMirror;
		this.vertMirror = vertMirror;
		this.priority = priority;
	}
}

/**
 * Base bitmap functions, for enable the use of the same .
 */
abstract class ABitmap{
	private Color* palettePtr;		///Set this to either a portion of the master palette or to a self-defined place. Not used in 32 bit bitmaps.
    private int iX;
    private int iY;
	/**
	 * Returns the width of the bitmap.
	 */
	@property @nogc public int width(){
		return iX;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	@property @nogc public int height(){
		return iY;
	}
	abstract AdvancedBitArray generateStandardCollisionModel();
	/**
	 * Returns the palette pointer.
	 */
	@nogc public Color* getPalettePtr(){
		return palettePtr;
	}
	/** 
	 * Sets the palette pointer. Make sure that you set it to a valid memory location.
	 */
	@nogc public void setPalettePtr(Color* p){
		palettePtr = p;
	}
	/**
	 * Returns the wordlength of the type
	 */
	abstract @nogc @property string wordLengthByString();
	/**
	 * Clears the whole bitmap to a transparent color.
	 */
	abstract @nogc void clear();
}
/*
 * S: Wordlength by usage. Possible values: 
 * - QB: QuadByte or 2Bit (currently unimplemented)
 * - HB: HalfByte or 4Bit
 * - B: Byte or 8Bit
 * - HW: HalfWord or 16Bit
 * - W: Word or 32Bit
 * T: Type. Possible values:
 * - ubyte: 8Bit or under
 * - ushort: 16Bit
 * - Color: 32Bit
 */
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
public class Bitmap(string S,T) : ABitmap{
	T[] pixels;
	static if(S != "HB" && S != "QB"){
		/**
		 * Resizes the bitmap.
		 * NOTE: It's not for scaling.
		 */
		public void resize(int x, int y){
			pixels.length=x*y;
			iX = x;
			iY = y;
		}
		///Returns the pixel at the given position.
		@nogc public T readPixel(int x, int y){
			return pixels[x+(iX*y)];
		}
		///Writes the pixel at the given position.
		@nogc public void writePixel(int x, int y, T color){
			pixels[x+(iX*y)]=color;
		}
	}
	static if(S == "HB"){
		///Creates an empty bitmap.
		this(int x, int y, Color* palettePtr = null){
			if(x & 1)
				x++;
			iX=x;
			iY=y;
			pixels.length=(x*y)/2;
			this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int x, int y, Color* palettePtr = null){
			if (p.length/2 < x * y || x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX=x;
			iY=y;
			pixels=p;
			this.palettePtr = palettePtr;
		}
		///Returns the pixel at the given position.
		@nogc public ubyte readPixel(int x, int y){
			if(x & 1)
				return (pixels[x>>1+(iX*y)])>>4;
			else
				return pixels[x>>1+(iX*y)] & 0x0F;
		}
		///Writes the pixel at the given position.
	    @nogc public void writePixel(int x, int y, ubyte color){
			if(x & 1) color<<=4;
				x/=2;
			pixels[x+(iX*y)]|= color;
		}
		public void resize(int x,int y){
			if(x & 1)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			pixels.length=x*y;
			iX = x;
			iY = y;
		}
		
	}else static if(S == "B"){
		///Creates an empty bitmap.
		this(int x, int y, Color* palettePtr = null){
			if(x < 0 || y < 0)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX=x;
			iY=y;
			pixels.length=x*y;
			this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int x, int y, Color* palettePtr = null){
			if (p.length < x * y)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX=x;
			iY=y;
			pixels=p;
			this.palettePtr = palettePtr;
		}
	}else static if(S == "HW"){
		///Creates an empty bitmap.
		this(int x, int y){
			if(x < 0 || y < 0)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX=x;
			iY=y;
			pixels.length=x*y;
		}
		///Creates a bitmap from an array.
		this(ushort[] p, int x, int y){
			if (p.length < x * y)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX=x;
			iY=y;
			pixels=p;
		}
	}else static if(S == "W"){
		///Creates an empty bitmap.
		public this(int x, int y){
			if(x < 0 || y < 0)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX = x;
			iY = y;
			pixels.length = x * y;
		}
		///Creates a bitmap from an array.
		public this(Color[] p, int x, int y){
			if (p.length < x * y)
				throw new BitmapFormatException("Incorrect Bitmap size exception!");
			iX = x;
			iY = y;
			this.pixels = p;
		}
	}else static assert("Template argument \"" ~ bitmapType ~ "\" not supported!");
	static if(S == "B" || S == "HW"){
		/**
		 * Offsets all indexes in the bitmap by a certain value. Keeps zeroth index (usually for transparency) if needed. Useful when converting bitmaps.
		 */
		public @nogc void offsetIndexes(ushort offset, bool keepZerothIndex = true){
			for(int i ; i < pixels.length ; i++){
				if(!(pixels[i] == 0 && keepZerothIndex)){
					pixels[i] += offset;
				}
			}
		}
	}
	static if(S == "W"){
		override public AdvancedBitArray generateStandardCollisionModel(){
			AdvancedBitArray result = new AdvancedBitArray(iX * iY);
			for(int i ; i < iX * iY ; i++){
				Color pixel = readPixel(i, 0);
				if(pixel.alpha != 0){
					result[i] = true;
				}
			}
			return result;
		}
		override @nogc void clear(){
			for(int i ; i < pixels.length ; i++){
				pixels[i] = Color(0x0);
			}
		}
	}else{
		override public AdvancedBitArray generateStandardCollisionModel(){
			AdvancedBitArray result = new AdvancedBitArray(iX * iY);
			for(int i ; i < iX * iY ; i++){
				T pixel = readPixel(i, 0);
				if(pixel != 0){
					result[i] = true;
				}
			}
			return result;
		}
		override @nogc void clear(){
			for(int i ; i < pixels.length ; i++){
				pixels[i] = 0;
			}
		}
	}
	@nogc public T* getPtr(){
		return pixels.ptr;
	}
	override @nogc @property string wordLengthByString() {
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