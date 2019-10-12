/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers module
 */
module PixelPerfectEngine.graphics.layers;

public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.graphics.transformFunctions;
import PixelPerfectEngine.system.binarySearchTree;
import PixelPerfectEngine.system.etc;
import std.parallelism;
//import std.container.rbtree;
//import system.etc;
import PixelPerfectEngine.system.exc;
//import std.algorithm;
import bindbc.sdl;
import core.stdc.stdlib;
//import std.range;
import CPUblit.composing;
import CPUblit.colorlookup;
import CPUblit.transform;
import conv = std.conv;

version(LDC){
	import inteli.emmintrin;
}
/// For generating a function out of a template
@nogc void localBlt(uint* src, uint* dest, size_t length){
	blitter(src, dest, length);
}
/**
 * The basis of all layer classes, containing functions for rendering.
 */
abstract class Layer {
	protected @nogc void function(uint* src, uint* dest, size_t length) mainRenderingFunction;		///Used to get around some readability issues. (void* src, void* dest, int length)
	protected @nogc void function(ushort* src, uint* dest, uint* palette, size_t length) mainColorLookupFunction;
	//protected @nogc void function(uint* src, int length) mainHorizontalMirroringFunction;
	protected @nogc void function(ubyte* src, uint* dest, uint* palette, size_t length) main8BitColorLookupFunction;
	protected @nogc void function(ubyte* src, uint* dest, uint* palette, size_t length, int offset) main4BitColorLookupFunction;
	protected LayerRenderingMode renderMode;

	// scrolling position
	protected int sX, sY, rasterX, rasterY;

