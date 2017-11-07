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
 * Note for 16Bit bitmap: It's using the master palette, It's not implementing any 16 bit RGB or RGBA color space.
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
		public void writePixel(int x, int y, T color){
			pixels[x+(iX*y)]=color;
		}
	}
	static if(S == "HB"){
		///Creates an empty bitmap.
		this(int x, int y, Color* palettePtr){
			iX=x;
			iY=y;
			pixels.length=(x*y)/2;
			this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int x, int y, Color* palettePtr){
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
				return (pixels[x+(iX*y)])>>4;
			else
				return pixels[x+(iX*y)] & 0x0F;
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
		this(int x, int y, Color* palettePtr){
			iX=x;
			iY=y;
			pixels.length=x*y;
			this.palettePtr = palettePtr;
		}
		///Creates a bitmap from an array.
		this(ubyte[] p, int x, int y, Color* palettePtr){
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
			iX = x;
			iY = y;
			pixels.length = x * y;
		}
		///Creates a bitmap from an array.
		public this(Color[] p, int x, int y){
			if (p.length < x * y * 4)
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
		public void offsetIndexes(ushort offset, bool keepZerothIndex = true){
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
	}
	@nogc public T* getPtr(){
		return pixels.ptr;
	}
	override @nogc @property string wordLengthByString() {
		return S;
	}
	
}

/+
/**
 * 4 bit bitmaps, mainly added for architectures that would favor multiple 256 color CLUTs instead of a single 65536 color one. Stores a pointer to the CLUT alongside the
 * basic image data.
 * Pixel alignment: HHHH LLLL (H: odd numbered pixels, L: even numbered pixels)
 * NOTE: SizeX must be the multitude of 2, otherwise an exception will be thrown.
 */
public class Bitmap4Bit{
	private ubyte[] pixels;
	private Color* palettePtr;		///Set this to either a portion of the master palette or to a self-defined place.
    private int iX;
    private int iY;
    ///Creates an empty bitmap.
    this(int x, int y, Color* palettePtr){
        iX=x;
        iY=y;
        pixels.length=(x*y)/2;
		this.palettePtr = palettePtr;
    }
    ///Creates a bitmap from an array.
    this(ubyte[] p, int x, int y, Color* palettePtr){
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
			return (pixels[x+(iX*y)])>>4;
		else
			return pixels[x+(iX*y)] & 0x0F;
    }
	///Returns the pointer of the first pixel.
	@nogc public ubyte* getPtr(){
		return pixels.ptr;
	}
	///Returns the palette pointer.
	@nogc public Color* getPalettePtr(){
		return palettePtr;
	}
	///Sets the palette pointer. Make sure that you set it to a valid memory location.
	@nogc public void setPalettePtr(Color* p){
		palettePtr = p;
	}
    ///Writes the pixel at the given position.
    @nogc public void writePixel(int x, int y, ubyte color){
		if(x+(iX*y) >= pixels.length || x+(iX*y) < 0){
			
		}else{
			if(x & 1) color<<=4;
			x/=2;
			pixels[x+(iX*y)]|= color;
		}
		
	}
    /**
	 * Resizes the bitmap.
     * NOTE: It's not for scaling.
	 */
    public void resize(int x, int y){
        pixels.length=x*y;
    }
	///Sets all pixels to 0. (standard transparency index)
	@nogc public void clear(){
		for(int i ; i < pixels.length ; i++)
			pixels[0] = 0;
	}
	/** 
	 * Returns the width of the bitmap
	 */
    @nogc public int getX(){
        return iX;
    }
	/** 
	 * Returns the height of the bitmap
	 */
    @nogc public int getY(){
        return iY;
    }   
	/**
	 * Returns the width of the bitmap.
	 */
	@property public int width(){
		return iX;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	@property public int height(){
		return iY;
	}
	///Generates a standard CollisionModel depending on the pixel transparency.
	public AdvancedBitArray generateStandardCollisionModel(){
		AdvancedBitArray result = new AdvancedBitArray(iX * iY);
		for(int i ; i < iX * iY ; i++){
			ubyte pixel = readPixel(i, 0);
			if(pixel != 0){
				result[i] = true;
			}
		}
		return result;
	}
}

/**
 * 8 bit bitmaps, mainly added for architectures that would favor multiple 256 color CLUTs instead of a single 65536 color one. Stores a pointer to the CLUT alongside the
 * basic image data.
 */
public class Bitmap8Bit{
	private ubyte[] pixels;
	private Color* palettePtr;		///Set this to either a portion of the master palette or to a self-defined place.
    private int iX;
    private int iY;
    ///Creates an empty bitmap.
    this(int x, int y, Color* palettePtr){
        iX=x;
        iY=y;
        pixels.length=x*y;
		this.palettePtr = palettePtr;
    }
    ///Creates a bitmap from an array.
    this(ubyte[] p, int x, int y, Color* palettePtr){
		if (p.length < x * y)
			throw new BitmapFormatException("Incorrect Bitmap size exception!");
        iX=x;
        iY=y;
        pixels=p;
        this.palettePtr = palettePtr;
    }
    ///Returns the pixel at the given position.
    @nogc public ubyte readPixel(int x, int y){

        return pixels[x+(iX*y)];

    }
	///Returns the pointer of the first pixel.
	@nogc public ubyte* getPtr(){
		return pixels.ptr;
	}
	///Sets the palette pointer. Make sure that you set it to a valid memory location.
	@nogc public void setPalettePtr(Color* p){
		palettePtr = p;
	}
	///Returns the palette pointer.
	@nogc public Color* getPalettePtr(){
		return palettePtr;
	}
    ///Writes the pixel at the given position.
    public void writePixel(int x, int y, ubyte color){
		if(x+(iX*y) >= pixels.length || x+(iX*y) < 0){
			
		}else{
			pixels[x+(iX*y)]=color;
		}
		
	}
    /**
	* Resizes the bitmap.
    * NOTE: It's not for scaling.
	*/
    public void resize(int x, int y){
        pixels.length=x*y;
    }
	///Sets all pixels to 0. (standard transparency index)
	@nogc public void clear(){
		for(int i ; i < pixels.length ; i++)
			pixels[0] = 0;
	}
	/** 
	* Returns the width of the bitmap
	*/
    @nogc public int getX(){
        return iX;
    }
	/** 
	* Returns the height of the bitmap
	*/
    @nogc public int getY(){
        return iY;
    }   
	/**
	 * Returns the width of the bitmap.
	 */
	@property public int width(){
		return iX;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	@property public int height(){
		return iY;
	}
	///Generates a standard CollisionModel depending on the pixel transparency.
	public AdvancedBitArray generateStandardCollisionModel(){
		AdvancedBitArray result = new AdvancedBitArray(iX * iY);
		for(int i ; i < iX * iY ; i++){
			if(pixels[i] != 0){
				result[i] = true;
			}
		}
		return result;
	}
	/**
	* Offsets all indexes in the bitmap by a certain value. Keeps zeroth index (usually for transparency) if needed. Useful when converting bitmaps.
	*/
	public void offsetIndexes(ushort offset, bool keepZerothIndex = true){
		for(int i ; i < pixels.length ; i++){
			if(!(pixels[i] == 0 && keepZerothIndex)){
				pixels[i] += offset;
			}
		}
	}
}
/**
 * Uses a 16 bit indexed mode instead of the more common RGB565 or RGBA5551 modes. Generally accesses colors from the master palette.
 */
public class Bitmap16Bit{

	private ushort[] pixels;
	private int iX;
	private int iY;
	///Creates an empty bitmap.
	this(int x, int y){
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
	///Returns the pixel at the given position.
	public ushort readPixel(int x, int y){
		return pixels[x+(iX*y)];
	}
	public deprecated ushort[] readRow(int row){

		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	public deprecated ushort[] readRowReverse(int row){
		row = iY-row-1;
		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	public deprecated ushort[] readChunk(int row, int offsetL, int offsetR){
		return pixels[((iX*row)+offsetL) .. ((iX*row)+iX-offsetR)];
	}
	///Gets the pointer to the first pixel.
	@nogc public ushort* getPtr(){
		return pixels.ptr;
	}
	///Writes the pixel at the given position.
	public void writePixel(int x, int y, ushort color){
		if(x+(iX*y) >= pixels.length || x+(iX*y) < 0){
			/*writeln(x,',',y);
			writeln(pixels.length);*/
		}else{
			pixels[x+(iX*y)]=color;
		}
		
	}
    /**
	* Resizes the bitmap.
    * NOTE: It's not for scaling.
	*/
	public void resize(int x, int y){
		pixels.length=x*y;
	}
   
	@nogc public void clear(){
		for(int i ; i < pixels.length ; i++)
			pixels[0] = 0;
	}
	/** 
	* Returns the width of the bitmap
	*/
	@nogc public int getX(){
		return iX;
	}
	/** 
	* Returns the height of the bitmap
	*/
	@nogc public int getY(){
		return iY;
	}
    //Flips the bitmap.
    /*public void swapX(){
        /*ushort foo;
        for(int i; i<iY; i++){
            for(int j; j<iX/2; j++){
                foo=pixels[j+(iX*i)];
                pixels[j+(iX*i)]=pixels[(iX*i)+iX-j];
                pixels[(iX*i)+iX-j]=foo;
            }
        }
    }
    public void swapY(){
		ushort[] bar;

		for(int y = iY -1 ; y >= 0 ; y--){
			bar ~= readRow(y);
		}
		pixels = bar;
    }*/
	///Generates a standard CollisionModel depending on the pixel transparency.
	public AdvancedBitArray generateStandardCollisionModel(){
		AdvancedBitArray result = new AdvancedBitArray(iX * iY);
		for(int i ; i < iX * iY ; i++){
			if(pixels[i] != 0){
				result[i] = true;
			}
		}
		return result;
	}
	/**
	* Offsets all indexes in the bitmap by a certain value. Keeps zeroth index (usually for transparency) if needed. Useful when converting bitmaps.
	*/
	public void offsetIndexes(ushort offset, bool keepZerothIndex = true){
		for(int i ; i < pixels.length ; i++){
			if(!(pixels[i] == 0 && keepZerothIndex)){
				pixels[i] += offset;
			}
		}
	}
	/**
	 * Returns the width of the bitmap.
	 */
	@property public int width(){
		return iX;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	@property public int height(){
		return iY;
	}
}
/**
 * Directly defines the colors of each pixels as well as their alpha values.
 */
public class Bitmap32Bit{
	//private ubyte[] pixels;
	private Color[] pixels;
	private int iX, iY;

	public this(int x, int y){
		iX = x;
		iY = y;
		pixels.length = x * y;
	}

	public this(Color[] p, int x, int y){
		if (p.length < x * y * 4)
			throw new BitmapFormatException("Incorrect Bitmap size exception!");
		iX = x;
		iY = y;
		this.pixels = p;
	}

	@nogc public Color readPixel(int x, int y){
		
		return pixels[x+(iX*y)];
		
	}
	public Color[] readRow(int row){
		
		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	public Color[] readRowReverse(int row){
		row = iY-row-1;
		return pixels[(iX*row) .. ((iX*row)+iX)];
	}
	/*public ubyte[] readChunk(int row, int offsetL, int offsetR){
		return pixels[((iX*row)+offsetL)*4 .. ((iX*row)+iX-offsetR)*4];
	}*/
	///Writes the pixel at the given position.
	@nogc public void writePixel(int x, int y, Color c){
		//writeln(x * (4 * y * iX));
		pixels[x + (y * iX)] = c;
	}
	/**
	 * Single channel pixel writing.
	 */
	template string(S){
	@nogc public void writePixel(S)(int x, int y, ubyte val){
		static if(S == "alpha"){
			pixels[x + (y * iX)].alpha = val;
		}else static if(S == "red"){
			pixels[x + (y * iX)].alpha = val;
		}else static if(S == "green"){
			pixels[x + (y * iX)].alpha = val;
		}else static if(S == "blue"){
			pixels[x + (y * iX)].alpha = val;
		}else{
			static assert(0, "Template argument '" ~ S ~ "' is not supported by function writePixel(channel)(int x, int y, ubyte val)!");
		}
	}}

	@nogc public Color* getPtr(){
		return pixels.ptr;
	}

	public Color[] getRawdata(){
		return pixels;
	}

	public bool[] generateStandardCollisionModel(){
		bool[] ba;
		for(int i; i < pixels.length; i+=4){
			if(pixels[i].alpha == 0){
				ba ~= false;
			}else{
				ba ~= true;
			}
		}
		return ba;
	}
	//Getters for each sizes.
	@nogc public int getX(){
		return iX;
	}
	@nogc public int getY(){
		return iY;
	}
	/**
	 * Returns the width of the bitmap.
	 */
	@property public int width(){
		return iX;
	}
	/**
	 * Returns the height of the bitmap.
	 */
	@property public int height(){
		return iY;
	}
}
+/