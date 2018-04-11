/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers module
 */
module PixelPerfectEngine.graphics.layers;

public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.common;
import std.conv;
import std.parallelism;
//import std.container.rbtree;
//import system.etc;
import PixelPerfectEngine.system.exc;
import std.algorithm;
import derelict.sdl2.sdl;
import core.stdc.stdlib;
//import std.range;
import CPUblit.composing;
import CPUblit.colorlookup;


/*static immutable ushort[4] alphaMMXmul_const256 = [256,256,256,256];
static immutable ushort[4] alphaMMXmul_const1 = [1,1,1,1];
static immutable ushort[8] alphaSSEConst256 = [256,256,256,256,256,256,256,256];
static immutable ushort[8] alphaSSEConst1 = [1,1,1,1,1,1,1,1];
static immutable ubyte[16] alphaSSEMask = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0];
static immutable uint[4] SSEUQWmaxvalue = [0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF] ;*/

//static immutable uint[2] alphaMMXmul_0 = [1,1];

public enum FlipRegister : ubyte {
	NORM	=	0x00,
	X		=	0x01,
	Y		=	0x02,
	XY		=	0x03
}

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
		version(NO_SSE2){
			int c = length / 2;
			void* dest = src + length * 4 - 4;
			asm @nogc{
				mov		ESI, src[EBP];
				mov		EDI, dest[EBP];
				mov		ECX, c;

			loopentry:

				movd	MM0, [ESI];
				movd	MM1, [EDI];
				movd	[ESI], MM1;
				movd	[EDI], MM0;
				add		ESI, 4;
				sub		EDI, 4;
				dec		ECX;
				cmp		ECX, 0;
				jnz		loopentry;
			}
		}else version(X86){
			//src -= 4;
			int c = length / 2;
			void* dest = src + length * 4 - 4;
			asm @nogc{
				mov		ESI, src[EBP];
				mov		EDI, dest[EBP];
				mov		ECX, c;

			loopentry:

				movd	XMM0, [ESI];
				movd	XMM1, [EDI];
				movd	[ESI], XMM1;
				movd	[EDI], XMM0;
				add		ESI, 4;
				sub		EDI, 4;
				dec		ECX;
				cmp		ECX, 0;
				jnz		loopentry;
			}
		}else version(X86_64){
			int c = length / 2, dest = length * 4;
			int c = length / 2;
			void* dest = src + length * 4 - 4;
			asm @nogc{
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RCX, c;

			loopentry:

				movd	XMM0, [RSI];
				movd	XMM1, [RDI];
				movd	[RSI], XMM1;
				movd	[RDI], XMM0;
				add		RSI, 4;
				sub		RDI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		loopentry;
			}
		}else{
			src -= 4;
			Color s, d;
			void* dest = src + (Color.sizeof * length);
			for(int i ; i < length ; i++){
				s = *cast(Color*)src;
				d = *cast(Color*)dest;
				*cast(Color*)dest = s;
				*cast(Color*)src = d;
				src += 4;
				dest -= 4;
			}
		}
	}
}

