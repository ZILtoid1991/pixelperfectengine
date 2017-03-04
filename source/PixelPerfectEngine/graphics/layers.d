/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers module
 */
module PixelPerfectEngine.graphics.layers;

public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.common;
import std.conv;
import std.stdio;
import std.parallelism;
//import system.etc;
import PixelPerfectEngine.system.exc;
import std.algorithm;
import derelict.sdl2.sdl;
//import std.range;


//Used mainly to return both the color ID and the transparency at the same time to reduce CPU time.
/*public struct PixelData {
 public bool alpha;
 public ushort color;
 this(bool a, ushort c){
 alpha = a;
 color = c;
 }
 }*/

static immutable ushort[4] alphaMMXmul_const256 = [256,256,256,256];
static immutable ushort[4] alphaMMXmul_const1 = [1,1,1,1];
static immutable ushort[8] alphaSSEConst256 = [256,256,256,256,256,256,256,256];
static immutable ushort[8] alphaSSEConst1 = [1,1,1,1,1,1,1,1];
static immutable uint[4] SSEUQWmaxvalue = [0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF] ;

//static immutable uint[2] alphaMMXmul_0 = [1,1];

public enum FlipRegister : ubyte {
	NORM	=	0x00,
	X		=	0x01,
	Y		=	0x02,
	XY		=	0x03
}

/*public interface ILayer{
	// Returns color.
	//public ushort getPixel(ushort x, ushort y);
	// Returns if the said pixel's color is equals with the transparent color index.
	//public bool isTransparent(ushort x, ushort y);
	// Returns the PixelData.
	//public PixelData getPixelData(ushort x, ushort y);
	
	public void setRasterizer(int rX, int rY);
	public void updateRaster(Bitmap16Bit frameBuffer);
	public void updateRaster(void* workpad, int pitch, ubyte[] palette);
}*/

abstract class Layer {
	protected LayerRenderingMode renderMode;
	
	// scrolling position
	protected int sX, sY, rasterX, rasterY;
	//Deprecated
	//private ushort transparencyIndex;
	//Deprecated. Set color 0 as transparent instead
	/*public void setTransparencyIndex(ushort color){
		transparencyIndex = color;
	}*/
	
	public void setRasterizer(int rX, int rY){
		//frameBuffer = frameBufferP;
		rasterX=rX;
		rasterY=rY;
		
	}
	