	/// Sets the main rasterizer
	public void setRasterizer(int rX, int rY){
		//frameBuffer = frameBufferP;
		rasterX=rX;
		rasterY=rY;

	}
	///Sets the rendering mode
	@nogc public void setRenderingMode(LayerRenderingMode mode){
		renderMode = mode;
		switch(mode){
			case LayerRenderingMode.ALPHA_BLENDING:
				//mainRenderingFunction = &alphaBlend;
				mainRenderingFunction = &alphaBlend32bit;
				break;
			case LayerRenderingMode.BLITTER:
				mainRenderingFunction = &localBlt;
				break;
			default:
				mainRenderingFunction = &copy32bit;
		}
		mainColorLookupFunction = &colorLookup!(ushort,uint);
		//mainHorizontalMirroringFunction = &flipHorizontal;
		main8BitColorLookupFunction = &colorLookup!(ubyte,uint);
		main4BitColorLookupFunction = &colorLookup4Bit!uint;
	}
	///Absolute scrolling.
	@nogc @safe public void scroll(int x, int y){
		sX=x;
		sY=y;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	@nogc @safe public void relScroll(int x, int y){
		sX=sX+x;
		sY=sY+y;
	}
	///Getter for the X scroll position.
	@nogc @safe public int getSX(){
		return sX;
	}
	///Getter for the Y scroll position.
	@nogc @safe public int getSY(){
		return sY;
	}
	/// Override this to enable output to the raster
	public abstract void updateRaster(void* workpad, int pitch, Color* palette);
	///Standard algorithm for horizontal mirroring
	///Will be deprecated in later versions and instead external functions will be used.
	@nogc protected void flipHorizontal(uint* src, int length){
		uint s;
		uint* dest = src + length;
		for(int i ; i < length ; i++){
			s = *src;
			*src = *dest;
			*dest = s;
			src++;
			dest--;
		}
	}
}
/**
 * Mostly used for internal communication.
 */
public enum LayerType {
	NULL,
	tile,
	transformableTile,
	sprite,
}
/**
 * Sets the rendering mode of the TileLayer.
 *
 * COPY is the fastest, but overrides any kind of transparency keying. It directly writes into the framebuffer. Should only be used for certain applications, like bottom layers.
 * BLITTER uses a custom BitBlT algorithm for the SSE2 instruction set. Automatically generates the copying mask depending on the alpha-value. Any alpha-value that's non-zero will cause a non-transparent pixel, and all zeros are completely transparent. Gradual transparency in not avaliable.
 * ALPHA_BLENDING uses SSE2 for alpha blending. The slowest (although speed loss might be minimal due to memory access limitation), but allows gradual transparencies.
 */
public enum LayerRenderingMode{
	COPY,			///the fastest, but overrides any kind of transparency keying. It directly writes into the framebuffer. Should only be used for certain applications, like bottom layers.
	BLITTER,		///uses a custom BitBlT algorithm for the SSE2 instruction set. Automatically generates the copying mask depending on the alpha-value. Any alpha-value that's non-zero will cause a non-transparent pixel, and all zeros are completely transparent. Gradual transparency in not avaliable.
	ALPHA_BLENDING	///uses SSE2 for alpha blending. The slowest (although speed loss might be minimal due to memory access limitation), but allows gradual transparencies.
}
/**
 * Tile interface, defines common functions.
 */
public interface ITileLayer{
	public MappingElement[] getMapping();
	/// Reads the mapping element from the given area.
	@nogc public MappingElement readMapping(int x, int y);
	/// Writes the given element into the mapping at the given location.
	@nogc public void writeMapping(int x, int y, MappingElement w);
	/// Loads the mapping, primarily used for deserialization.
	public void loadMapping(int x, int y, MappingElement[] mapping);
	/// Removes the tile from the display list with the given ID.
	public void removeTile(wchar id);
	/// Returns the tile ID from the location by pixel.
	@nogc public MappingElement tileByPixel(int x, int y);
	/// Returns the width of the tiles.
	@nogc public int getTileWidth() pure;
	/// Returns the height of the tiles.
	@nogc public int getTileHeight() pure;
	/// Returns the width of the mapping.
	@nogc public int getMX() pure;
	/// Returns the height of the mapping.
	@nogc public int getMY() pure;
	/// Returns the total width of the tile layer.
	@nogc public int getTX() pure;
	/// Returns the total height of the tile layer.
	@nogc public int getTY() pure;
	/// Adds a tile.
	public void addTile(ABitmap tile, wchar id);
}
/**
 * Universal Mapping element, that is stored on 32 bit.
 */
public struct MappingElement{
	wchar tileID;				///Determines which tile is being used for the given instance
	BitmapAttrib attributes;	///General attributes, such as vertical and horizontal mirroring. The extra 6 bits can be used for various purposes
	ubyte paletteSel;			///Selects the palette for the bitmap if supported
	///Default constructor
	@nogc @safe this(wchar tileID, BitmapAttrib attributes = BitmapAttrib(false, false)){
		this.tileID = tileID;
		this.attributes = attributes;
	}
	public string toString() const {
		import std.conv : to;
		return "[tileID:" ~ to!string(cast(int)tileID) ~ "; attributes:" ~ attributes.toString ~ "; paletteSel:" ~
				to!string(paletteSel) ~ "]";
	}
}

/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Can use any kind of bitmaps thanks to code restructuring.
 */
public class TileLayer : Layer, ITileLayer{
	/**
	 * Implements a single tile to be displayed.
	 * Is ordered in a BinarySearchTree for fast lookup.
	 */
	protected struct DisplayListItem{
		ABitmap tile;			///reference counting only
		void* pixelDataPtr;		///points to the pixeldata
		//Color* palettePtr;		///points to the palette if present
		wchar ID;				///ID, mainly as a padding to 32 bit alignment
		ubyte wordLength;		///to avoid calling the more costly classinfo
		ubyte reserved;		///currently unused
		///Default ctor
		this(wchar ID, ABitmap tile){
			//palettePtr = tile.getPalettePtr();
			//this.paletteSel = paletteSel;
			this.ID = ID;
			this.tile=tile;
			if(tile.classinfo == typeid(Bitmap4Bit)){
				wordLength = 4;
				pixelDataPtr = (cast(Bitmap4Bit)(tile)).getPtr;
			}else if(tile.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelDataPtr = (cast(Bitmap8Bit)(tile)).getPtr;
			}else if(tile.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelDataPtr = (cast(Bitmap16Bit)(tile)).getPtr;
			}else if(tile.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelDataPtr = (cast(Bitmap32Bit)(tile)).getPtr;
			}else{
				throw new TileFormatException("Bitmap format not supported!");
			}
		}
	}
	protected int tileX;	///Tile width
	protected int tileY;	///Tile height
	protected int mX;		///Map width
	protected int mY;		///Map height
	protected int totalX;	///Total width of the tilelayer in pixels
	protected int totalY;	///Total height of the tilelayer in pixels
	protected MappingElement[] mapping;///Contains the mapping data
	//private wchar[] mapping;
	//private BitmapAttrib[] tileAttributes;
	protected Color[] src;		///Local buffer
	protected BinarySearchTree!(wchar, DisplayListItem) displayList;	///displaylist using a BST to allow skipping elements
	protected bool warpMode;
	///Emulates horizontal blanking interrupt effects, like per-line scrolling.
	///line no -1 indicates that no lines have been drawn yet.
	public @nogc  void delegate(int line, ref int sX0, ref int sY0) hBlankInterrupt;
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
		src.length = tileX;
	}
	/// Warpmode: if enabled, the layer will be turned into an "infinite" mode.
	public void setWarpMode(bool w){
		warpMode = w;
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	@nogc public MappingElement readMapping(int x, int y){
		if(!warpMode){
			if(x < 0 || y < 0 || x >= mX || y >= mY){
				return MappingElement(0xFFFF);
			}
		}else{
			x = x % mX;
			y = y % mY;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, MappingElement w){
		mapping[x+(mX*y)]=w;
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	/*@nogc public void writeTileAttribute(int x, int y, BitmapAttrib ba){
		tileAttributes[x+(mX*y)]=ba;
	}*/
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping){
		mX=x;
		mY=y;
		this.mapping = mapping;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(ABitmap tile, wchar id){
		if(tile.width==tileX && tile.height==tileY){
			displayList[id]=DisplayListItem(id, tile);
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		displayList.remove(id);
	}
	///Returns which tile is at the given pixel
	@nogc public MappingElement tileByPixel(int x, int y){
		if(!warpMode && (x < 0 || y < 0)) return MappingElement(0xFFFF);
		x /= tileX;
		y /= tileY;
		if(warpMode){
			x %= mX;
			y %= mY;
		}
		if(x >= mX || y >= mY) return MappingElement(0xFFFF);
		return mapping[x + y*mX];
	}

	public @nogc override void updateRaster(void* workpad, int pitch, Color* palette){
		int sX0 = sX, sY0 = sY;
		if (hBlankInterrupt !is null)
			hBlankInterrupt(-1, sX0, sY0);

		for (int line  ; line < rasterY ; line++) {
			if (hBlankInterrupt !is null)
				hBlankInterrupt(line, sX0, sY0);
			if ((sY0 >= 0 && sY0 < totalY) || warpMode) {
				int sXAbs = warpMode ? sX0 & int.max : sX0, sYAbs = sY0 & int.max;
				const sizediff_t offsetP = line * pitch;	// The offset of the line that is being written
				void* w0 = workpad + offsetP;
				const int offsetY = sYAbs % tileY;		//Offset of the current line of the tiles in this line
				const int offsetX0 = tileX - ((sXAbs + rasterX) % tileX);		//Scroll offset of the rightmost column
				const int offsetX = (sXAbs & int.max) % tileX;		//Scroll offset of the leftmost column
				int tileXLength = offsetX ? tileX - offsetX : tileX;
				for (int col ; col < rasterX ; ) {
					const MappingElement currentTile = tileByPixel(sXAbs, sYAbs);
					if (currentTile.tileID != 0xFFFF) {
						const DisplayListItem tileInfo = displayList[currentTile.tileID];
						const int offsetX1 = col ? 0 : offsetX;
						const int offsetY0 = currentTile.attributes.vertMirror ? tileY - offsetY : offsetY;
						if (col + tileXLength > rasterX) {
							tileXLength -= offsetX0;
						}
						final switch (tileInfo.wordLength) {
							case 4:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + (offsetX1 + (offsetY0 * tileX)>>>1);
								main4BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + (currentTile.paletteSel<<4),
										tileXLength, offsetX1 & 1);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength);
								break;
							case 8:
								ubyte* tileSrc = cast(ubyte*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								main8BitColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette) + (currentTile.paletteSel<<8), tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength);
								break;
							case 16:
								ushort* tileSrc = cast(ushort*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								mainColorLookupFunction(tileSrc, cast(uint*)src, (cast(uint*)palette), tileXLength);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength);
								break;
							case 32:
								Color* tileSrc = cast(Color*)tileInfo.pixelDataPtr + offsetX1 + (offsetY0 * tileX);
								if(!currentTile.attributes.horizMirror) {
									mainRenderingFunction(cast(uint*)tileSrc,cast(uint*)w0,tileXLength);
								} else {
									CPUblit.composing.copy32bit(cast(uint*)tileSrc, cast(uint*)src, tileXLength);
									flipHorizontal(cast(uint*)src.ptr, tileX);
									mainRenderingFunction(cast(uint*)src,cast(uint*)w0,tileXLength);
								}
								break;

						}

					}
					sXAbs += tileXLength;
					col += tileXLength;
					w0 += tileXLength<<2;

					tileXLength = tileX;
				}
			}
			sY0++;
		}
	}
	public MappingElement[] getMapping(){
		return mapping;
	}
	@nogc public int getTileWidth() pure{
		return tileX;
	}
	@nogc public int getTileHeight() pure{
		return tileY;
	}
	@nogc public int getMX() pure{
		return mX;
	}
	@nogc public int getMY() pure{
		return mY;
	}
	@nogc public int getTX() pure{
		return totalX;
	}
	@nogc public int getTY() pure{
		return totalY;
	}
}
/**
 * Implements a modified TileLayer with transformability with capabilities similar to MODE7.
 * <br/>
 * Transform function:
 * [x',y'] = ([A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])>>>8 + [x_0,y_0]
 * <br/>
 * All basic transform values are integer based, 256 equals with 1.0
 * <br/>
 * Restrictions compared to standard TileLayer:
 * <ul>
 * <li>Tiles must have any of the following sizes: 8, 16, 32, 64; since this layer needs to do modulo computations for each pixel.</li>
 * <li>Maximum layer size in pixels are restricted to 65536*65536 due to architectural limitations. Accelerated versions might raise
 * this limitation.</li>
 * </ul>
 * HDMA emulation supported through delegate hBlankInterrupt.
 */
public class TransformableTileLayer(BMPType = Bitmap16Bit, int TileX = 8, int TileY = 8) : Layer, ITileLayer{
		/*if(isPowerOf2(TileX) && isPowerOf2(TileY))*/
	protected struct DisplayListItem{
		void* pixelSrc;		///Used for quicker access to the Data
		wchar ID;			///ID, mainly used as a padding
		ushort reserved;	///Padding for 32 bit
		this(wchar ID, BMPType tile){
			this.ID = ID;
			pixelSrc = cast(void*)tile.getPtr();
		}
	}
	protected BinarySearchTree!(wchar, DisplayListItem) displayList;
	protected short[4] transformPoints;	/** Defines how the layer is being transformed */
	protected short[2] tpOrigin;
	protected Bitmap32Bit backbuffer;	///used to store current screen output
	/*static if(BMPType.mangleof == Bitmap8Bit.mangleof){
		protected ubyte[] src;
		protected Color* palettePtr;	///Shared palette
	}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
		protected ushort[] src;*/
	static if(BMPType.mangleof == Bitmap4Bit.mangleof || BMPType.mangleof == Bitmap8Bit.mangleof ||
			BMPType.mangleof == Bitmap16Bit.mangleof){
		protected ushort[] src;
	}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){

	}else static assert(false,"Template parameter " ~ BMPType.mangleof ~ " not supported by TransformableTileLayer!");
	protected bool needsUpdate;			///Set to true if backbuffer needs an update
	protected bool warpMode;			///Repeats the whole layer if set to true
	protected int mX, mY;				///"Inherited" from TileLayer
	static if(TileX == 8)
		protected immutable int shiftX = 3;
	else static if(TileX == 16)
		protected immutable int shiftX = 4;
	else static if(TileX == 32)
		protected immutable int shiftX = 5;
	else static if(TileX == 64)
		protected immutable int shiftX = 6;
	else static assert(false,"Unsupported horizontal tile size!");
	static if(TileY == 8)
		protected immutable int shiftY = 3;
	else static if(TileY == 16)
		protected immutable int shiftY = 4;
	else static if(TileY == 32)
		protected immutable int shiftY = 5;
	else static if(TileY == 64)
		protected immutable int shiftY = 6;
	else static assert(false,"Unsupported vertical tile size!");
	protected int totalX, totalY;
	protected MappingElement[] mapping;
	version(LDC){
		protected int4 _tileAmpersand;
		protected static short8 _increment;
	}
	alias HBIDelegate = @nogc void delegate(ref short[4] localABCD, ref short[2] localsXsY, ref short[2] localx0y0, short y);
	/**
	 * Called before each line being redrawn. Can modify global values for each lines.
	 */
	public HBIDelegate hBlankInterrupt;

