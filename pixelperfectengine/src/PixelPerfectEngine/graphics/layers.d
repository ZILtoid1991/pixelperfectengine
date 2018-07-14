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
import std.parallelism;
//import std.container.rbtree;
//import system.etc;
import PixelPerfectEngine.system.exc;
//import std.algorithm;
import derelict.sdl2.sdl;
import core.stdc.stdlib;
//import std.range;
import CPUblit.composing;
import CPUblit.colorlookup;

version(LDC){
	import inteli.emmintrin;
}

/*static immutable ushort[4] alphaMMXmul_const256 = [256,256,256,256];
static immutable ushort[4] alphaMMXmul_const1 = [1,1,1,1];
static immutable ushort[8] alphaSSEConst256 = [256,256,256,256,256,256,256,256];
static immutable ushort[8] alphaSSEConst1 = [1,1,1,1,1,1,1,1];
static immutable ubyte[16] alphaSSEMask = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0];
static immutable uint[4] SSEUQWmaxvalue = [0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF] ;*/

//static immutable uint[2] alphaMMXmul_0 = [1,1];

/**
 * The basis of all layer classes, containing functions for rendering.
 * TODO: Move rendering functions to an external library.
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
				mainRenderingFunction = &blitter32bit;
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
	public abstract void updateRaster(void* workpad, int pitch, Color* palette, int[] threads);
	///Standard algorithm for horizontal mirroring
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
 * Sets the rendering mode of the TileLayer.
 * 
 * COPY is the fastest, but overrides any kind of transparency keying. It directly writes into the framebuffer. Should only be used for certain applications, like bottom layers.
 * BLITTER uses a custom BitBlT algorithm for the SSE2 instruction set. Automatically generates the copying mask depending on the alpha-value. Any alpha-value that's non-zero will cause a non-transparent pixel, and all zeros are completely transparent. Gradual transparency in not avaliable.
 * ALPHA_BLENDING uses SSE2 for alpha blending. The slowest, but allows gradual transparencies.
 */ 
public enum LayerRenderingMode{
	COPY,
	BLITTER,
	ALPHA_BLENDING
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
	@nogc public int getTileWidth();
	/// Returns the height of the tiles.
	@nogc public int getTileHeight();
	/// Returns the width of the mapping.
	@nogc public int getMX();
	/// Returns the height of the mapping.
	@nogc public int getMY();
	/// Returns the total width of the tile layer.
	@nogc public int getTX();
	/// Returns the total height of the tile layer.
	@nogc public int getTY();
	/// Adds a tile.
	public void addTile(ABitmap tile, wchar id);
}

public struct MappingElement{
	wchar tileID;				///Determines which tile is being used for the given instance
	BitmapAttrib attributes;	///General attributes
	ubyte reserved;				///Currently unused
	@nogc this(wchar tileID, BitmapAttrib attributes = BitmapAttrib(false, false)){
		this.tileID = tileID;
		this.attributes = attributes;
	}
}

/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Can use any kind of bitmaps thanks to code restructuring.
 */