	///Absolute scrolling.
	public void scroll(int x, int y){
		sX=x;
		sY=y;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public void relScroll(int x, int y){
		sX=sX+x;
		sY=sY+y;
	}
	///Getter for the X scroll position.
	public int getSX(){
		return sX;
	}
	///Getter for the Y scroll position.
	public int getSY(){
		return sY;
	}
	/// Override this to enable output to the raster
	public abstract void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads);
	protected void colorLookup(ushort* src, void* dest, ubyte* palette, int length){
		for(int i; i < length; i++){
			*cast(ubyte[4]*)dest = *cast(ubyte[4]*)(palette + 4 * *(src+i));
			dest += 4;
		}
	}
	protected void createAlphaMask(void* src, void* alpha, int length){
		asm{
			//setting up the pointer registers and the counter registers
			mov		ESI, src[EBP];
			mov		EDI, alpha[EBP];
			mov		ECX, length;
			//iteration cycle entry point
		alphamaskcreation:
			xor		EAX, EAX;
			mov		BL, [ESI];
			add		AL,	BL;
			rol		EAX, 8;
			add		AL,	BL;
			rol		EAX, 8;
			add		AL,	BL;
			rol		EAX, 8;
			add		AL,	BL;
			mov		[EDI], EAX;
			add		ESI, 4;
			add		EDI, 4;
			dec		ECX;
			cmp		ECX, 0;
			jnz		alphamaskcreation;
		}
	}
	protected void alphaBlend(void* src, void* dest, void* alpha, int length){
		int target16 = length/4, target4 = length%4;
		//if(target4) writeln(length);
		asm{
			//setting up the pointer registers and the counter register
			mov		EBX, alpha[EBP];
			mov		ESI, src[EBP];
			mov		EDI, dest[EBP];
			mov		ECX, target16;
			cmp		ECX, 0;
			jz		fourpixelblend; //skip 16 byte operations if not needed
			//iteration cycle entry point
		sixteenpixelblend:
			movups	XMM0, [EBX];
			movups	XMM1, XMM0;
			punpcklbw	XMM0, XMM2;
			punpckhbw	XMM1, XMM2;
			movups	XMM6, alphaSSEConst256;
			movups	XMM7, XMM6;
			movups	XMM4, alphaSSEConst1;
			movups	XMM5, XMM4;
			
			paddusw	XMM4, XMM0;	//1 + alpha01
			paddusw	XMM5, XMM1;
			psubusw	XMM6, XMM0;	//256 - alpha01
			psubusw	XMM7, XMM1;
			
			//moving the values to their destinations

			movups	XMM0, [ESI];	//src01
			movups	XMM1, XMM0; //src23
			punpcklbw	XMM0, XMM2;
			punpckhbw	XMM1, XMM2;
			pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
			pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
			movups	XMM0, [EDI];	//dest01
			movups	XMM1, XMM0;		//dest23
			punpcklbw	XMM0, XMM2;
			punpckhbw	XMM1, XMM2;
			pmullw	XMM6, XMM0;	//dest01 * (256 - alpha)
			pmullw	XMM7, XMM1; //dest23 * (256 - alpha)
			
			paddusw	XMM4, XMM6;	//(src01 * (1 + alpha01)) + (dest01 * (256 - alpha01))
			paddusw	XMM5, XMM7; //(src * (1 + alpha)) + (dest * (256 - alpha))
			psrlw	XMM4, 8;		//(src * (1 + alpha)) + (dest * (256 - alpha)) / 256
			psrlw	XMM5, 8;
			//moving the result to its place;
			//pxor	MM2, MM2;
			packuswb	XMM4, XMM5;
			
			movups	[EDI], XMM4;
			add		EBX, 16;
			add		ESI, 16;
			add		EDI, 16;
			dec		ECX;
			cmp		ECX, 0;
			jnz		sixteenpixelblend;

		fourpixelblend:

			mov		ECX, target4;
			cmp		ECX, 0;
			jz		endofalgorithm;

		fourpixelblendloop:

			movd	XMM6, [EBX];//alpha
			punpcklbw	XMM6, XMM2;

			movd	XMM0, [EDI];
			movd	XMM1, [ESI];
			punpcklbw	XMM0, XMM2;//dest
			punpcklbw	XMM1, XMM2;//src

			movaps	XMM4, alphaSSEConst256;
			movaps	XMM5, alphaSSEConst1;
				
			paddusw XMM5, XMM6;//1+alpha
			psubusw	XMM4, XMM6;//256-alpha
				
			pmullw	XMM0, XMM4;//dest*(256-alpha)
			pmullw	XMM1, XMM5;//src*(1+alpha)
			paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
			psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
				
			packuswb	XMM0, XMM3;
				
			movd	[EDI], XMM0;
			add		EBX, 4;
			add		ESI, 4;
			add		EDI, 4;
			dec		ECX;
			cmp		ECX, 0;
			jnz		fourpixelblendloop;

		endofalgorithm:
			;
		}
	}
	protected void blitter(void* src, void* dest, void* alpha, int length){
		int target16 = length/4, target4 = length%4;
		asm{
			//setting up the pointer registers and the counter register
			mov		EBX, alpha[EBP];
			mov		ESI, src[EBP];
			mov		EDI, dest[EBP];
			mov		ECX, target16;
			cmp		ECX, 0;
			jz		fourpixelblend; //skip 16 byte operations if not needed
			//iteration cycle entry point
		sixteenpixelblend:
			movups	XMM2, [EBX];
			movups	XMM0, [ESI];	//src01
			movups	XMM1, [EDI];	//dest01
			pcmpeqd	XMM2, XMM3;
			pand	XMM1, XMM2;
			por		XMM1, XMM0;
			movups	[EDI], XMM1;
			add		EBX, 16;
			add		ESI, 16;
			add		EDI, 16;
			dec		ECX;
			cmp		ECX, 0;
			jnz		sixteenpixelblend;

		fourpixelblend:
			
			mov		ECX, target4;
			cmp		ECX, 0;
			jz		endofalgorithm;

		fourpixelblendloop:
			
			movd	XMM2, [EBX];
			movd	XMM0, [ESI];
			movd	XMM1, [EDI];
			pcmpeqd	XMM2, XMM3;
			pand	XMM1, XMM2;
			por		XMM1, XMM0;
			movd	[EDI], XMM1;
			add		EBX, 4;
			add		ESI, 4;
			add		EDI, 4;
			dec		ECX;
			cmp		ECX, 0;
			jnz		fourpixelblendloop;
			
		endofalgorithm:
			;
		}
	}
	protected void copyRegion(void* src, void* dest, int length){
		int target16 = length/4, target4 = length%4;
		asm{
			//setting up the pointer registers and the counter register
			//mov		EBX, alpha[EBP];
			mov		ESI, src[EBP];
			mov		EDI, dest[EBP];
			mov		ECX, target16;
			cmp		ECX, 0;
			jz		fourpixelblend; //skip 16 byte operations if not needed
			//iteration cycle entry point
		sixteenpixelblend:
			movups	XMM0, [ESI];	
			movups	[EDI], XMM0;
			add		ESI, 16;
			add		EDI, 16;
			dec		ECX;
			cmp		ECX, 0;
			jnz		sixteenpixelblend;
			
		fourpixelblend:
			
			mov		ECX, target4;
			cmp		ECX, 0;
			jz		endofalgorithm;
			
		fourpixelblendloop:

			movd	XMM0, [ESI];
			movd	[EDI], XMM0;
			add		ESI, 4;
			add		EDI, 4;
			dec		ECX;
			cmp		ECX, 0;
			jnz		fourpixelblendloop;
			
		endofalgorithm:
			;
		}
	}
	protected void flipHorizontal(void* src, int length){
		int c = length / 2, dest = c * 4;
		asm{
			mov		ESI, src[EBP];
			mov		EDI, ESI;
			add		EDI, dest;
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
/*
 *Used by the background-sprite tester.
 */
public interface ITileLayer{
	public BLInfo getLayerInfo();
	public Bitmap16Bit getTile(wchar id);
	public wchar[] getMapping();
}
/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 */
public class TileLayer : Layer, ITileLayer{
	private int tileX, tileY, mX, mY;
	private int totalX, totalY;
	private wchar[] mapping;
	
	private Bitmap16Bit[wchar] tileSet;
	private bool wrapMode; 
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		this.renderMode = renderMode;
	}
	/// Wrapmode: if enabled, the layer will be turned into an "infinite" mode.
	public void setWrapMode(bool w){
		wrapMode = w;
	}
	///Gets the the ID of the given element from the mapping. x , y : Position.
	public wchar readMapping(int x, int y){
		/*if(x<0 || x>totalX/tileX){
		 return 0xFFFF;
		 }*/
		return mapping[x+(mX*y)];
	}
	///Writes to the map. x , y : Position. w : ID of the tile.
	public void writeMapping(int x, int y, wchar w){
		mapping[x+(mX*y)]=w;
	}
	//Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	//x*y=map.length
	public void loadMapping(int x, int y, wchar[] map){
		mX=x;
		mY=y;
		mapping = map;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	//Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(Bitmap16Bit t, wchar id){
		if(t.getX()==tileX && t.getY()==tileY){
			tileSet[id]=t;
		}
		else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	//Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		tileSet.remove(id);
	}

	public wchar tileByPixel(int x, int y){
		if(x/tileX + (y/tileY)*mX < 0 || x/tileX + (y/tileY)*mX >= mapping.length) return 0xFFFF;
		return mapping[x/tileX + (y/tileY)*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		ubyte[] src, alpha;
		//int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
		src.length = tileX * 4;
		alpha.length = tileX * 4;
		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		switch(renderMode){
			case LayerRenderingMode.ALPHA_BLENDING:
				int y = sY < 0 ? sY * -1 : 0;
				//int yBegin = sY < 0 ? sY * -1 : 0;
				/*if(wrapMode){
				 y = sX + 0x7FFFFFFF;
				 }else{
				 y = sX < 0 ? 0 : sX;
				 }*/
				for( ; y < rasterY ; y++){

					int offsetP = y*pitch;	// The offset of the line that is being written
					int offsetY = tileY * ((y + sY)%tileY);
					int offsetX = sX%tileX;	// tile offset of the last column
					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){
						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0xFFFF){ // skip if tile is null
							//writeln(x);
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX) ;	// the length of the displayed tile
							//if(tileXtarget + x > ){}
							int xp = (offsetX != 0 && x == 0) ? offsetX : 0;	// offset of the first tile
							tileXtarget -= xp > 0 ? tileX - offsetX : 0;	// length of the first tile
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							c += xp;
							colorLookup(c, src.ptr, palette, tileXtarget);
							createAlphaMask(src.ptr, alpha.ptr, tileXtarget);
							alphaBlend(src.ptr, p0, alpha.ptr, tileXtarget);
							p0 += (tileX - xp) * 4;
							x+=tileX - xp;
						}else{
							x+=tileX;
						}


					}
					
				}
				break;
			case LayerRenderingMode.BLITTER:
				int y = sY < 0 ? sY * -1 : 0;

				for( ; y < rasterY ; y++){
					
					int offsetP = y*pitch;	// The offset of the line that is being written
					int offsetY = tileY * ((y + sY)%tileY);
					int offsetX = sX%tileX;	// tile offset of the last column
					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){
						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0xFFFF){ // skip if tile is null
							//writeln(x);
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX) ;	// the length of the displayed tile
							//if(tileXtarget + x > ){}
							int xp = (offsetX != 0 && x == 0) ? offsetX : 0;	// offset of the first tile
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							c += xp;
							colorLookup(c, src.ptr, palette, tileXtarget);
							createAlphaMask(src.ptr, alpha.ptr, tileXtarget);
							blitter(src.ptr, p0, alpha.ptr, tileXtarget);
							p0 += (tileX - xp) * 4;
							x+=tileX - xp;
						}else{
							x+=tileX;
						}
						
						
					}
					
				}
				break;
			default:
				int y = sY < 0 ? sY * -1 : 0;
				
				for( ; y < rasterY ; y++){
					
					int offsetP = y*pitch;	// The offset of the line that is being written
					int offsetY = tileY * ((y + sY)%tileY);
					int offsetX = sX%tileX;	// tile offset of the last column
					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){
						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0xFFFF){ // skip if tile is null
							//writeln(x);
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX) ;	// the length of the displayed tile
							//if(tileXtarget + x > ){}
							int xp = (offsetX != 0 && x == 0) ? offsetX : 0;	// offset of the first tile
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							c += xp;
							colorLookup(c, src.ptr, palette, tileXtarget);
							//alphaBlend(src.ptr, p0, alpha.ptr, tileXtarget);
							p0 += (tileX - xp) * 4;
							x+=tileX - xp;
						}else{
							x+=tileX;
						}
						
						
					}
					
				}
				break;
		}
	}
	
	public BLInfo getLayerInfo(){
		return BLInfo(tileX,tileY,mX,mY);
	}
	public Bitmap16Bit getTile(wchar id){
		return tileSet[id];
	}
	public wchar[] getMapping(){
		return mapping;
	}
}
/*
 *Used by the collision detectors
 */