	this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		A = 256;
		B = 0;
		C = 0;
		D = 256;
		x_0 = 0;
		y_0 = 0;
		_tileAmpersand = [TileX - 1, TileY - 1, TileX - 1, TileY - 1];
		setRenderingMode(renderMode);
		needsUpdate = true;
	}
	static this(){
		for(int i ; i < 8 ; i+=2)
			_increment[i] = 2;
	}
	override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
		backbuffer = new Bitmap32Bit(rX, rY);
		static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
			src.length = rX;
		}
	}

	override public @nogc void updateRaster(void* workpad,int pitch,Color* palette) {
		//import core.stdc.stdio;
		if(needsUpdate){
			needsUpdate = false;
			//clear buffer
			//backbuffer.clear();
			Color* dest = backbuffer.getPtr();
			short[2] sXsY = [cast(short)sX,cast(short)sY];
			short[4] localTP = transformPoints;
			short[2] localTPO = tpOrigin;
			//write new data into it
			for(short y; y < rasterY; y++){
				if(hBlankInterrupt !is null){
					hBlankInterrupt(localTP, sXsY, localTPO, y);
				}
				version(DMD){
					for(short x; x < rasterX; x++){
						int[2] xy = transformFunctionInt([x,y], localTP, localTPO, sXsY);
						//printf("[%i,%i]",xy[0],xy[1]);
						MappingElement currentTile = tileByPixelWithoutTransform(xy[0],xy[1]);
						if(currentTile.tileID != 0xFFFF){
							const DisplayListItem d = displayList[currentTile.tileID];
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							xy[0] = xy[0] & (TileX - 1);
							xy[1] = xy[1] & (TileY - 1);
							const int totalOffset = xy[0] + xy[1] * TileX;
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = (totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | currentTile.paletteSel<<4;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof ){
								src[x] = tsrc[totalOffset] | currentTile.paletteSel<<8;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = tsrc[totalOffset];
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
									BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
					}
				}else version(LDC){
					/*short8 _sXsY = [sXsY[0],sXsY[1],sXsY[0],sXsY[1],sXsY[0],sXsY[1],sXsY[0],sXsY[1]],
							_localTP = [localTP[0], localTP[1],localTP[2], localTP[3], localTP[0], localTP[1],localTP[2], localTP[3]],
							_localTPO = [localTPO[0],localTPO[1],localTPO[0],localTPO[1],localTPO[0],localTPO[1],localTPO[0],localTPO[1]];
					int4 _localTPO_0 = [localTPO[0],localTPO[1],localTPO[0],localTPO[1]];*/
					short8 _sXsY, _localTP, _localTPO;
					for(int i; i < 8; i++){
						_sXsY[i] = sXsY[i & 1];
						_localTP[i] = localTP[i & 3];
						_localTPO[i] = localTPO[i & 1];
					}
					short8 xy_in;
					for(int i = 1; i < 8; i += 2){
						xy_in[i] = y;
					}
					xy_in[4] = 1;
					xy_in[6] = 1;
					int4 _localTPO_0;
					for(int i; i < 4; i++){
						_localTPO_0[i] = localTPO[i & 1];
					}
					for(short x; x < rasterX; x++){
						int4 xy = _mm_srai_epi32(_mm_madd_epi16(_localTP, xy_in + _sXsY - _localTPO),8) + _localTPO_0;
						MappingElement currentTile0 = tileByPixelWithoutTransform(xy[0],xy[1]),
								currentTile1 = tileByPixelWithoutTransform(xy[2],xy[3]);
						xy &= _tileAmpersand;
						if(currentTile0.tileID != 0xFFFF){
							const DisplayListItem d = displayList[currentTile0.tileID];
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							xy[0] = xy[0] & (TileX - 1);
							xy[1] = xy[1] & (TileY - 1);
							const int totalOffset = xy[0] + xy[1] * TileX;
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = (totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | currentTile0.paletteSel<<4;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof ){
								src[x] = tsrc[totalOffset] | currentTile0.paletteSel<<8;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = tsrc[totalOffset];
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
									BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
						x++;
						if(currentTile1.tileID != 0xFFFF){
							const DisplayListItem d = displayList[currentTile1.tileID];
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							xy[2] = xy[2] & (TileX - 1);
							xy[3] = xy[3] & (TileY - 1);
							const int totalOffset = xy[2] + xy[3] * TileX;
							static if(BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = (totalOffset & 1 ? tsrc[totalOffset>>1]>>4 : tsrc[totalOffset>>1] & 0x0F) | currentTile1.paletteSel<<4;
							}else static if(BMPType.mangleof == Bitmap8Bit.mangleof ){
								src[x] = tsrc[totalOffset] | currentTile1.paletteSel<<8;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = tsrc[totalOffset];
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof ||
									BMPType.mangleof == Bitmap4Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
						xy_in += _increment;

					}
				}else static assert(false, "Compiler not supported");
				/*static if(BMPType.mangleof == Bitmap8Bit.mangleof){
					main8BitColorLookupFunction(src.ptr, cast(uint*)dest, cast(uint*)palettePtr, rasterX);
					dest += rasterX;
				}else*/ static if(BMPType.mangleof == Bitmap4Bit.mangleof || BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
					mainColorLookupFunction(src.ptr, cast(uint*)dest, cast(uint*)palette, rasterX);
					dest += rasterX;
				}
			}
		}
		//render surface onto the raster
		void* p0 = workpad;
		Color* c = backbuffer.getPtr();
		for(int y; y < rasterY; y++){
			mainRenderingFunction(cast(uint*)c,cast(uint*)p0,rasterX);
			c += rasterX;
			p0 += pitch;
		}

	}
	///Returns which tile is at the given pixel
	@nogc public MappingElement tileByPixel(int x, int y){
		int[2] xy = transformFunctionInt([cast(short)x,cast(short)y],transformPoints,tpOrigin,[cast(short)sX,cast(short)sY]);
		return tileByPixelWithoutTransform(xy[0],xy[1]);
	}
	///Returns which tile is at the given pixel
	@nogc protected MappingElement tileByPixelWithoutTransform(int x, int y){
		x >>>= shiftX;
		y >>>= shiftY;
		if(warpMode){
			x %= mX;
			y %= mY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return MappingElement(0xFFFF);
		return mapping[x + y*mX];
	}

	/**
	 * Horizontal scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property short A(){
		return transformPoints[0];
	}
	/**
	 * Horizontal shearing.
	 */
	public @nogc @property short B(){
		return transformPoints[1];
	}
	/**
	 * Vertical shearing.
	 */
	public @nogc @property short C(){
		return transformPoints[2];
	}
	/**
	 * Vertical scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property short D(){
		return transformPoints[3];
	}
	/**
	 * Horizontal transformation offset.
	 */
	public @nogc @property short x_0(){
		return tpOrigin[0];
	}
	/**
	 * Vertical transformation offset.
	 */
	public @nogc @property short y_0(){
		return tpOrigin[1];
	}
	/**
	 * Horizontal scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property short A(short newval){
		transformPoints[0] = newval;
		needsUpdate = true;
		return transformPoints[0];
	}
	/**
	 * Horizontal shearing.
	 */
	public @nogc @property short B(short newval){
		transformPoints[1] = newval;
		needsUpdate = true;
		return transformPoints[1];
	}
	/**
	 * Vertical shearing.
	 */
	public @nogc @property short C(short newval){
		transformPoints[2] = newval;
		needsUpdate = true;
		return transformPoints[2];
	}
	/**
	 * Vertical scaling. Greater than 256 means zooming in, less than 256 means zooming out.
	 */
	public @nogc @property short D(short newval){
		transformPoints[3] = newval;
		needsUpdate = true;
		return transformPoints[3];
	}
	/**
	 * Horizontal transformation offset.
	 */
	public @nogc @property short x_0(short newval){
		tpOrigin[0] = newval;
		//tpOrigin[2] = newval;
		needsUpdate = true;
		return tpOrigin[0];
	}
	/**
	 * Vertical transformation offset.
	 */
	public @nogc @property short y_0(short newval){
		tpOrigin[1] = newval;
		//tpOrigin[3] = newval;
		needsUpdate = true;
		return tpOrigin[1];
	}
	override public @safe @nogc void scroll(int x,int y) {
		super.scroll(x,y);
		needsUpdate = true;
	}
	override public @safe @nogc void relScroll(int x,int y) {
		super.relScroll(x,y);
		needsUpdate = true;
	}
	public MappingElement[] getMapping(){
		return mapping;
	}
	@nogc public int getTileWidth() pure{
		return TileX;
	}
	@nogc public int getTileHeight() pure{
		return TileY;
	}
	@nogc public int getMX() pure{
		return mX;
	}
	@nogc public int getMY() pure{
		return mY;
	}
	@nogc public int getTX() pure{
		return totalX;
	}
	@nogc public int getTY() pure{
		return totalY;
	}
	/// Warpmode: if enabled, the layer will be turned into an "infinite" mode.
	public void setWarpMode(bool w){
		warpMode = w;
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	@nogc public MappingElement readMapping(int x, int y){
		if(!warpMode){
			if(x < 0 || y < 0 || x >= mX || y >= mY){
				return MappingElement(0xFFFF);
			}
		}else{
			x = x % mX;
			y = y % mY;
		}
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, MappingElement w){
		mapping[x+(mX*y)]=w;
	}
	public void addTile(ABitmap tile, wchar id){
		if(tile.classinfo != typeid(BMPType)){
			throw new TileFormatException("Incorrect type of tile!");
		}
		if(tile.width == TileX && tile.height == TileY){
			displayList[id]=DisplayListItem(id, cast(BMPType)tile);
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		displayList.remove(id);
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, MappingElement[] mapping){
		mX=x;
		mY=y;
		this.mapping = mapping;
		totalX=mX*TileX;
		totalY=mY*TileY;
	}
}
/**
 *Used by the collision detectors
 *DEPRECATED! Use the new system instead!
 */
public interface ISpriteCollision{
	///Returns all sprite coordinates.
	public ref Coordinate[int] getCoordinates();
	///Returns all sprite attributes.
	public ref BitmapAttrib[int] getSpriteAttributes();
	public ref int[] getSpriteSorter();

}
/**
 *General SpriteLayer interface.
 */
public interface ISpriteLayer{
	///Removes the sprite with the given ID.
	public void removeSprite(int n);
	///Moves the sprite to the given location.
	public @nogc void moveSprite(int n, int x, int y);
	///Relatively moves the sprite by the given values.
	public @nogc void relMoveSprite(int n, int x, int y);
	///Gets the coordinate of the sprite.
	public Coordinate getSpriteCoordinate(int n);
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, Coordinate c, ushort paletteSel = 0, int scaleHoriz = 1024, int scaleVert = 1024);
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, int scaleVert = 1024);
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(ABitmap s, int n);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, int x, int y);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, Coordinate c);
	///Edits a sprite attribute.
	public void editSpriteAttribute(string S, T)(int n, T value);
	///Reads a sprite attribute
	public T readSpriteAttribute(string S, T)(int n);
	///Replaces a sprite attribute. DEPRECATED
	public void replaceSpriteAttribute(int n, BitmapAttrib attr);
	///Returns the displayed portion of the sprite.
	public @nogc Coordinate getSlice(int n);
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns the old one.
	public @nogc Coordinate setSlice(int n, Coordinate slice);
	///Returns the selected paletteID of the sprite.
	public @nogc ushort getPaletteID(int n);
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen
	public @nogc ushort setPaletteID(int n, ushort paletteID);
	///Scales bitmap horizontally
	public @nogc int scaleSpriteHoriz(int n, int hScl);
	///Scales bitmap vertically
	public @nogc int scaleSpriteVert(int n, int vScl);
}
/**
 *Use it to call the collision detector
 *DEPRECATED!
 */
public interface SpriteMovementListener{
	///Called when a sprite is moved.
	void spriteMoved(int ID);
}
/**
 * General-purpose sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteLayer{
	/**
	 * Helps to determine the displaying properties and order of sprites.
	 */
	public struct DisplayListItem{
		Coordinate position;		/// Stores the position relative to the origin point. Actual display position is determined by the scroll positions.
		Coordinate slice;			/// To compensate for the lack of scanline interrupt capabilities, this enables chopping off parts of a sprite.
		//ABitmap sprite;				/// Defines the sprite being displayed on the screen.
		void* pixelData;			/// Points to the pixel data.
		//Color* palette;
		int width;					/// Width of the sprite
		int height;					/// Height of the sprite
		int scaleHoriz;				/// Horizontal scaling
		int scaleVert;				/// Vertical scaling
		int priority;				/// Used for automatic sorting and identification.
		BitmapAttrib attributes;	/// Horizontal and vertical mirroring. DEPRECATED
		ubyte wordLength;			/// Determines the word length of a sprite in a much quicker way than getting classinfo.
		/**
		 * Selects the palette of the sprite (Bitmap4Bit: 4096X16 color palettes; Bitmap8Bit: 256X256 color palettes)
		 */
		ushort paletteSel;
		this(Coordinate position, ABitmap sprite, int priority, ushort paletteSel = 0, int scaleHoriz = 1024,
				int scaleVert = 1024){
			this.position = position;
			this.width = sprite.width;
			this.height = sprite.height;
			this.priority = priority;
			this.paletteSel = paletteSel;
			this.scaleVert = scaleVert;
			this.scaleHoriz = scaleHoriz;
			slice = Coordinate(0,0,sprite.width,sprite.height);
			if(sprite.classinfo == typeid(Bitmap4Bit)){
				wordLength = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		this(Coordinate position, Coordinate slice, ABitmap sprite, int priority, int scaleHoriz = 1024,
				int scaleVert = 1024){
			this.position = position;
			//this.sprite = sprite;
			//palette = sprite.getPalettePtr();
			this.priority = priority;
			//this.attributes = attributes;
			this.scaleVert = scaleVert;
			this.scaleHoriz = scaleHoriz;
			if(slice.top < 0)
				slice.top = 0;
			if(slice.left < 0)
				slice.left = 0;
			if(slice.right >= sprite.width)
				slice.right = sprite.width - 1;
			if(slice.bottom >= sprite.height)
				slice.bottom = sprite.height - 1;
			this.slice = slice;
			if(sprite.classinfo == typeid(Bitmap4Bit)){
				wordLength = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
				//palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
				//palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		/**
		 * Resets the slice to its original position.
		 */
		@nogc void resetSlice(){
			slice.left = 0;
			slice.top = 0;
			slice.right = position.width;
			slice.bottom = position.height;
		}
		/**
		 * Replaces the sprite with a new one.
		 * If the sizes are mismatching, the top-left coordinates are left as is, but the slicing is reset.
		 */
		void replaceSprite(ABitmap sprite){
			//this.sprite = sprite;
			//palette = sprite.getPalettePtr();
			if(this.width != sprite.width || this.height != sprite.height){
				this.width = sprite.width;
				this.height = sprite.height;
				position.right = position.left + cast(int)scaleNearestLength(width, scaleHoriz);
				position.bottom = position.top + cast(int)scaleNearestLength(height, scaleVert);
			}
			resetSlice();
			if(sprite.classinfo == typeid(Bitmap4Bit)){
				wordLength = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
				//palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
				//palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		@nogc int opCmp(in DisplayListItem d) const{
			return priority - d.priority;
		}
		@nogc bool opEquals(in DisplayListItem d) const{
			return priority == d.priority;
		}
		string toString() const{
			return "[Position: " ~ position.toString ~ ";\nDisplayed portion: " ~ slice.toString ~";\nPriority" ~
				conv.to!string(priority) ~ "; PixelData: " ~ conv.to!string(pixelData) ~ "; Attributes: " ~ attributes.toString ~
				"; PaletteSel: " ~ conv.to!string(paletteSel) ~ "; WordLenght: " ~ conv.to!string(wordLength) ~ "]";
		}
	}
	protected DisplayListItem[] displayList;	///Stores the display data
	Color[2048] src;							///Local buffer for scaling
	//size_t[8] prevSize;

	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		setRenderingMode(renderMode);
		//src[0].length = 1024;
	}
	/+~this(){
		foreach(p; src){
			if(p)
				free(p);
		}
	}+/
	override public void setRasterizer(int rX,int rY) {
		super.setRasterizer(rX,rY);
		/+for(int i; i < src.length; i++){
			src[i].length=rY;
		}+/
		//src.length = rY;
	}
	///Returns the displayed portion of the sprite.
	public @nogc Coordinate getSlice(int n){
		for(int i ; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				return displayList[i].slice;
			}
		}
		return Coordinate(0,0,0,0);
	}
	///Writes the displayed portion of the sprite.
	///Returns the new slice, if invalid (greater than the bitmap, etc.) returns the old one.
	public @nogc Coordinate setSlice(int n, Coordinate slice){
		for(int i ; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				//test if inputted slice is valid
				if(slice.top >= 0 && slice.bottom >= 0 && slice.left >= 0 && slice.right >= 0 && slice.top <= slice.bottom &&
						slice.left <= slice.right && slice.width <= displayList[i].slice.width && slice.height <=
						displayList[i].slice.height){
					displayList[i].slice = slice;
				}
				return displayList[i].slice;
			}
		}
		return Coordinate(0,0,0,0);
	}
	///Returns the selected paletteID of the sprite.
	public @nogc ushort getPaletteID(int n){
		for(int i ; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				return displayList[i].paletteSel;
			}
		}
		return 0;
	}
	///Sets the paletteID of the sprite. Returns the new ID, which is truncated to the possible values with a simple binary and operation
	///Palette must exist in the parent Raster, otherwise AccessError might happen
	public @nogc ushort setPaletteID(int n, ushort paletteID){
		for(int i ; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				if(displayList[i].wordLength == 4){
					displayList[i].paletteSel = paletteID & 0x0F_FF;
				}else if(displayList[i].wordLength == 8){
					displayList[i].paletteSel = paletteID & 0x00_FF;
				}
				return displayList[i].paletteSel;
			}
		}
		return 0;
	}

	public void addSprite(ABitmap s, int n, Coordinate c, ushort paletteSel = 0, int scaleHoriz = 1024, int scaleVert = 1024){
		import std.algorithm.sorting;
		import std.algorithm.searching;
		DisplayListItem d = DisplayListItem(c, s, n, paletteSel, scaleHoriz, scaleVert);
		if(canFind(displayList, d)){
			throw new SpritePriorityException("Sprite number already exists!");
		}else{
			displayList ~= d;
			displayList.sort!"a > b"();
		}
	}

	public void addSprite(ABitmap s, int n, int x, int y, ushort paletteSel = 0, int scaleHoriz = 1024, int scaleVert = 1024){
		import std.algorithm.sorting;
		import std.algorithm.searching;
		Coordinate c = Coordinate(x,y,x+s.width,y+s.height);
		DisplayListItem d = DisplayListItem(c, s, n, paletteSel, scaleHoriz, scaleVert);
		if(canFind(displayList, d)){
			throw new SpritePriorityException("Sprite number already exists!");
		}else{
			displayList ~= d;
			displayList.sort!"a > b"();
		}
	}
	public void editSpriteAttribute(string S, T)(int n, T value){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				mixin("displayList[i]."~S~" = value;");
				return;
			}
		}
	}
	///Reads a sprite attribute
	public T readSpriteAttribute(string S, T)(int n){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				mixin("return displayList[i]."~S~";");
			}
		}
		return T.init;
	}
	public void replaceSpriteAttribute(int n, BitmapAttrib attr){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].attributes = attr;
				return;
			}
		}
	}
	public void replaceSprite(ABitmap s, int n){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].replaceSprite(s);
				return;
			}
		}
	}

	public void replaceSprite(ABitmap s, int n, int x, int y){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].replaceSprite(s);
				return;
			}
		}
	}

	public void replaceSprite(ABitmap s, int n, Coordinate c){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].replaceSprite(s);
				return;
			}
		}
	}

	/*public ushort getTransparencyIndex(){
		return transparencyIndex;
	}*/

	public void removeSprite(int n){
		DisplayListItem[] ndl;
		ndl.reserve(displayList.length);
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority != n){
				ndl ~= displayList[i];
			}
		}
		displayList = ndl;
	}
	public @nogc void moveSprite(int n, int x, int y){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].position.move(x,y);
				return;
			}
		}
	}
	public @nogc void relMoveSprite(int n, int x, int y){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].position.relMove(x,y);
				return;
			}
		}
	}

	public @nogc Coordinate getSpriteCoordinate(int n){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				return displayList[i].position;
			}
		}
		return Coordinate(0,0,0,0);
	}
	///Scales sprite horizontally. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public @nogc int scaleSpriteHoriz(int n, int hScl){
		if (!hScl) return -1;
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].scaleHoriz = hScl;
				const int newWidth = cast(int)scaleNearestLength(displayList[i].width, hScl);
				displayList[i].slice.right = newWidth;
				return displayList[i].position.right = displayList[i].position.left + newWidth;
			}
		}
		return -2;
	}
	///Scales sprite vertically. Returns the new size, or -1 if the scaling value is invalid, or -2 if spriteID not found.
	public @nogc int scaleSpriteVert(int n, int vScl){
		if (!vScl) return -1;
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].scaleVert = vScl;
				const int newHeight = cast(int)scaleNearestLength(displayList[i].height, vScl);
				displayList[i].slice.bottom = newHeight;
				return displayList[i].position.bottom = displayList[i].position.top + newHeight;
			}
		}
		return -2;
	}

	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette){
		foreach(i ; displayList){
			const int left = i.position.left + i.slice.left;
			const int top = i.position.top + i.slice.top;
			const int right = i.position.left + i.slice.right;
			const int bottom = i.position.top + i.slice.bottom;
			/+if((i.position.right > sX && i.position.bottom > sY) && (i.position.left < sX + rasterX && i.position.top < sY +
					rasterY)){+/
			if((right > sX && left < sX + rasterX) && (bottom > sY && top < sY + rasterY) && i.slice.width && i.slice.height){
				int offsetXA = sX > left ? sX - left : 0;//Left hand side offset, zero if not obscured
				const int offsetXB = sX + rasterX < right ? right - rasterX : 0; //Right hand side offset, zero if not obscured
				const int offsetYA = sY > top ? sY - top : 0;		//top offset of sprite, zero if not obscured
				const int offsetYB = sY + rasterY < bottom ? bottom - rasterY : 0;	//bottom offset of sprite, zero if not obscured
				//const int offsetYB0 = cast(int)scaleNearestLength(offsetYB, i.scaleVert);
				const int sizeX = i.slice.width();		//total displayed width
				const int offsetX = left - sX;
				const int length = sizeX - offsetXA - offsetXB;
				//int lengthY = i.slice.height - offsetYA - offsetYB;
				//const int lfour = length * 4;
				const int offsetY = sY < top ? (top-sY)*pitch : 0;	//used if top portion of the sprite is off-screen
				//offset = i.scaleVert % 1024;
				const int scaleVertAbs = i.scaleVert * (i.scaleVert < 0 ? -1 : 1);	//absolute value of vertical offset, used in various calculations
				//int offset, prevOffset;
				const int offsetAmount = scaleVertAbs <= 1024 ? 1024 : scaleVertAbs;	//used to limit the amount of re-rendering every line
				//offset = offsetYA<<10;
				const int offsetYA0 = cast(int)(cast(double)offsetYA / (1024.0 / cast(double)scaleVertAbs));	//amount of skipped lines (I think) TODO: remove floating-point arithmetic
				const int sizeXOffset = i.width * (i.scaleVert < 0 ? -1 : 1);
				int prevOffset = offsetYA0 * offsetAmount;		//
				int offset = offsetYA0 * scaleVertAbs;
				const size_t p0offset = (i.scaleHoriz > 0 ? offsetXA : offsetXB); //determines offset based on mirroring
				const int scalelength = i.position.width < 2048 ? i.width : 2048;	//limit width to 2048, the minimum required for this scaling method to work
				void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
				switch(i.wordLength){
					case 4:
						ubyte* p0 = cast(ubyte*)i.pixelData + i.width * ((i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0)>>1);
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
							horizontalScaleNearest4BitAndCLU(p0, src.ptr, palette + (i.paletteSel<<4), scalelength, offsetXA & 1,
									i.scaleHoriz);
							prevOffset += offsetAmount;
							for(; offset < prevOffset; offset += scaleVertAbs){
								y++;
								mainRenderingFunction(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length);
								dest += pitch;
							}
							p0 += sizeXOffset >>> 1;
						}
						//}
						break;
					case 8:
						ubyte* p0 = cast(ubyte*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
							horizontalScaleNearestAndCLU(p0, src.ptr, palette + (i.paletteSel<<8), scalelength, i.scaleHoriz);
							prevOffset += 1024;
							for(; offset < prevOffset; offset += scaleVertAbs){
								y++;
								mainRenderingFunction(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length);
								dest += pitch;
							}
							p0 += sizeXOffset;
						}
						break;
					case 16:
						ushort* p0 = cast(ushort*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
							horizontalScaleNearestAndCLU(p0, src.ptr, palette, scalelength, i.scaleHoriz);
							prevOffset += 1024;
							for(; offset < prevOffset; offset += scaleVertAbs){
								y++;
								mainRenderingFunction(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length);
								dest += pitch;
							}
							p0 += sizeXOffset;
						}
						break;
					case 32:
						Color* p0 = cast(Color*)i.pixelData + i.width * (i.scaleVert < 0 ? (i.height - offsetYA0 - 1) : offsetYA0);
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; ){
							horizontalScaleNearest(p0, src.ptr, scalelength, i.scaleHoriz);
							prevOffset += 1024;
							for(; offset < prevOffset; offset += scaleVertAbs){
								y++;
								mainRenderingFunction(cast(uint*)src.ptr + p0offset, cast(uint*)dest, length);
								dest += pitch;
							}
							p0 += sizeXOffset;
						}
						//}
						break;
					default:
						break;
				}

			}
		}
		//foreach(int threadOffset; threads.parallel)
			//free(src[threadOffset]);
	}

}
/**
 * Puts various effects on the framebuffer (XOR blitter, etc).
 */