public class TileLayer : Layer, ITileLayer{
	protected struct DisplayListItem{
		ABitmap tile;			///reference counting only
		void* pixelDataPtr;		///points to the pixeldata
		Color* palettePtr;		///points to the palette if present
		wchar ID;				///ID, mainly as a padding to 32 bit alignment
		ubyte wordLength;		///to avoid calling the more costly classinfo
		ubyte reserved;
		this(wchar ID, ABitmap tile){
			palettePtr = tile.getPalettePtr();
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
			}
		}
	}
	protected int tileX, tileY, mX, mY;
	protected int totalX, totalY;
	protected MappingElement[] mapping;
	//private wchar[] mapping;
	//private BitmapAttrib[] tileAttributes;
	Color[] src;
	protected BinarySearchTree!(wchar, DisplayListItem) displayList;
	protected bool warpMode;
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
		x /= tileX;
		y /= tileY;
		if(warpMode){
			x %= mX;
			y %= mY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return MappingElement(0xFFFF);
		return mapping[x + y*mX];
	}
	///Returns the tile's attribute at the given pixel
	/+@nogc public BitmapAttrib tileAttributeByPixel(int x, int y){
		x /= tileX;
		y /= tileY;
		if(warpMode){
			x %= totalX;
			y %= totalY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return BitmapAttrib(false,false);
		return tileAttributes[x + y*mX];
	}+/
	
	public @nogc override void updateRaster(void* workpad, int pitch, Color* palette, int[] threads){
		import core.stdc.stdio;
		int y = sY < 0 && !warpMode ? sY * -1 : 0;
		int sY0 = cast(int)(cast(uint)(sY) & 0b0111_1111_1111_1111_1111_1111_1111_1111);
		int offsetP = y*pitch;	// The offset of the line that is being written
		int offsetY = sY0 % tileY;		//Scroll offset upwards
		int offsetY0 = (sY + rasterY) % tileY;
		int offsetXA = sX%tileX;	// tile offset of the first column
		//for( ; y < rasterY ; y+=tileY){
		while(y < rasterY){
			//int offsetY = tileX * ((y + sY)%tileY);		
			int offsetYA = !y ? offsetY : 0;	//top offset for first tile, 0 otherwise
			int offsetYB = y + tileY > rasterY ? offsetY0 : tileY;	//bottom offset of last tile, equals tileY otherwise
			int x = sX < 0 && !warpMode ? sX * -1 : 0;
			int targetX = totalX - sX > rasterX && !warpMode ? rasterX : rasterX - (totalX - sX);
			void *p0 = (workpad + (x*Color.sizeof) + offsetP);
			while(x < targetX){
				MappingElement currentTile = tileByPixel(x+sX,y+sY);
				int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX) ;	// the length of the displayed tile
				int xp = (offsetXA != 0 && x == 0) ? offsetXA : 0;	// offset of the first column
				tileXtarget -= xp;	// length of the first tile
				if(currentTile.tileID != 0xFFFF){ // skip if tile is null
					//BitmapAttrib tileAttrib = tileAttributeByPixel(x+sX,y+sY);
					DisplayListItem d = displayList[currentTile.tileID];	// pointer to the current tile's pixeldata
					int tileYOffset = tileY;
					tileYOffset *= currentTile.attributes.vertMirror ? -1 : 1;	//vertical mirroring
					//int pitchOffset = pitch * threads.length;
					void* p1 = p0;
					switch(d.wordLength){
						case 4:
							ubyte* c = cast(ubyte*)d.pixelDataPtr;
							c += currentTile.attributes.vertMirror ? ((tileY - offsetYA - 1) * tileX)>>1 : (offsetYA * tileX)>>1;
							for(int y0 = offsetYA ; y0 < offsetYB ; y0++){
								main4BitColorLookupFunction(c, cast(uint*)src.ptr, cast(uint*)d.palettePtr, tileX, x & 1);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src.ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset>>>1;
								p1 += pitch;
							}
							break;
						case 8:
							ubyte* c = cast(ubyte*)d.pixelDataPtr;
							c += currentTile.attributes.vertMirror ? (tileY - offsetYA - 1) * tileX : offsetYA * tileX;
							for(int y0 = offsetYA ; y0 < offsetYB ; y0++){
								main8BitColorLookupFunction(c, cast(uint*)src.ptr, cast(uint*)d.palettePtr, tileX);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src.ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset;
								p1 += pitch;
							}
							break;
						case 16:
							ushort* c = cast(ushort*)d.pixelDataPtr;
							c += currentTile.attributes.vertMirror ? (tileY - offsetYA - 1) * tileX : offsetYA * tileX;
							for(int y0 = offsetYA ; y0 < offsetYB ; y0++){
								mainColorLookupFunction(c, cast(uint*)src.ptr, cast(uint*)palette, tileX);
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src.ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src.ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset;
								p1 += pitch;
							}
							break;
						case 32:
							Color* c = cast(Color*)d.pixelDataPtr;								
							c += currentTile.attributes.vertMirror ? (tileY - offsetYA - 1) * tileX : offsetYA * tileX;
							for(int y0 = offsetYA ; y0 < offsetYB ; y0++){
								if(currentTile.attributes.horizMirror){//Horizontal mirroring
									copy32bit(cast(uint*)c, cast(uint*)src.ptr, tileX);
									flipHorizontal(cast(uint*)src.ptr, tileX);
									mainRenderingFunction(cast(uint*)src.ptr + xp, cast(uint*)p1, tileXtarget);
								}else{
									mainRenderingFunction(cast(uint*)(c + xp), cast(uint*)p1, tileXtarget);
								}
								c += tileYOffset;
								p1 += pitch;
							}
							break;
						default:
							break;
					}
					
				}
				p0 += tileXtarget * Color.sizeof;
				x+=tileXtarget;
			}
			offsetP	+= !y ? pitch * (tileY - offsetY) : pitch * tileY;
			/*if(y + tileY > y) y += tileY - offsetY0;
			else if(y) y += tileY;
			else y += (tileY - offsetY);*/
			y += !y ? (tileY - offsetY) : tileY;
		}
				
		
	}
	public MappingElement[] getMapping(){
		return mapping;
	}
	@nogc public int getTileWidth(){
		return tileX;
	}
	@nogc public int getTileHeight(){
		return tileY;
	}
	@nogc public int getMX(){
		return mX;
	}
	@nogc public int getMY(){
		return mY;
	}
	@nogc public int getTX(){
		return totalX;
	}
	@nogc public int getTY(){
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
 * <li>Only a single type of bitmap can be used and 4 bit ones are excluded.</li>
 * <li>8 bit tiles will share the same palette.</li>
 * <li>Tiles must have any of the following sizes: 8, 16, 32, 64.</li>
 * <li>Maximum layer size in pixels are restricted to 65536*65536</li>
 * </ul>
 * HDMA emulation supported through delegate hBlankInterrupt.
 */
public class TransformableTileLayer(BMPType = Bitmap16Bit, int TileX = 8, int TileY = 8) : Layer, ITileLayer{
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
	static if(BMPType.mangleof == Bitmap8Bit.mangleof){
		protected ubyte[] src;
		protected Color* palettePtr;	///Shared palette
	}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
		protected ushort[] src;
	}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
		
	}else static assert("Template parameter " ~ BMPType.mangleof ~ " not supported by TransformableTileLayer!");
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
	else static assert("Unsupported horizontal tile size!");
	static if(TileY == 8)
		protected immutable int shiftY = 3;
	else static if(TileY == 16)
		protected immutable int shiftY = 4;
	else static if(TileY == 32)
		protected immutable int shiftY = 5;
	else static if(TileY == 64)
		protected immutable int shiftY = 6;
	else static assert("Unsupported vertical tile size!");
	protected int totalX, totalY;		
	protected MappingElement[] mapping;
	version(LDC){
		protected int4 _tileAmpersand;
		protected static short8 _increment;
	}

	public @nogc void delegate(ref short[4] localABCD, ref short[2] localsXsY, ref short[2] localx0y0, short y) hBlankInterrupt;

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
	
	override public @nogc void updateRaster(void* workpad,int pitch,Color* palette,int[] threads) {
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
							DisplayListItem d = displayList[currentTile.tileID];
							static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							xy = [xy[0] & (TileX - 1), xy[1] & (TileY - 1)];
							tsrc += xy[0] + xy[1] * TileX;
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = *tsrc;
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = 0;
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
						MappingElement currentTile0 = tileByPixelWithoutTransform(xy[0],xy[1]), currentTile1 = tileByPixelWithoutTransform(xy[2],xy[3]);
						xy &= _tileAmpersand;
						if(currentTile0.tileID != 0xFFFF){
							DisplayListItem d = displayList[currentTile0.tileID];
							static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							
							tsrc += xy[0] + xy[1] * TileX;
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = *tsrc;
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
						x++;
						if(currentTile1.tileID != 0xFFFF){
							DisplayListItem d = displayList[currentTile1.tileID];
							static if(BMPType.mangleof == Bitmap8Bit.mangleof){
								ubyte* tsrc = cast(ubyte*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
								ushort* tsrc = cast(ushort*)d.pixelSrc;
							}else static if(BMPType.mangleof == Bitmap32Bit.mangleof){
								Color* tsrc = cast(Color*)d.pixelSrc;
							}
							//xy = [xy[2] & (TileX - 1), xy[3] & (TileY - 1)];
							tsrc += xy[2] + xy[3] * TileX;
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = *tsrc;
							}else{
								*dest = *tsrc;
								dest++;
							}
						}else{
							static if(BMPType.mangleof == Bitmap8Bit.mangleof || BMPType.mangleof == Bitmap16Bit.mangleof){
								src[x] = 0;
							}else{
								(*dest).raw = 0;
							}
						}
						xy_in += _increment;

					}
				}else static assert("Compiler not supported");
				static if(BMPType.mangleof == Bitmap8Bit.mangleof){
					main8BitColorLookupFunction(src.ptr, cast(uint*)dest, cast(uint*)palettePtr, rasterX);
					dest += rasterX;
				}else static if(BMPType.mangleof == Bitmap16Bit.mangleof){
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
	public @nogc @property short x_0(){
		return tpOrigin[0];
	}
	public @nogc @property short y_0(){
		return tpOrigin[1];
	}
	public @nogc @property short A(short newval){
		transformPoints[0] = newval;
		needsUpdate = true;
		return transformPoints[0];
	}
	public @nogc @property short B(short newval){
		transformPoints[1] = newval;
		needsUpdate = true;
		return transformPoints[1];
	}
	public @nogc @property short C(short newval){
		transformPoints[2] = newval;
		needsUpdate = true;
		return transformPoints[2];
	}
	public @nogc @property short D(short newval){
		transformPoints[3] = newval;
		needsUpdate = true;
		return transformPoints[3];
	}
	public @nogc @property short x_0(short newval){
		tpOrigin[0] = newval;
		//tpOrigin[2] = newval;
		needsUpdate = true;
		return tpOrigin[0];
	}
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
	@nogc public int getTileWidth(){
		return TileX;
	}
	@nogc public int getTileHeight(){
		return TileY;
	}
	@nogc public int getMX(){
		return mX;
	}
	@nogc public int getMY(){
		return mY;
	}
	@nogc public int getTX(){
		return totalX;
	}
	@nogc public int getTY(){
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
	public void addSprite(ABitmap s, int n, Coordinate c, BitmapAttrib attr);
	///Adds a sprite to the layer.
	public void addSprite(ABitmap s, int n, int x, int y, BitmapAttrib attr);
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(ABitmap s, int n);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, int x, int y);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(ABitmap s, int n, Coordinate c);
	///Edits a sprite attribute.
	public void editSpriteAttribute(S, T)(int n, T value);
	///Replaces a sprite attribute.
	public void replaceSpriteAttribute(int n, BitmapAttrib attr);
}
/**
 *Use it to call the collision detector
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
	protected struct DisplayListItem{
		Coordinate position;		/// Stores the position relative to the origin point. Actual display position is determined by the scroll positions.
		Coordinate slice;			/// To compensate for the lack of scanline interrupt capabilities, this enables chopping off parts of a sprite.
		//ABitmap sprite;				/// Defines the sprite being displayed on the screen.
		void* pixelData;
		Color* palette;
		int priority;				/// Used for automatic sorting and identification, otherwise the DisplayList is pre-sorted for better performance.
		BitmapAttrib attributes;	/// Horizontal and vertical mirroring.
		ubyte wordLength;			/// Determines the word length of a sprite in a much quicker way than getting classinfo.
		this(Coordinate position, ABitmap sprite, int priority, BitmapAttrib attributes = BitmapAttrib(false, false)){
			this.position = position;
			//this.sprite = sprite;
			palette = sprite.getPalettePtr();
			this.priority = priority;
			this.attributes = attributes;
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
		this(Coordinate position, Coordinate slice, ABitmap sprite, int priority, BitmapAttrib attributes = BitmapAttrib(false, false)){
			this.position = position;
			//this.sprite = sprite;
			palette = sprite.getPalettePtr();
			this.priority = priority;
			this.attributes = attributes;
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
				palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
				palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		void replaceSprite(ABitmap sprite){
			//this.sprite = sprite;
			palette = sprite.getPalettePtr();
			if(sprite.classinfo == typeid(Bitmap4Bit)){
				wordLength = 4;
				pixelData = (cast(Bitmap4Bit)(sprite)).getPtr;
				palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap8Bit)){
				wordLength = 8;
				pixelData = (cast(Bitmap8Bit)(sprite)).getPtr;
				palette = sprite.getPalettePtr();
			}else if(sprite.classinfo == typeid(Bitmap16Bit)){
				wordLength = 16;
				pixelData = (cast(Bitmap16Bit)(sprite)).getPtr;
			}else if(sprite.classinfo == typeid(Bitmap32Bit)){
				wordLength = 32;
				pixelData = (cast(Bitmap32Bit)(sprite)).getPtr;
			}
		}
		@nogc int opCmp(in DisplayListItem d){
			return priority - d.priority;
		}
		@nogc bool opEquals(in DisplayListItem d){
			return priority == d.priority;
		}
	}
	protected DisplayListItem[] displayList;	///Stores the display data with the 
	//private ABitmap[int] spriteSet;			///Stores the sprites.
	//private Coordinate[int] coordinates;		///Stores the coordinates.
	//private BitmapAttrib[int] spriteAttributes;	///Stores spriteattributes. (layer priority, mirroring, etc.)
	//private int[] spriteSorter;					///Stores the priorities.
	//public SpriteMovementListener[int] collisionDetector;	Deprecated, different collision detection will be used in the future.
	Color[] src;
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
		src.length = rY;
	}
	
	public void addSprite(ABitmap s, int n, Coordinate c, BitmapAttrib attr){
		import std.algorithm.sorting;
		import std.algorithm.searching;
		DisplayListItem d = DisplayListItem(c, s, n, attr);
		if(canFind(displayList, d)){
			throw new SpritePriorityException("Sprite number already exists!");
		}else{
			displayList ~= d;
			displayList.sort!"a > b"();
		}
	}
	
	public void addSprite(ABitmap s, int n, int x, int y, BitmapAttrib attr){
		import std.algorithm.sorting;
		import std.algorithm.searching;
		Coordinate c = Coordinate(x,y,x+s.width,y+s.height);
		DisplayListItem d = DisplayListItem(c, s, n, attr);
		if(canFind(displayList, d)){
			throw new SpritePriorityException("Sprite number already exists!");
		}else{
			displayList ~= d;
			displayList.sort!"a > b"();
		}
	}
	public void editSpriteAttribute(S, T)(int n, T value){
		for(int i; i < displayList.length ; i++){
			if(displayList[i].priority == n){
				displayList[i].S = value;
				return;
			}
		}
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
		
	}

	public void replaceSprite(ABitmap s, int n, Coordinate c){
		
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

	public override @nogc void updateRaster(void* workpad, int pitch, Color* palette, int[] threads){
		foreach(i ; displayList){
			if((i.position.right > sX && i.position.bottom > sY) && (i.position.left < sX + rasterX && i.position.top < sY + rasterY)){
				int offsetXA = sX > i.position.left ? sX - i.position.left : 0;//Left hand side offset
				int offsetXB = sX + rasterX < i.position.right ? i.position.right - rasterX : 0; //Right hand side offset
				int offsetYA = sY > i.position.top ? sY - i.position.top : 0;
				int offsetYB = sY + rasterY < i.position.bottom ? i.position.bottom - rasterY : 0;
				int sizeX = i.position.width(), offsetX = i.position.left - sX;
				int length = sizeX - offsetXA - offsetXB, lfour = length * 4;
				int offsetY = sY < i.position.top ? (i.position.top-sY)*pitch : 0;
				//int pitchOffset = pitch * threads.length;
				//int sizeXOffset = sizeX * threads.length;
				//sizeXOffset *= i.attributes.vertMirror ? -1 : 1;
				int sizeXOffset = sizeX * (i.attributes.vertMirror ? -1 : 1);
				switch(i.wordLength){
					case 4:
						//Bitmap4Bit bmp = cast(Bitmap4Bit)i.sprite;
						//ubyte* p0 = bmp.getPtr();
						ubyte* p0 = cast(ubyte*)i.pixelData;
						if(i.attributes.vertMirror)
							p0 += (sizeX * (i.position.height - offsetYB))>>1;
						else
							p0 += (sizeX * offsetYA)>>1;
						if(!i.attributes.horizMirror)
							p0 += offsetXA>>1;
						else
							p0 += offsetXB>>1;
						//foreach(int threadOffset; threads.parallel){
						//ubyte* p1 = p0 + threadOffset * sizeX;
						//void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
						//for(int y = offsetYA + threadOffset ; y < i.position.height - offsetYB ; y+=threads.length){
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; y++){	
							//main4BitColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)i.sprite.getPalettePtr(), length, offsetXA);
							main4BitColorLookupFunction(p0, cast(uint*)src.ptr, cast(uint*)i.palette, length, offsetXA);
							if(i.attributes.horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src.ptr, length);
							}
							mainRenderingFunction(cast(uint*)src.ptr, cast(uint*)dest, length);
							//dest += pitchOffset;
							dest += pitch;
							//p1 += sizeXOffset;
							p0 += sizeXOffset;
						}
						//}
						break;
					case 8:
						//Bitmap8Bit bmp = cast(Bitmap8Bit)i.sprite;
						//ubyte* p0 = bmp.getPtr();
						ubyte* p0 = cast(ubyte*)i.pixelData;
						if(i.attributes.vertMirror)
							p0 += sizeX * (i.position.height - offsetYB);
						else
						p0 += sizeX * offsetYA;
						if(!i.attributes.horizMirror)
							p0 += offsetXA;
						else
							p0 += offsetXB;
						//foreach(int threadOffset; threads.parallel){
						//ubyte* p1 = p0 + threadOffset * sizeX;
						//void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
						//for(int y = offsetYA + threadOffset ; y < i.position.height - offsetYB ; y+=threads.length){	
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; y++){	
							//main8BitColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)i.sprite.getPalettePtr(), length);
							main8BitColorLookupFunction(p0, cast(uint*)src.ptr, cast(uint*)i.palette, length);
							if(i.attributes.horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src.ptr, length);
							}
							mainRenderingFunction(cast(uint*)src.ptr, cast(uint*)dest, length);
							//dest += pitchOffset;
							dest += pitch;
							//p1 += sizeXOffset;
							p0 += sizeXOffset;
						}
						//}
						break;
					case 16:
						//Bitmap16Bit bmp = cast(Bitmap16Bit)i.sprite;
						//ushort* p0 = bmp.getPtr();
						ushort* p0 = cast(ushort*)i.pixelData;
						if(i.attributes.vertMirror)
							p0 += sizeX * (i.position.height - offsetYB);
						else
							p0 += sizeX * offsetYA;
						if(!i.attributes.horizMirror)
							p0 += offsetXA;
						else
							p0 += offsetXB;
						//foreach(int threadOffset; threads.parallel){
						//ushort* p1 = p0 + threadOffset * sizeX;
						//void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
						//for(int y = offsetYA + threadOffset ; y < i.position.height - offsetYB ; y+=threads.length){
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; y++){
							//mainColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)palette, length);
							//mainColorLookupFunction(p1, cast(uint*)src[threadOffset].ptr, cast(uint*)palette, length);
							mainColorLookupFunction(p0, cast(uint*)src.ptr, cast(uint*)palette, length);
							if(i.attributes.horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src.ptr, length);
							}
							mainRenderingFunction(cast(uint*)src.ptr, cast(uint*)dest, length);
							//dest += pitchOffset;
							dest += pitch;
							//p1 += sizeXOffset;
							p0 += sizeXOffset;
						}
						//}
						break;
					case 32:
						//Bitmap32Bit bmp = cast(Bitmap32Bit)i.sprite;
						//Color* p0 = bmp.getPtr();
						uint* p0 = cast(uint*)i.pixelData;
						if(i.attributes.vertMirror)
							p0 += sizeX * (i.position.height - offsetYB);
						else
							p0 += sizeX * offsetYA;
						if(!i.attributes.horizMirror)
							p0 += offsetXA;
						else
							p0 += offsetXB;
						//foreach(int threadOffset; threads.parallel){
							
						//uint* p1 = p0 + threadOffset * sizeX;
						//void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
						//for(int y = offsetYA + threadOffset ; y < i.position.height - offsetYB ; y+=threads.length){		
						for(int y = offsetYA ; y < i.slice.height - offsetYB ; y++){
							if(i.attributes.horizMirror){//Flips lines if needed
								//copy32bit(p1, cast(uint*)(src[threadOffset].ptr), length);
								copy32bit(p0, cast(uint*)(src.ptr), length);
								flipHorizontal(cast(uint*)(src.ptr), length);
								mainRenderingFunction(cast(uint*)(src.ptr), cast(uint*)dest, length);
							}else{
								mainRenderingFunction(p0, cast(uint*)dest, length);
							}
							//dest += pitchOffset;
							dest += pitch;
							//p1 += sizeXOffset;
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

	override public void updateRaster(void* workpad,int pitch,Color* palette,int[] threads) {
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