public interface ISpriteCollision{
	//public Bitmap16Bit[int] getSpriteSet();
	public Coordinate[int] getCoordinates();
	public FlipRegister[int] getFlipRegisters();
	public int[int] getSpriteSorter();
	//public ushort getTransparencyIndex();
}

public interface ISpriteLayer{
	//public void addSprite(Bitmap16Bit s, int n, Coordinate c);
	//public void addSprite(Bitmap16Bit s, int n, int x, int y);
	public void removeSprite(int n);
	public void moveSprite(int n, int x, int y);
	public void relMoveSprite(int n, int x, int y);
}
public interface ISpriteLayer16Bit : ISpriteLayer{
	public void addSprite(Bitmap16Bit s, int n, Coordinate c);
	public void addSprite(Bitmap16Bit s, int n, int x, int y);
	public void replaceSprite(Bitmap16Bit s, int n);
	public void replaceSprite(Bitmap16Bit s, int n, int x, int y);
	public void replaceSprite(Bitmap16Bit s, int n, Coordinate c);
}
public interface ISpriteLayer32Bit : ISpriteLayer{
	public void addSprite(Bitmap32Bit s, int n, Coordinate c);
	public void addSprite(Bitmap32Bit s, int n, int x, int y);
	public void replaceSprite(Bitmap32Bit s, int n);
	public void replaceSprite(Bitmap32Bit s, int n, int x, int y);
	public void replaceSprite(Bitmap32Bit s, int n, Coordinate c);
}
/*
 *Use it to call the collision detector
 */