public class EffectLayer : Layer{
	/**
	 * Stores various commands for effects
	 */
	public class EffectLayerCommand{
		public CommandType command;
		public Coordinate[] coordinates;
		public Color[] colors;
		public ushort[] indexedColors;
		public int[] values;
		public this(CommandType command, Coordinate[] coordinates, Color[] colors, int[] values = null){
			this.command = command;
			this.coordinates = coordinates;
			this.indexedColors = null;
			this.colors = colors;
			this.values = values;
		}
		public this(CommandType command, Coordinate[] coordinates, ushort[] indexedColors, int[] values = null){
			this.command = command;
			this.coordinates = coordinates;
			this.indexedColors = indexedColors;
			this.colors = null;
			this.values = values;
		}
	}
	public enum CommandType : ubyte{
		/// Does nothing, placeholder command.
		NONE			=	0,
		/**
		 * Does a XOR blitter line. Parameters:
		 * coordinate[0]: Begins the line from the top-left corner until the right corner. Bottom value is discarded.
		 * color[0]: The 32 bit colorvector.
		 */
		XORBLITTERLINE	=	1,
		/**
		 * Does a XOR blitter box. Parameters:
		 * coordinate[0]: The coordinates where the box should be drawn.
		 * color[0]: The 32 bit colorvector.
		 */
		XORBLITTERBOX	=	2,
		/**
		 * Offsets a line by a given value. Parameters:
		 * coordinate[0]: Begins the line from the top-left corner until the right corner. Bottom value is discarded.
		 * value[0]: The amount which the line will be offsetted.
		 *
		 * NOTE: Be careful with this operation, if the algorithm has to write out from the screen, it'll cause a MemoryAccessViolationError.
		 * Overscanning will enable to write outside of it as well as offsetting otherwise off-screen elements onto the screen.
		 */
		LINEOFFSET		=	3
	}
	private EffectLayerCommand[int] commandList;
	private int[] commandListPriorities;
	public this(){

	}
	/**
	 * Adds a new command with the specified values.
	 */
	public void addCommand(int priority, EffectLayerCommand command){
		import std.algorithm.sorting;
		commandList[priority] = command;
		commandListPriorities ~= priority;
		commandListPriorities.sort();
	}
	/**
	 * Removes a command at the specified priority.
	 */
	public void removeCommand(int priority){
		commandList.remove(priority);
		int[] newCommandListPriorities;
		for(int i ; i < commandListPriorities.length ; i++){
			if(commandListPriorities[i] != priority){
				newCommandListPriorities ~= commandListPriorities[i];
			}
		}
		commandListPriorities = newCommandListPriorities;
	}