public struct BLInfo{
	public int tileX, tileY, mX, mY;
	this(int tileX1,int tileY1,int x1,int y1){
		tileX = tileX1;
		tileY = tileY1;
		mX = x1;
		mY = y1;
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
	public BLInfo getLayerInfo();
	/// Returns the whole mapping data, primarily used for serialization.
	public wchar[] getMapping();
	/// Reads the mapping element from the given area.
	@nogc public wchar readMapping(int x, int y);
	/// Writes the given element into the mapping at the given location.
	@nogc public void writeMapping(int x, int y, wchar w);
	/// Loads the mapping, primarily used for deserialization.
	public void loadMapping(int x, int y, wchar[] map, BitmapAttrib[] tileAttributes);
	/// Removes the tile from the display list with the given ID.
	public void removeTile(wchar id);
	/// Returns the tile ID from the location by pixel.
	@nogc public wchar tileByPixel(int x, int y);
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
	/// Returns a tile by ID if exists, returns null otherwise
	public ABitmap getTile(wchar id);
}

/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Can use any kind of bitmaps thanks to code restructuring.
 */
public class TileLayer : Layer, ITileLayer{
	protected int tileX, tileY, mX, mY;
	protected int totalX, totalY;
	private wchar[] mapping;
	private BitmapAttrib[] tileAttributes;
	Color[][8] src;
	private ABitmap[wchar] tileSet;
	protected bool warpMode;
	protected @nogc void function(ref int y, ref int x) hBlankInterrupt0;
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
		for(int i; i < 8; i++){
			src[i].length = tileX;
		}
	}
	/*~this(){
		foreach(p; src){
			if(p){
				free(p);
			}
		}
	}*/
	/// Warpmode: if enabled, the layer will be turned into an "infinite" mode.
	public void setWarpMode(bool w){
		warpMode = w;
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	@nogc public wchar readMapping(int x, int y){
		/*if(x<0 || x>totalX/tileX){
		 return 0xFFFF;
		 }*/
		return mapping[x+(mX*y)];
	}
	///
	@nogc public BitmapAttrib readTileAttribute(int x, int y){
		return tileAttributes[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, wchar w){
		mapping[x+(mX*y)]=w;
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeTileAttribute(int x, int y, BitmapAttrib ba){
		tileAttributes[x+(mX*y)]=ba;
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, wchar[] map, BitmapAttrib[] tileAttributes){
		mX=x;
		mY=y;
		mapping = map;
		this.tileAttributes = tileAttributes;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(ABitmap tile, wchar id){
		if(tile.width==tileX && tile.height==tileY){
			tileSet[id]=tile;
		}else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		tileSet.remove(id);
	}
	///Returns which tile is at the given pixel
	@nogc public wchar tileByPixel(int x, int y){
		x /= tileX;
		y /= tileY;
		if(warpMode){
			x %= totalX;
			y %= totalY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return 0xFFFF;
		return mapping[x + y*mX];
	}
	///Returns the tile's attribute at the given pixel
	@nogc public BitmapAttrib tileAttributeByPixel(int x, int y){
		x /= tileX;
		y /= tileY;
		if(warpMode){
			x %= totalX;
			y %= totalY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return BitmapAttrib(false,false);
		return tileAttributes[x + y*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, Color* palette, int[] threads){
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
				wchar currentTile = tileByPixel(x+sX,y+sY);
				int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX) ;	// the length of the displayed tile
				int xp = (offsetXA != 0 && x == 0) ? offsetXA : 0;	// offset of the first column
				tileXtarget -= xp;	// length of the first tile
				if(currentTile != 0xFFFF){ // skip if tile is null
					BitmapAttrib tileAttrib = tileAttributeByPixel(x+sX,y+sY);
					
					//if(tileXtarget + x > ){}
					
					ABitmap ab = tileSet[currentTile];	// pointer to the current tile's pixeldata
					int tileYOffset = tileY * threads.length;
					tileYOffset *= tileAttrib.vertMirror ? -1 : 1;	//vertical mirroring
					int pitchOffset = pitch * threads.length;
					/+switch(ab.classinfo){
						case typeid(Bitmap4Bit):+/
					if(ab.classinfo == typeid(Bitmap4Bit)){
						//tileYOffset >>=1;
						foreach(int threadOffset; threads.parallel){
							void* p1 = p0;
							Bitmap4Bit bmp = cast(Bitmap4Bit)(ab);
							ubyte* c = bmp.getPtr();
							c += tileAttrib.vertMirror ? ((tileY - offsetYA - 1 + threadOffset) * tileX)>>1 : ((offsetYA + threadOffset) * tileX)>>1;
							for(int y0 = offsetYA + threadOffset ; y0 < offsetYB ; y0+=threads.length){
								main4BitColorLookupFunction(c, cast(uint*)src[threadOffset].ptr, cast(uint*)ab.getPalettePtr, tileX, 0);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src[threadOffset].ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset>>1;
								p1 += pitchOffset;
							}
							/+}+/
						}
					}else if(ab.classinfo == typeid(Bitmap8Bit)){
						/+	break;
						case typeid(Bitmap8Bit):+/
						foreach(int threadOffset; threads.parallel){
							void* p1 = p0;
							Bitmap8Bit bmp = cast(Bitmap8Bit)(ab);
							ubyte* c = bmp.getPtr();
							c += tileAttrib.vertMirror ? (tileY - offsetYA - 1 + threadOffset) * tileX : (offsetYA + threadOffset) * tileX;
							for(int y0 = offsetYA + threadOffset ; y0 < offsetYB ; y0+=threads.length){
								main8BitColorLookupFunction(c, cast(uint*)src[threadOffset].ptr, cast(uint*)ab.getPalettePtr, tileX);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src[threadOffset].ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset;
								p1 += pitchOffset;
							}
							/+}+/
						}
					}else if(ab.classinfo == typeid(Bitmap16Bit)){
							/+break;
						case typeid(Bitmap16Bit):+/
						foreach(int threadOffset; threads.parallel){
							void* p1 = p0;
							Bitmap16Bit bmp = cast(Bitmap16Bit)(ab);
							ushort* c = bmp.getPtr();
							c += tileAttrib.vertMirror ? (tileY - offsetYA - 1 + threadOffset) * tileX : (offsetYA + threadOffset) * tileX;
							for(int y0 = offsetYA + threadOffset ; y0 < offsetYB ; y0+=threads.length){
								mainColorLookupFunction(c, cast(uint*)src[threadOffset].ptr, cast(uint*)palette, tileX);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									flipHorizontal(cast(uint*)src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(cast(uint*)src[threadOffset].ptr + xp, cast(uint*)p1, tileXtarget);
								c += tileYOffset;
								p1 += pitchOffset;
							}
							
						}
					}else if(ab.classinfo == typeid(Bitmap32Bit)){
							/+break;
						case typeid(Bitmap32Bit):+/
						foreach(int threadOffset; threads.parallel){
							void* p1 = p0;
							Bitmap32Bit bmp = cast(Bitmap32Bit)(ab);
							Color* c = bmp.getPtr();								
							c += tileAttrib.vertMirror ? (tileY - offsetYA - 1 + threadOffset) * tileX : (offsetYA + threadOffset) * tileX;
							for(int y0 = offsetYA + threadOffset ; y0 < offsetYB ; y0+=threads.length){
								if(tileAttrib.horizMirror){//Horizontal mirroring
									copy32bit(cast(uint*)c, cast(uint*)src[threadOffset].ptr, tileX);
									flipHorizontal(cast(uint*)src[threadOffset].ptr, tileX);
									mainRenderingFunction(cast(uint*)src[threadOffset].ptr + xp, cast(uint*)p1, tileXtarget);
								}else{
									mainRenderingFunction(cast(uint*)(c + xp), cast(uint*)p1, tileXtarget);
								}
								c += tileYOffset;
								p1 += pitchOffset;
							}
							
						}
							/+break;
						default:
							break;+/
					}
					p0 += tileXtarget * Color.sizeof;
				}
				x+=tileXtarget;

			}
			offsetP	+= !y ? pitch * (tileY - offsetY) : pitch * tileY;
			/*if(y + tileY > y) y += tileY - offsetY0;
			else if(y) y += tileY;
			else y += (tileY - offsetY);*/
			y += !y ? (tileY - offsetY) : tileY;
		}
				
		
	}
	
	public BLInfo getLayerInfo(){
		return BLInfo(tileX,tileY,mX,mY);
	}
	public ABitmap getTile(wchar id){
		return tileSet[id];
	}
	public wchar[] getMapping(){
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
 * Implements a modified TileLayer with transformability.
 * <br/>
 * Transform function:
 * x_out = scale_x * (x_in + sX - x_0) + shear_x * (y_in + sY - y_0) + x_0
 * y_out = shear_y * (x_in + sX - x_0) + scale_y * (y_in + sY - y_0) + y_0
 * <br/>
 * For per-scanline transformation, use SuperTransformableTileLayer.
 * <br/>
 * All basic transform values are integer based, 65536 equals with 1.0
 */
public class TransformableTileLayer : TileLayer{
	//protected int[2] ac, bd, xy0;
	protected float[4] transformPoints;
	protected float[4] tpOrigin;
	protected Bitmap32Bit backbuffer;	///used to store current screen output
	private bool needsUpdate;
	protected static immutable uint[4] maskAC = [uint.max, 0, uint.max, 0];
	protected @nogc void function(int y, ref float[4] transformPoints, ref float[4] tpOrigin) hBlankInterrupt1;

	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		super(tX, tY, renderMode);
		A = 1.0;
		B = 0;
		C = 0;
		D = 1.0;
		x_0 = 0;
		y_0 = 0;
	}
	override public void setRasterizer(int rX,int rY) {
		backbuffer = new Bitmap32Bit(rX, rY);
		super.setRasterizer(rX,rY);
	}
	
	override public void updateRaster(void* workpad,int pitch,Color* palette,int[] threads) {
		if(needsUpdate){
			needsUpdate = false;
			//clear buffer
			backbuffer.clear();
			//write new data into it
			foreach(int thread; threads.parallel){
				for(int y = thread; y < rasterY; y += threads.length){
					for(int x; x < rasterX; x++){
						int[2] newpix = transformFunc([x,y]);
						wchar tile = super.tileByPixel(newpix[0], newpix[1]);
						if(tile != 0xFFFF){
							BitmapAttrib b = super.tileAttributeByPixel(newpix[0], newpix[1]);
							newpix[0] = /+b.horizMirror ? tileX - (newpix[0] % tileX) - 1 :+/ newpix[0] % tileX;
							newpix[1] = /+b.vertMirror ? tileY - (newpix[1] % tileY) - 1 :+/ newpix[1] % tileY;
							ABitmap ab = tileSet[tile];
							Color c;
							if(ab.classinfo == typeid(Bitmap4Bit)){
								Bitmap4Bit bmp = cast(Bitmap4Bit)ab;
								c = bmp.getPalettePtr[bmp.readPixel(newpix[0], newpix[1])];
							}else if(ab.classinfo == typeid(Bitmap8Bit)){
								Bitmap8Bit bmp = cast(Bitmap8Bit)ab;
								c = bmp.getPalettePtr[bmp.readPixel(newpix[0], newpix[1])];
							}else if(ab.classinfo == typeid(Bitmap16Bit)){
								Bitmap16Bit bmp = cast(Bitmap16Bit)ab;
								c = palette[bmp.readPixel(newpix[0], newpix[1])];
							}else if(ab.classinfo == typeid(Bitmap32Bit)){
								Bitmap32Bit bmp = cast(Bitmap32Bit)ab;
								c = bmp.readPixel(newpix[0], newpix[1]);
							}
							backbuffer.writePixel(x,y,c);
						}
					}
				}
			}
		}
		//render surface onto the raster
		foreach(int thread; threads.parallel){
			void* p0 = workpad + thread * pitch;
			int w = backbuffer.width;
			Color* c = backbuffer.getPtr();
			for(int y = thread; y < rasterY; y += threads.length){
				mainRenderingFunction(cast(uint*)c,cast(uint*)p0,w);
				c += w * threads.length;
				p0 += pitch * threads.length;
			}
		}
	}
	/+override public @nogc wchar tileByPixel(int x,int y) {
		int[2] newpix = transformFunc([x,y]);
		return super.tileByPixel(newpix[0], newpix[1]);
	}
	override public @nogc BitmapAttrib tileAttributeByPixel(int x,int y) {
		int[2] newpix = transformFunc([x,y]);
		return super.tileAttributeByPixel(newpix[0], newpix[1]);
	}+/
	
	/**
	 * Main transform function, returns the point where the pixel is needed to be read from.
	 * The function reads as:
	 * [x',y'] = [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
	 */
	public @nogc int[2] transformFunc(int[2] xy){
		version(X86){
			int[2] result;
			int[4] scrollpos = [sX, sY, sX, sY];
			asm @nogc{
				mov			EBX, this;
				movq		XMM7, xy;
				cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
				movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
				pslldq		XMM1, 8;	// YYYY XXXX ---- ----
				por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
				movups		XMM7, scrollpos;
				cvtdq2ps	XMM1, XMM7;
				addps		XMM0, XMM1; // [x,y] + [sX,sY]
				movups		XMM6, tpOrigin[EBX];
				subps		XMM0, XMM6;	// [x,y] + [sX,sY] - [x_0,y_0]
				movups		XMM2, transformPoints[EBX];	// dddd cccc bbbb aaaa
				mulps		XMM2, XMM0;	//[A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])
				movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
				psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
				pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
				pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
				addps		XMM2, XMM3;	// ---- c+d ---- a+b
				movups		XMM3, XMM2; // ---- C+D ---- A+B
				psrldq		XMM3, 4;	// ---- ---- C+D ----
				por			XMM2, XMM3; // ---- c+d C+D A+B
				addps		XMM2, XMM6; // [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
				cvttps2dq	XMM7, XMM2;
				movq		result, XMM7;
			}
			return result;
		}else version(X86_64){
			int[2] result;
			int[4] scrollpos = [sX, sY, sX, sY];
			asm @nogc{
				mov			RBX, this;
				movq		XMM7, xy;
				cvtdq2ps	XMM0, XMM7;	// ---- ---- yyyy xxxx
				movups		XMM1, XMM0;	// ---- ---- YYYY XXXX
				pslldq		XMM1, 8;	// YYYY XXXX ---- ----
				por			XMM0, XMM1; // YYYY XXXX yyyy xxxx
				movups		XMM7, scrollpos;
				cvtdq2ps	XMM1, XMM7;
				addps		XMM0, XMM1; // [x,y] + [sX,sY]
				movups		XMM6, tpOrigin[RBX];
				subps		XMM0, XMM6;	// [x,y] + [sX,sY] - [x_0,y_0]
				movups		XMM2, transformPoints[RBX];	// dddd cccc bbbb aaaa
				mulps		XMM2, XMM0;	//[A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0])
				movups		XMM3, XMM2; // DDDD CCCC BBBB AAAA
				psrldq		XMM3, 4;	// ---- DDDD CCCC BBBB
				pand		XMM2, maskAC;	// ---- CCCC ---- AAAA
				pand		XMM3, maskAC;	// ---- DDDD ---- BBBB
				addps		XMM2, XMM3;	// ---- c+d ---- a+b
				movups		XMM3, XMM2; // ---- C+D ---- A+B
				psrldq		XMM3, 4;	// ---- ---- C+D ----
				por			XMM2, XMM3; // ---- c+d C+D A+B
				addps		XMM2, XMM6; // [A,B,C,D] * ([x,y] + [sX,sY] - [x_0,y_0]) + [x_0,y_0]
				cvttps2dq	XMM7, XMM2;
				movq		result, XMM7;
			}
			return result;
		}else{
			
		}
	}
	/+public @nogc @property int A(){
		return ac[0];
	}
	public @nogc @property int B(){
		return bd[0];
	}
	public @nogc @property int C(){
		return ac[1];
	}
	public @nogc @property int D(){
		return bd[1];
	}
	public @nogc @property int x_0(){
		return xy0[0];
	}
	public @nogc @property int y_0(){
		return xy0[1];
	}
	public @nogc @property int A(int newval){
		ac[0] = newval;
		needsUpdate = true;
		return ac[0];
	}
	public @nogc @property int B(int newval){
		bd[0] = newval;
		needsUpdate = true;
		return bd[0];
	}
	public @nogc @property int C(int newval){
		ac[1] = newval;
		needsUpdate = true;
		return ac[1];
	}
	public @nogc @property int D(int newval){
		bd[1] = newval;
		needsUpdate = true;
		return bd[1];
	}
	public @nogc @property int x_0(int newval){
		xy0[0] = newval;
		needsUpdate = true;
		return xy0[0];
	}
	public @nogc @property int y_0(int newval){
		xy0[1] = newval;
		needsUpdate = true;
		return xy0[1];
	}+/
	public @nogc @property float A(){
		return transformPoints[0];
	}
	public @nogc @property float B(){
		return transformPoints[1];
	}
	public @nogc @property float C(){
		return transformPoints[2];
	}
	public @nogc @property float D(){
		return transformPoints[3];
	}
	public @nogc @property float x_0(){
		return tpOrigin[0];
	}
	public @nogc @property float y_0(){
		return tpOrigin[1];
	}
	public @nogc @property float A(float newval){
		transformPoints[0] = newval;
		needsUpdate = true;
		return transformPoints[0];
	}
	public @nogc @property float B(float newval){
		transformPoints[1] = newval;
		needsUpdate = true;
		return transformPoints[1];
	}
	public @nogc @property float C(float newval){
		transformPoints[2] = newval;
		needsUpdate = true;
		return transformPoints[2];
	}
	public @nogc @property float D(float newval){
		transformPoints[3] = newval;
		needsUpdate = true;
		return transformPoints[3];
	}
	public @nogc @property float x_0(float newval){
		tpOrigin[0] = newval;
		tpOrigin[2] = newval;
		needsUpdate = true;
		return tpOrigin[0];
	}
	public @nogc @property float y_0(float newval){
		tpOrigin[1] = newval;
		tpOrigin[3] = newval;
		needsUpdate = true;
		return tpOrigin[1];
	}
	/**
	 * Relative rotation clockwise by given degrees.
	 */
	public @nogc void rotate(double theta){
		import std.math;
		theta *= PI / 180;
		transformPoints[0] += cos(theta);
		transformPoints[1] += sin(theta);
		transformPoints[2] += -1.0 * sin(theta);
		transformPoints[3] += cos(theta);
		needsUpdate = true;
	}
	override public @safe @nogc void scroll(int x,int y) {
		super.scroll(x,y);
		needsUpdate = true;
	}
	override public @safe @nogc void relScroll(int x,int y) {
		super.relScroll(x,y);
		needsUpdate = true;
	}
	
}
/**
 *Used by the collision detectors
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
	public void moveSprite(int n, int x, int y);
	///Relatively moves the sprite by the given values.
	public void relMoveSprite(int n, int x, int y);
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
public class SpriteLayer : Layer, ISpriteCollision, ISpriteLayer{
	private ABitmap[int] spriteSet;			///Stores the sprites.
	private Coordinate[int] coordinates;		///Stores the coordinates.
	private BitmapAttrib[int] spriteAttributes;	///Stores spriteattributes. (layer priority, mirroring, etc.)
	private int[] spriteSorter;					///Stores the priorities.
	public SpriteMovementListener[int] collisionDetector;
	Color*[8] src;
	size_t[8] prevSize;
	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		setRenderingMode(renderMode);
		//src[0].length = 1024;
		for(int i; i < src.length; i++){
			src[i] = cast(Color*)malloc(256);
			prevSize[i]	= 256;
		}
	}
	~this(){
		foreach(p; src){
			if(p)
				free(p);
		}
	}
	
	public void addSprite(ABitmap s, int n, Coordinate c, BitmapAttrib attr){
		spriteSet[n] = s;
		coordinates[n] = c;
		spriteAttributes[n] = attr;
		spriteSorter ~= n;
		//sortSprites();
		spriteSorter.sort();
		
	}
	
	public void addSprite(ABitmap s, int n, int x, int y, BitmapAttrib attr){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.width,y+s.height);
		spriteAttributes[n] = attr;
		//spriteSorter[n] = n;
		spriteSorter ~= n;
		//sortSprites();
		
		spriteSorter.sort();
		
	}
	public void editSpriteAttribute(S, T)(int n, T value){
		spriteAttributes[n].S = value;
	}
	public void replaceSpriteAttribute(int n, BitmapAttrib attr){
		spriteAttributes[n] = attr;
	}
	public void replaceSprite(ABitmap s, int n){

		if(!(s.width == spriteSet[n].width && s.height == spriteSet[n].height)){
			coordinates[n] = Coordinate(coordinates[n].left,coordinates[n].top,coordinates[n].left + s.width,coordinates[n].top + s.height);
		}
		spriteSet[n] = s;
	}

	public void replaceSprite(ABitmap s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.width,y+s.height);
	}

	public void replaceSprite(ABitmap s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
	}
	
	/*public ushort getTransparencyIndex(){
		return transparencyIndex;
	}*/
	
	public void removeSprite(int n){
		//spriteSorter.remove(n);
		coordinates.remove(n);
		spriteAttributes.remove(n);
		spriteSet.remove(n);
		int[] newSpriteSorter;
		for(int i; i < spriteSorter.length; i++){
			//writeln(0);
			if(spriteSorter[i] != n){
				newSpriteSorter ~= spriteSorter[i];
				
			}
		}
		spriteSorter = newSpriteSorter;
		//writeln(spriteSorter);
		//sortSprites();
	}
	public void moveSprite(int n, int x, int y){
		coordinates[n].move(x,y);
		callCollisionDetector(n);
	}
	public void relMoveSprite(int n, int x, int y){
		coordinates[n].relMove(x,y);
		callCollisionDetector(n);
	}
	
	///Returns all sprite coordinates.
	public ref Coordinate[int] getCoordinates(){
		return coordinates;
	}
	///Returns all sprite attributes.
	public ref BitmapAttrib[int] getSpriteAttributes(){
		return spriteAttributes;
	}
	public ref int[] getSpriteSorter(){
		return spriteSorter;
	}
	
	private void callCollisionDetector(int n){
		foreach(c; collisionDetector){
			c.spriteMoved(n);
		}
	}
	
	public Coordinate getSpriteCoordinate(int n){
		return coordinates[n];
	}

	public override void updateRaster(void* workpad, int pitch, Color* palette, int[] threads){
		foreach_reverse(int i ; spriteSorter){
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				int offsetXA = sX > coordinates[i].left ? sX - coordinates[i].left : 0;//Left hand side offset
				int offsetXB = sX + rasterX < coordinates[i].right ? coordinates[i].right - rasterX : 0; //Right hand side offset
				int offsetYA = sY > coordinates[i].top ? sY - coordinates[i].top : 0;
				int offsetYB = sY + rasterY < coordinates[i].bottom ? coordinates[i].bottom - rasterY : 0;
				int sizeX = coordinates[i].width(), offsetX = coordinates[i].left - sX;
				int length = sizeX - offsetXA - offsetXB, lfour = length * 4;
				int offsetY = sY < coordinates[i].top ? (coordinates[i].top-sY)*pitch : 0;
				int pitchOffset = pitch * threads.length;
				int sizeXOffset = sizeX * threads.length;
				sizeXOffset *= spriteAttributes[i].vertMirror ? -1 : 1;
				ABitmap ab = spriteSet[i];
				/+switch(ab.classinfo){
					case typeid(Bitmap4Bit):+/
				if(ab.classinfo == typeid(Bitmap4Bit)){
					Bitmap4Bit bmp = cast(Bitmap4Bit)ab;
					ubyte* p0 = bmp.getPtr();
					if(spriteAttributes[i].vertMirror)
						p0 += (sizeX * (coordinates[i].height - offsetYB))>>1;
					else
						p0 += (sizeX * offsetYA)>>1;
					if(!spriteAttributes[i].horizMirror)
						p0 += offsetXA>>1;
					else
						p0 += offsetXB>>1;
					foreach(int threadOffset; threads.parallel){
						src[threadOffset] = cast(Color*)realloc(src[threadOffset], lfour);
						ubyte* p1 = p0 + threadOffset * sizeX;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						for(int y = offsetYA + threadOffset ; y < coordinates[i].height - offsetYB ; y+=threads.length){		
							main4BitColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)ab.getPalettePtr(), length, offsetXA);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src[threadOffset], length);
							}
							mainRenderingFunction(cast(uint*)src[threadOffset], cast(uint*)dest, length);
							dest += pitchOffset;
							p1 += sizeXOffset;
						}
					}
				}else if(ab.classinfo == typeid(Bitmap8Bit)){
						/+break;
					case typeid(Bitmap8Bit):+/
					Bitmap8Bit bmp = cast(Bitmap8Bit)ab;
					ubyte* p0 = bmp.getPtr();
					if(spriteAttributes[i].vertMirror)
						p0 += sizeX * (coordinates[i].height - offsetYB);
					else
						p0 += sizeX * offsetYA;
					if(!spriteAttributes[i].horizMirror)
						p0 += offsetXA;
					else
						p0 += offsetXB;
					foreach(int threadOffset; threads.parallel){
						src[threadOffset] = cast(Color*)realloc(src[threadOffset], lfour);
						ubyte* p1 = p0 + threadOffset * sizeX;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						for(int y = offsetYA + threadOffset ; y < coordinates[i].height - offsetYB ; y+=threads.length){		
							main8BitColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)ab.getPalettePtr(), length);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src[threadOffset], length);
							}
							mainRenderingFunction(cast(uint*)src[threadOffset], cast(uint*)dest, length);
							dest += pitchOffset;
							p1 += sizeXOffset;
						}
					}
				}else if(ab.classinfo == typeid(Bitmap16Bit)){
						/+break;
					case typeid(Bitmap16Bit):+/
					Bitmap16Bit bmp = cast(Bitmap16Bit)ab;
					ushort* p0 = bmp.getPtr();
					if(spriteAttributes[i].vertMirror)
						p0 += sizeX * (coordinates[i].height - offsetYB);
					else
						p0 += sizeX * offsetYA;
					if(!spriteAttributes[i].horizMirror)
						p0 += offsetXA;
					else
						p0 += offsetXB;
					foreach(int threadOffset; threads.parallel){
						if(prevSize[threadOffset] < lfour)
							src[threadOffset] = cast(Color*)realloc(src[threadOffset], lfour);
						ushort* p1 = p0 + threadOffset * sizeX;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						for(int y = offsetYA + threadOffset ; y < coordinates[i].height - offsetYB ; y+=threads.length){		
							mainColorLookupFunction(p1, cast(uint*)src[threadOffset], cast(uint*)palette, length);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								flipHorizontal(cast(uint*)src[threadOffset], length);
							}
							mainRenderingFunction(cast(uint*)src[threadOffset], cast(uint*)dest, length);
							dest += pitchOffset;
							p1 += sizeXOffset;
						}
					}
				}else if(ab.classinfo == typeid(Bitmap32Bit)){
						/+break;
					case typeid(Bitmap32Bit):+/
					Bitmap32Bit bmp = cast(Bitmap32Bit)ab;
					Color* p0 = bmp.getPtr();
					if(spriteAttributes[i].vertMirror)
						p0 += sizeX * (coordinates[i].height - offsetYB);
					else
						p0 += sizeX * offsetYA;
					if(!spriteAttributes[i].horizMirror)
						p0 += offsetXA;
					else
						p0 += offsetXB;
					foreach(int threadOffset; threads.parallel){
						if(spriteAttributes[i].horizMirror)
							src[threadOffset] = cast(Color*)realloc(src[threadOffset], lfour);
						Color* p1 = p0 + threadOffset * sizeX;
						void* dest = workpad + (offsetX + offsetXA)*4 + offsetY + threadOffset * pitch;
						for(int y = offsetYA + threadOffset ; y < coordinates[i].height - offsetYB ; y+=threads.length){		
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								copy32bit(cast(uint*)p1, cast(uint*)src[threadOffset], length);
								flipHorizontal(cast(uint*)src[threadOffset], length);
								mainRenderingFunction(cast(uint*)src[threadOffset], cast(uint*)dest, length);
							}else{
								mainRenderingFunction(cast(uint*)p1, cast(uint*)dest, length);
							}
							dest += pitchOffset;
							p1 += sizeXOffset;
						}
					}
					/+	break;
					default:
						break;+/
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