public interface SpriteMovementListener{
	void spriteMoved(int ID);
}
/**
 *Sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteCollision, ISpriteLayer16Bit{
	private Bitmap16Bit[int] spriteSet;
	private Coordinate[int] coordinates;		//Use moveSprite() and relMoveSprite() instead to move sprites
	private FlipRegister[int] flipRegisters;
	private int[] spriteSorter;
	public SpriteMovementListener[int] collisionDetector;
	//Constructors. 
	/*public this(int n){
	 spriteSet.length = n;
	 coordinates.length = n;
	 flipRegisters.length = n;
	 }*/
	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		this.renderMode = renderMode;
	}
	
	public void addSprite(Bitmap16Bit s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
		flipRegisters[n] = FlipRegister.NORM;
		spriteSorter ~= n;
		//sortSprites();
		spriteSorter.sort();
		
	}
	
	public void addSprite(Bitmap16Bit s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.getX(),y+s.getY());
		flipRegisters[n] = FlipRegister.NORM;
		//spriteSorter[n] = n;
		spriteSorter ~= n;
		//sortSprites();
		
		spriteSorter.sort();
		
	}
	/**
	 * 
	 */
	public void replaceSprite(Bitmap16Bit s, int n){

		if(!(s.getX == spriteSet[n].getX && s.getY == spriteSet[n].getY)){
			coordinates[n] = Coordinate(coordinates[n].left,coordinates[n].top,coordinates[n].left + s.getX,coordinates[n].top + s.getY);
		}
		spriteSet[n] = s;
	}

	public void replaceSprite(Bitmap16Bit s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.getX(),y+s.getY());
	}

	public void replaceSprite(Bitmap16Bit s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
	}
	
	/*public ushort getTransparencyIndex(){
		return transparencyIndex;
	}*/
	
	public void removeSprite(int n){
		//spriteSorter.remove(n);
		coordinates.remove(n);
		flipRegisters.remove(n);
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
	
	public Bitmap16Bit[int] getSpriteSet(){
		return spriteSet;
	}
	
	public Coordinate[int] getCoordinates(){
		return coordinates;
	}
	
	public FlipRegister[int] getFlipRegisters(){
		return flipRegisters;
	}
	public int[int] getSpriteSorter(){
		return null;
	}
	
	private void callCollisionDetector(int n){
		foreach(c; collisionDetector){
			c.spriteMoved(n);
		}
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		switch(renderMode){
			case LayerRenderingMode.ALPHA_BLENDING:
				foreach_reverse(int i ; spriteSorter){
					/*foreach(int i ; spriteSet.byKey){*/
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
						//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ushort* p0 = spriteSet[i].getPtr();
						ubyte[] src, alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						src.length = l4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							//ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//int x = offsetXA;
							
							//if(x < 0) writeln(x); 
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								flipHorizontal(src.ptr, length);
								createAlphaMask(src.ptr, alpha.ptr, length);

								alphaBlend(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);
							}
							else{ //for non flipped sprites
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								createAlphaMask(src.ptr, alpha.ptr, length);

								alphaBlend(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);/* */
							}
						}
					}
				}
				break;
			case LayerRenderingMode.BLITTER:
				foreach_reverse(int i ; spriteSorter){
					/*foreach(int i ; spriteSet.byKey){*/
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
						//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ushort* p0 = spriteSet[i].getPtr();
						ubyte[] src, alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						src.length = l4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							//ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//int x = offsetXA;
							
							//if(x < 0) writeln(x); 
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								flipHorizontal(src.ptr, length);
								createAlphaMask(src.ptr, alpha.ptr, length);

								blitter(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);
							}
							else{ //for non flipped sprites
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								createAlphaMask(src.ptr, alpha.ptr, length);

								blitter(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);/* */
							}
						}
					}
				}
				break;
			default:
				foreach_reverse(int i ; spriteSorter){
					/*foreach(int i ; spriteSet.byKey){*/
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
						//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ushort* p0 = spriteSet[i].getPtr();
						ubyte[] src, alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						src.length = l4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							//ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//int x = offsetXA;
							
							//if(x < 0) writeln(x); 
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								flipHorizontal(src.ptr, length);
								//createAlphaMask(src.ptr, alpha.ptr, length);

								copyRegion(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, length);
							}
							else{ //for non flipped sprites
								colorLookup(p0 + offsetXA + offsetP, src.ptr, palette, length);
								//createAlphaMask(src.ptr, alpha.ptr, length);

								copyRegion(src.ptr, workpad + (offsetX + offsetXA)*4 + offsetY, length);/* */
							}
						}
					}
				}
				break;
		}
	}

}