	override public void updateRaster(void* workpad,int pitch,Color* palette) {
		/*foreach(int i; commandListPriorities){
			switch(commandList[i].command){
				case CommandType.XORBLITTERLINE:
					int offset = (commandList[i].coordinates[0].top * pitch) + commandList[i].coordinates[0].left;
					if(commandList[i].indexedColors is null){
						xorBlitter(workpad + offset,commandList[i].colors[0],commandList[i].coordinates[0].width());
					}else{
						xorBlitter(workpad + offset,palette[commandList[i].indexedColors[0]],commandList[i].coordinates[0].width());
					}
					break;
				case CommandType.XORBLITTERBOX:
					int offset = (commandList[i].coordinates[0].top * pitch) + commandList[i].coordinates[0].left;
					if(commandList[i].indexedColors is null){
						for(int y = commandList[i].coordinates[0].top; y < commandList[i].coordinates[0].bottom; y++){
							xorBlitter(workpad + offset,commandList[i].colors[0],commandList[i].coordinates[0].width());
							offset += pitch;
						}
					}else{
						for(int y = commandList[i].coordinates[0].top; y < commandList[i].coordinates[0].bottom; y++){
							xorBlitter(workpad + offset,commandList[i].colors[0],commandList[i].coordinates[0].width());
							offset += pitch;
						}
					}
					break;
				case CommandType.LINEOFFSET:
					int offset = (commandList[i].coordinates[0].top * pitch) + commandList[i].coordinates[0].left;
					copyRegion(workpad + offset, workpad + offset + commandList[i].values[0], commandList[i].coordinates[0].width());
					break;
				default:
					break;
			}
		}*/
	}

}
unittest{
	TransformableTileLayer test = new TransformableTileLayer();
}