public class SpriteLayer32Bit : Layer, ISpriteCollision, ISpriteLayer32Bit{
	private Bitmap32Bit[int] spriteSet;
	private Coordinate[int] coordinates;		//Use moveSprite() and relMoveSprite() instead to move sprites
	private FlipRegister[int] flipRegisters;
	private int[] spriteSorter;
	public SpriteMovementListener[int] collisionDetector;

	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		this.renderMode = renderMode;
	}
	
	public void addSprite(Bitmap32Bit s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
		flipRegisters[n] = FlipRegister.NORM;
		spriteSorter ~= n;
		//sortSprites();
		spriteSorter.sort();
		
	}
	
	public void addSprite(Bitmap32Bit s, int n, int x, int y){
		writeln(s);
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+spriteSet[n].getX,y+spriteSet[n].getY);
		flipRegisters[n] = FlipRegister.NORM;
		//spriteSorter[n] = n;
		spriteSorter ~= n;
		//sortSprites();
		
		spriteSorter.sort();
		
	}

	public void replaceSprite(Bitmap32Bit s, int n){
		if(!(s.getX == spriteSet[n].getX && s.getY == spriteSet[n].getY)){
			coordinates[n] = Coordinate(coordinates[n].left,coordinates[n].top,coordinates[n].left + s.getX,coordinates[n].top + s.getY);
		}
		spriteSet[n] = s;
	}
	public void replaceSprite(Bitmap32Bit s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.getX(),y+s.getY());
	}
	public void replaceSprite(Bitmap32Bit s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
	}
	
	/*public ushort getTransparencyIndex(){
		return transparencyIndex;
	}*/
	
	public void removeSprite(int n){
		//spriteSorter.remove(n);
		coordinates.remove(n);
		flipRegisters.remove(n);
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
	
	public Bitmap32Bit[int] getSpriteSet(){
		return spriteSet;
	}
	
	public Coordinate[int] getCoordinates(){
		return coordinates;
	}
	
	public FlipRegister[int] getFlipRegisters(){
		return flipRegisters;
	}
	public int[int] getSpriteSorter(){
		return null;
	}
	
	private void callCollisionDetector(int n){
		foreach(c; collisionDetector){
			c.spriteMoved(n);
		}
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		switch(renderMode){
			case LayerRenderingMode.ALPHA_BLENDING:
				foreach_reverse(int i ; spriteSorter){
			
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
					//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ubyte* src = spriteSet[i].getPtr();
						//writeln(p0);
						ubyte[] alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//src + offsetXA + offsetP;
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						
							}
							else{ //for non flipped sprites
								createAlphaMask(src + offsetXA + offsetP, alpha.ptr, length);
								alphaBlend(src + offsetXA + offsetP, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);/* */
							}
						}
					}
				}
				break;
			case LayerRenderingMode.BLITTER:
				foreach_reverse(int i ; spriteSorter){
			
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
					//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ubyte* src = spriteSet[i].getPtr();
						//writeln(p0);
						ubyte[] alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//src + offsetXA + offsetP;
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						
							}
							else{ //for non flipped sprites
								createAlphaMask(src + offsetXA + offsetP, alpha.ptr, length);
								blitter(src + offsetXA + offsetP, workpad + (offsetX + offsetXA)*4 + offsetY, alpha.ptr, length);/* */
							}
						}
					}
				}
				break;
			default:
				foreach_reverse(int i ; spriteSorter){
			
					if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
					//writeln(i);
						int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
						if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
						if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
						if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
						if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
						ubyte* src = spriteSet[i].getPtr();
						//writeln(p0);
						ubyte[] alpha;
						int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
						alpha.length = l4;
						for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
							int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
							//src + offsetXA + offsetP;
							if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
								
								/*copyRegion(src + offsetXA + offsetP, workpad + (offsetX + offsetXA)*4 + offsetY, length);/* */
							}
							else{ //for non flipped sprites
								//createAlphaMask(src + offsetXA + offsetP, alpha.ptr, length);
								copyRegion(src + offsetXA + offsetP, workpad + (offsetX + offsetXA)*4 + offsetY, length);/* */
							}
						}
					}
				}
				break;
		}
	}
}