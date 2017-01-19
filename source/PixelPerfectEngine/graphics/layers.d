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
	
	
	// scrolling position
	private int sX, sY, rasterX, rasterY;
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
	
	//Absolute scrolling.
	public void scroll(int x, int y){
		sX=x;
		sY=y;
	}
	//Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	public void relScroll(int x, int y){
		sX=sX+x;
		sY=sY+y;
	}
	//Getters for the scroll positions.
	public int getSX(){
		return sX;
	}
	public int getSY(){
		return sY;
	}
	/// Override this to enable output to the raster
	public abstract void updateRaster(void* workpad, int pitch, ubyte[] palette, int[] threads);
	

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
public enum TileLayerRenderingMode{
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
	private TileLayerRenderingMode renderMode;
	private Bitmap16Bit[wchar] tileSet;
	private bool wrapMode; 
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, TileLayerRenderingMode renderMode = TileLayerRenderingMode.ALPHA_BLENDING){
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
	
	public override void updateRaster(void* workpad, int pitch, ubyte[] palette, int[] threads){

		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		switch(renderMode){
			case TileLayerRenderingMode.ALPHA_BLENDING:
				int y = sY < 0 ? sY * -1 : 0;
				//int yBegin = sY < 0 ? sY * -1 : 0;
				/*if(wrapMode){
				 y = sX + 0x7FFFFFFF;
				 }else{
				 y = sX < 0 ? 0 : sX;
				 }*/
				for( ; y < rasterY ; y++){
					//writeln(y);
					//if((sY + y >= totalY) && !wrapMode) break;
					//if(y + sY >= 0){
					int offsetP = y*pitch;	// The offset of the line that is being written
					int offsetY = tileY * ((y + sY)%tileY);
					int offsetX = sX%tileX;
					//int outscrollX = sX<0 ? sX*-1 : 0;
					//int tnXreg = (sX-(sX%tileX))/tileX;		
					//int tnXC = tnXreg + (rasterX/tileX);
					//bool finish;
					//writeln(offsetY);
					//while(!finish){
					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){
						//writeln(tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY)));
						//ushort[] chunk = tileSet[mapping[tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY))]].readRow((y+sY)%tileY);
						
						//ushort *c = tileSet[mapping[tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY))]].getPtr();

						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0xFFFF){ // skip if tile is null
							//writeln(currentTile);
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX);	// 
							//if(tileXtarget + x > ){}
							int xp = (offsetX != 0 && x == 0) ? offsetX : 0;	// 
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							c += xp;
							//int foo = (tnXreg*tileX);
							for(; xp < tileXtarget-3; xp+=4){

								ubyte[16] *p = cast(ubyte[16]*)p0;
								//writeln(p,',',x,',',y,',',xp);
								ubyte[16] src;
								//writeln(*c);
								*cast(ubyte[4]*)(src.ptr) = *cast(ubyte[4]*)(palette.ptr + (4 * *c));
								c++;
								*cast(ubyte[4]*)(src.ptr + 4) = *cast(ubyte[4]*)(palette.ptr + (4 * *c));
								c++;
								*cast(ubyte[4]*)(src.ptr + 8) = *cast(ubyte[4]*)(palette.ptr + (4 * *c));
								c++;
								*cast(ubyte[4]*)(src.ptr + 12) = *cast(ubyte[4]*)(palette.ptr + (4 * *c));
								c++;
								ubyte[16] alpha = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];
								//uint[4] alpha;
								//writeln(src);
								asm{
									//calculating alpha
									//pxor	XMM1, XMM1;
									movups	XMM0, alpha;
									
									movups	XMM1, XMM0;
									punpcklbw	XMM0, XMM2;
									punpckhbw	XMM1, XMM2;
									movaps	XMM6, alphaSSEConst256;
									movaps	XMM7, XMM6;
									movaps	XMM4, alphaSSEConst1;
									movaps	XMM5, XMM4;
									
									
									//punpcklbw	XMM1, XMM2;
									
									paddusw	XMM4, XMM0;	//1 + alpha01
									paddusw	XMM5, XMM1;
									psubusw	XMM6, XMM0;	//256 - alpha01
									psubusw	XMM7, XMM1;
									
									//moving the values to their destinations
									mov		EBX, p[EBP];
									movups	XMM0, src;	//src01
									movups	XMM1, XMM0; //src23
									punpcklbw	XMM0, XMM2;
									punpckhbw	XMM1, XMM2;
									pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
									pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
									movups	XMM0, [EBX];	//dest01
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
									
									movups	[EBX], XMM4;
									
									//emms;
								}
								//writeln(*p);
								x+=4;
								p0+=16;
							}
							for(; xp < tileXtarget; xp++){
								ubyte[4] *p = cast(ubyte[4]*)p0;
								ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								ushort[4] alpha = [src[0],src[0],src[0],src[0]];
								asm{
									pxor	XMM3, XMM3;
									movq	XMM2, alpha;
									mov		EBX, p[EBP];
									movd	XMM0, [EBX];
									movd	XMM1, src;
									punpcklbw	XMM0, XMM3;//dest
									punpcklbw	XMM1, XMM3;//src
									//punpcklbw	XMM2, XMM3;//alpha
									movaps	XMM4, alphaSSEConst256;
									movaps	XMM5, alphaSSEConst1;
									
									paddusw XMM5, XMM2;//1+alpha
									psubusw	XMM4, XMM2;//256-alpha
									
									pmullw	XMM0, XMM4;//dest*(256-alpha)
									pmullw	XMM1, XMM5;//src*(1+alpha)
									paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
									psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
									//pxor	XMM7, XMM7;
									packuswb	XMM0, XMM3;
									
									movd	[EBX], XMM0;
									
									//pxor	XMM0, XMM0;
									//pxor	XMM1, XMM1;
									pxor	XMM2, XMM2;
								}
								x++;
								p0+=4;
							}
							/*ushort c = chunk[x];
							 alphaBlend(palette[(c*4)+1],palette[(c*4)+2],palette[(c*4)+3],palette[(c*4)], workpad + ((tnXreg*tileX)+x-sX)*4 + y*pitch);*/
							
							
						}else{
							x+=tileX;
						}
					}
					
				}break;
			case TileLayerRenderingMode.BLITTER:
				int y = sY < 0 ? sY * -1 : 0;

				for( ; y < rasterY ; y++){

					int offsetP = y*pitch;	// The offset of the line that is being written
					int offsetY = tileY * ((y + sY)%tileY);
					int offsetX = sX%tileX;

					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){

						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0xFFFF){
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX);	// 

							//int xp;	// 
							int xp = (offsetX != 0 && x == 0) ? offsetX : 0;	// 
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							c += xp;
							//int foo = (tnXreg*tileX);
							for(; xp < tileXtarget-3; xp+=4){
								
								ubyte[16] *p = cast(ubyte[16]*)p0;
								ubyte[16] src;
								*cast(ubyte[4]*)(src.ptr) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 4) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 8) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 12) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								ubyte[16] alpha = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];

								asm{
									//generating copying mask
									pxor	XMM1, XMM1;
									movups	XMM0, alpha;
									pcmpgtd	XMM0, XMM1;

									mov		EBX, p[EBP];
									movups	XMM2, src;
									movups	XMM3, [EBX];
									//the blitter algorithm
									pand	XMM3, XMM0;
									por		XMM3, XMM2;
									//writeback
									movups	[EBX], XMM3;

								}
								x+=4;
								p0+=16;
							}
							for(; xp < tileXtarget; xp++){
								ubyte[4] *p = cast(ubyte[4]*)p0;
								ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								ubyte[4] alpha = [src[0],src[0],src[0],src[0]];
								asm{
									//generating copying mask
									pxor	XMM1, XMM1;
									movd	XMM0, alpha;
									pcmpgtd	XMM0, XMM1;
									
									mov		EBX, p[EBP];
									movd	XMM2, src;
									movd	XMM3, [EBX];
									//the blitter algorithm
									pand	XMM3, XMM0;
									por		XMM3, XMM2;
									//writeback
									movd	[EBX], XMM3;

								}
								x++;
								p0+=4;
							}

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
					int offsetY = tileY * (y - sY)%tileY;
					
					int x = sX < 0 ? sX * -1 : 0;
					int targetX = totalX - sX > rasterX ? rasterX : rasterX - (totalX - sX);
					void *p0 = (workpad + (x*4) + offsetP);
					while(x < targetX){
						
						wchar currentTile = tileByPixel(x+sX,y+sY);
						if(currentTile != 0x0000){
							int tileXtarget = x + tileX < rasterX ? tileX : tileX - ((x + tileX) - rasterX);	// 
							
							int xp;	// 
							ushort *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
							c += offsetY;
							//int foo = (tnXreg*tileX);
							for(; xp < tileXtarget-3; xp+=4){
								
								ubyte[16] *p = cast(ubyte[16]*)p0;
								ubyte[16] src;
								*cast(ubyte[4]*)(src.ptr) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 4) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 8) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								*cast(ubyte[4]*)(src.ptr + 12) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
								c++;
								//ubyte[16] alpha = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];
								
								asm{

									mov		EBX, p[EBP];
									movups	XMM2, src;
									//writeback
									movups	[EBX], XMM2;
									
								}
								x+=4;
								p0+=16;
							}
							for(; xp < tileXtarget; xp++){
								ubyte[4] *p = cast(ubyte[4]*)p0;
								ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);

								c++;
								//ubyte[4] alpha = [src[0],src[0],src[0],src[0]];
								asm{

									mov		EBX, p[EBP];
									movd	XMM2, src;
									//writeback
									movd	[EBX], XMM2;
									
								}
								x++;
								p0+=4;
							}
							
						}else{
							x+=tileX;
						}
					}
					
				}
				break;
		}
	}
	
	public void updateRaster(Bitmap16Bit frameBuffer){
		if(sX + rasterX <= 0 || sX > totalX) return;
		for(int y ; y < rasterY ; y++){
			if(sY + y >= totalY) break;
			if(y + sY >= 0){
				
				//int outscrollX = sX<0 ? sX*-1 : 0;
				int tnXreg = sX>0 ? (sX-(sX%tileX))/tileX : 0;
				//int tnXC = tnXreg + (rasterX/tileX);
				bool finish;
				while(!finish){
					//writeln(tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY)));
					ushort[] chunk = tileSet[mapping[tnXreg+(mX*((y+sY-((y+sY)%tileY))/tileY))]].readRow((y+sY)%tileY);
					for(int x; x <tileX; x++){
						
						if((tnXreg*tileX)+x-sX >= 0 && (tnXreg*tileX)+x-sX < rasterX){
							frameBuffer.writePixel((tnXreg*tileX)+x-sX,y,chunk[x]);
						}else if((tnXreg*tileX)+x-sX >= rasterX){
							finish = true;
						}
					}
					tnXreg++;
					if(tnXreg == mX){ finish = true;}
				}
			}
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
	
	public this(){
		
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
	
	public override void updateRaster(void* workpad, int pitch, ubyte[] palette, int[] threads){
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
				for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
					//ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
					int offsetP = sizeX * y, offsetY = (coordinates[i].top - sY + y)*pitch;
					int x = offsetXA;
					//if(x < 0) writeln(x); 
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						for(; x < sizeX - offsetXB ; x+=4){
							ushort* c = (p0 + (sizeX - x - 1) + offsetP);

							//ushort c = chunk[chunk.length-x-1];
							//alphaBlend(palette[(c*4)+1],palette[(c*4)+2],palette[(c*4)+3],palette[(c*4)], workpad + (coordinates[i].xa - sX + x)*4 + (coordinates[i].ya - sY + y)*pitch);
							//alphaBlend(*cast(ubyte[4]*)(palette.ptr + 4 * c), workpad + (coordinates[i].xa - sX + x)*4 + (coordinates[i].ya - sY + y)*pitch);
							//ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							//ubyte[4] *p = cast(ubyte[4]*)(workpad + (offsetX + x)*4 + offsetY);
							/*if(src[0] == 255){
								*p = src;
							}
							else if(src[0] != 0){
								ubyte[4] dest2 = *p;
								dest2[1] = to!ubyte((src[1] * src[0] + dest2[1] * (255 - src[0]))>>8);
								dest2[2] = to!ubyte((src[2] * src[0] + dest2[2] * (255 - src[0]))>>8);
								dest2[3] = to!ubyte((src[3] * src[0] + dest2[3] * (255 - src[0]))>>8);
								*p = dest2;
							}*/
							ubyte[16] *p = cast(ubyte[16]*)(workpad + (offsetX + x)*4 + offsetY);
							ubyte[16] src;
							//uint[4] src;
							*cast(ubyte[4]*)(src.ptr) = *cast(ubyte[4]*)(palette.ptr + 4 * *(c+3));
							*cast(ubyte[4]*)(src.ptr + 4) = *cast(ubyte[4]*)(palette.ptr + 4 * *(c+2));
							*cast(ubyte[4]*)(src.ptr + 8) = *cast(ubyte[4]*)(palette.ptr + 4 * *(c+1));
							*cast(ubyte[4]*)(src.ptr + 12) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							ubyte[16] alpha = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];


							asm{
								//calculating alpha
								//pxor	XMM1, XMM1;
								movups	XMM0, alpha;
								
								movups	XMM1, XMM0;
								punpcklbw	XMM0, XMM2;
								punpckhbw	XMM1, XMM3;
								movaps	XMM6, alphaSSEConst256;
								movaps	XMM7, XMM6;
								movaps	XMM4, alphaSSEConst1;
								movaps	XMM5, XMM4;

								
								//punpcklbw	XMM1, XMM2;
								
								paddusw	XMM4, XMM1;	//1 + alpha01
								paddusw	XMM5, XMM0;
								psubusw	XMM6, XMM1;	//256 - alpha01
								psubusw	XMM7, XMM0;
								
								//moving the values to their destinations
								mov		EBX, p[EBP];
								movups	XMM0, src;	//src01
								movups	XMM1, XMM0; //src23
								punpcklbw	XMM0, XMM2;
								punpckhbw	XMM1, XMM3;
								pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
								pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
								movups	XMM0, [EBX];	//dest01
								movups	XMM1, XMM0;		//dest23
								punpcklbw	XMM0, XMM2;
								punpckhbw	XMM1, XMM3;
								pmullw	XMM6, XMM0;	//dest01 * (256 - alpha)
								pmullw	XMM7, XMM1; //dest23 * (256 - alpha)
								
								paddusw	XMM4, XMM6;	//(src01 * (1 + alpha01)) + (dest01 * (256 - alpha01))
								paddusw	XMM5, XMM7; //(src * (1 + alpha)) + (dest * (256 - alpha))
								psrlw	XMM4, 8;		//(src * (1 + alpha)) + (dest * (256 - alpha)) / 256
								psrlw	XMM5, 8;
								//moving the result to its place;
								//pxor	MM2, MM2;
								packuswb	XMM4, XMM5;
								
								movups	[EBX], XMM4;
								
								//emms;
							}
						}
						for(; x < sizeX - offsetXB ; x++){
							ushort* c = (p0 + (sizeX - x - 1) + offsetP);
							
							ubyte[4] *p = cast(ubyte[4]*)(workpad + (offsetX + x)*4 + offsetY);
							ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							ushort[4] alpha = [src[0],src[0],src[0],src[0]];
							asm{
								pxor	XMM3, XMM3;
								movq	XMM2, alpha;
								mov		EBX, p[EBP];
								movd	XMM0, [EBX];
								movd	XMM1, src;
								punpcklbw	XMM0, XMM3;//dest
								punpcklbw	XMM1, XMM3;//src
								//punpcklbw	XMM2, XMM3;//alpha
								movaps	XMM4, alphaSSEConst256;
								movaps	XMM5, alphaSSEConst1;
								
								paddusw XMM5, XMM2;//1+alpha
								psubusw	XMM4, XMM2;//256-alpha
								
								pmullw	XMM0, XMM4;//dest*(256-alpha)
								pmullw	XMM1, XMM5;//src*(1+alpha)
								paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
								psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
								//pxor	XMM7, XMM7;
								packuswb	XMM0, XMM3;
								
								movd	[EBX], XMM0;
								
								//pxor	XMM0, XMM0;
								//pxor	XMM1, XMM1;
								pxor	XMM2, XMM2;
							}
							
						}
					}
					else{ //for non flipped sprites
						void* pl = (workpad + (offsetX + x)*4 + offsetY);
						ushort* c = p0 + x + offsetP;
						for(; x < sizeX - offsetXB - 3 ; x+=4){
							//ushort* c = p0 + x + offsetP;
							ubyte[16] *p = cast(ubyte[16]*)pl;		//(workpad + (offsetX + x)*4 + offsetY);
							ubyte[16] src;
							*cast(ubyte[4]*)(src.ptr) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							c++;
							*cast(ubyte[4]*)(src.ptr + 4) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							c++;
							*cast(ubyte[4]*)(src.ptr + 8) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							c++;
							*cast(ubyte[4]*)(src.ptr + 12) = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							c++;
							ubyte[16] alpha = [src[12],src[12],src[12],src[12],src[8],src[8],src[8],src[8],src[4],src[4],src[4],src[4],src[0],src[0],src[0],src[0]];

							//uint[4] src;
							//uint[4] alpha;

							asm{
								//do a test if alpha-blending and/or blitter can avoided
								/*
								movups	XMM0, alpha;
								pxor 	XMM1, XMM1;
								pcmpeqq	XMM1, XMM0; //use packed testing of SSE to figure out if any operation can be skipped
								je 		endofalgorithm;
								movaps	XMM3, SSEUQWmaxvalue; //use further tests if blitter can be used
								pcmpeqq	XMM3, XMM0;
								pand	XMM3, XMM1;
								pcmpeqq XMM3, SSEUQWmaxvalue;
								jne		alphablend;

								//blitter routine
								mov		EBX, p[EBP];
								movups	XMM0, src;
								movups	XMM1, [EBX];
								pxor	XMM3, XMM3;
								pcmpeqq	XMM3, XMM0;
								pand	XMM1, XMM3;
								por		XMM1, XMM0;
								movups	[EBX], XMM1;
								jmp 	endofalgorithm;

							alphablend:*/
								//calculating alpha
								//pxor	XMM1, XMM1;
							
								movups	XMM0, alpha;
								movups	XMM1, XMM0;
								punpcklbw	XMM0, XMM2;
								punpckhbw	XMM1, XMM2;
								movaps	XMM6, alphaSSEConst256;
								movaps	XMM7, XMM6;
								movaps	XMM4, alphaSSEConst1;
								movaps	XMM5, XMM4;


								//punpcklbw	XMM1, XMM2;
								
								paddusw	XMM4, XMM0;	//1 + alpha01
								paddusw	XMM5, XMM1;
								psubusw	XMM6, XMM0;	//256 - alpha01
								psubusw	XMM7, XMM1;

								//moving the values to their destinations
								mov		EBX, p[EBP];
								movups	XMM0, src;	//src01
								movups	XMM1, XMM0; //src23
								punpcklbw	XMM0, XMM2;
								punpckhbw	XMM1, XMM2;
								pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
								pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
								movups	XMM0, [EBX];	//dest01
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
								
								movups	[EBX], XMM4;

							//endofalgorithm:

							}
							pl += 16;
							//c += 4;
							//*p = [res[0],res[2],res[4],res[6]];
							//ubyte[4] res = *p;
							//writeln(res);
							
							//}
						}
						for(; x < sizeX - offsetXB ; x++){
							//ushort* c = p0 + x + offsetP;
							
							ubyte[4] *p = cast(ubyte[4]*)pl;		//(workpad + (offsetX + x)*4 + offsetY);
							ubyte[4] src = *cast(ubyte[4]*)(palette.ptr + 4 * *c);
							ushort[4] alpha = [src[0],src[0],src[0],src[0]];
							asm{
								//pxor	XMM3, XMM3;
								movq	XMM2, alpha;
								mov		EBX, p[EBP];
								movd	XMM0, [EBX];
								movd	XMM1, src;
								punpcklbw	XMM0, XMM3;//dest
								punpcklbw	XMM1, XMM3;//src
								//punpcklbw	XMM2, XMM3;//alpha
								movaps	XMM4, alphaSSEConst256;
								movaps	XMM5, alphaSSEConst1;

								paddusw XMM5, XMM2;//1+alpha
								psubusw	XMM4, XMM2;//256-alpha

								pmullw	XMM0, XMM4;//dest*(256-alpha)
								pmullw	XMM1, XMM5;//src*(1+alpha)
								paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
								psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
								//pxor	XMM7, XMM7;
								packuswb	XMM0, XMM3;

								movd	[EBX], XMM0;

								//pxor	XMM0, XMM0;
								//pxor	XMM1, XMM1;
								pxor	XMM2, XMM2;
							}
							pl += 4;
							c++;
						}
					}
				}
			}
		}
	}
	
	/*public void updateRaster(Bitmap16Bit frameBuffer){
		//writeln(spriteSorter);
		foreach_reverse(int i ; spriteSorter){
			/*foreach(int i ; spriteSet.byKey){*/
			/*if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].right < sY + rasterY)) {
				//writeln(i);
				int offsetXA, offsetXB, offsetYA, offsetYB;
				//if(sX > coordinates[i].xa) {offsetXA = sX - coordinates[i].xa; }
				if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
				//if(sX + rasterX < coordinates[i].xb) {offsetXB = sX - coordinates[i].xb - rasterX; }
				if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
				for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){
					ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						for(int x ; x < chunk.length ; x++){
							if(coordinates[i].left - sX + x >= 0 && coordinates[i].left - sX + x < rasterX){
								if(chunk[chunk.length-x-1] != transparencyIndex) frameBuffer.writePixel(coordinates[i].left - sX + x, coordinates[i].top - sY + y, chunk[chunk.length-x-1]);
							}
						}
					}
					else{
						for(int x ; x < chunk.length ; x++){
							if(coordinates[i].left - sX + x >= 0 && coordinates[i].left - sX + x < rasterX){
								if(chunk[x] != transparencyIndex) frameBuffer.writePixel(coordinates[i].left - sX + x, coordinates[i].top - sY + y, chunk[x]);
							}
						}
					}
				}
			}
		}
	}*/
	
	
}

public class SpriteLayer32Bit : Layer, ISpriteCollision, ISpriteLayer32Bit{
	private Bitmap32Bit[int] spriteSet;
	private Coordinate[int] coordinates;		//Use moveSprite() and relMoveSprite() instead to move sprites
	private FlipRegister[int] flipRegisters;
	private int[] spriteSorter;
	public SpriteMovementListener[int] collisionDetector;

	
	public this(){
		
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

	public void replaceSprite(Bitmap32Bit s, int n){}
	public void replaceSprite(Bitmap32Bit s, int n, int x, int y){}
	public void replaceSprite(Bitmap32Bit s, int n, Coordinate c){}
	
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
	
	public override void updateRaster(void* workpad, int pitch, ubyte[] palette, int[] threads){
		foreach_reverse(int i ; spriteSorter){
			
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				//writeln(i);
				int offsetXA, offsetXB, offsetYA, offsetYB, sizeX = coordinates[i].getXSize(), offsetX = coordinates[i].left - sX;
				if(sX > coordinates[i].left) {offsetXA = sX - coordinates[i].left; }
				if(sY > coordinates[i].top) {offsetYA = sY - coordinates[i].top; }
				if(sX + rasterX < coordinates[i].right) {offsetXB = coordinates[i].right - rasterX; }
				if(sY + rasterY < coordinates[i].bottom) {offsetYB = coordinates[i].bottom - rasterY; }
				ubyte* p0 = spriteSet[i].getPtr();
				//writeln(p0);
				for(int y = offsetYA ; y < coordinates[i].getYSize() - offsetYB ; y++){//for non flipped sprites
					//ushort[] chunk = (flipRegisters[i] == FlipRegister.Y || flipRegisters[i] == FlipRegister.XY) ? spriteSet[i].readRowReverse(y) : spriteSet[i].readRow(y);
					int offsetP = sizeX * y * 4, offsetY = (coordinates[i].top - sY + y)*pitch;
					int x = offsetXA;
					ubyte* c = p0 + x + offsetP;
					void* pl = (workpad + (offsetX + x * 4) + offsetY);
					for(; x < sizeX - offsetXB - 3 ; x+=4){
						//writeln(x);
						ubyte[16] *p = cast(ubyte[16]*)pl;
						ubyte[16] src = *cast(ubyte[16]*)c;
						//src = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];
						//ubyte[16] alpha = [src[12],src[12],src[12],src[12],src[8],src[8],src[8],src[8],src[4],src[4],src[4],src[4],src[0],src[0],src[0],src[0]];
						ubyte[16] alpha = [src[0],src[0],src[0],src[0],src[4],src[4],src[4],src[4],src[8],src[8],src[8],src[8],src[12],src[12],src[12],src[12]];
						//ubyte[16] alpha = [255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255];
						//uint[4] src;
						//uint[4] alpha;
						
						asm{
							//create the source
							
							//calculating alpha
							//pxor	XMM1, XMM1;
							movups	XMM0, alpha;	//a01
							movups	XMM1, XMM0;		//a23
							punpcklbw	XMM0, XMM2;
							punpckhbw	XMM1, XMM2;
							movaps	XMM6, alphaSSEConst256;
							movaps	XMM7, XMM6;
							movaps	XMM4, alphaSSEConst1;
							movaps	XMM5, XMM4;
							
							
							//punpcklbw	XMM1, XMM2;
							
							paddusw	XMM4, XMM0;	//1 + alpha01
							paddusw	XMM5, XMM1;
							psubusw	XMM6, XMM0;	//256 - alpha01
							psubusw	XMM7, XMM1;
							
							//moving the values to their destinations
							mov		EBX, p[EBP];
							movups	XMM0, src;	//src01
							movups	XMM1, XMM0; //src23
							punpcklbw	XMM0, XMM2;
							punpckhbw	XMM1, XMM2;
							pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
							pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
							movups	XMM0, [EBX];	//dest01
							movups	XMM1, XMM0;		//dest23
							punpcklbw	XMM0, XMM2;
							punpckhbw	XMM1, XMM3;
							pmullw	XMM6, XMM0;	//dest01 * (256 - alpha)
							pmullw	XMM7, XMM1; //dest23 * (256 - alpha)
							
							paddusw	XMM4, XMM6;	//(src01 * (1 + alpha01)) + (dest01 * (256 - alpha01))
							paddusw	XMM5, XMM7; //(src * (1 + alpha)) + (dest * (256 - alpha))
							psrlw	XMM4, 8;		//(src * (1 + alpha)) + (dest * (256 - alpha)) / 256
							psrlw	XMM5, 8;
							//moving the result to its place;
							//pxor	MM2, MM2;
							packuswb	XMM4, XMM5;
							
							movups	[EBX], XMM4;
							
							//emms;
						}
						//*p = [res[0],res[2],res[4],res[6]];
						//ubyte[4] res = *p;
						//writeln(res);
						pl += 16;
						c += 16;
						//}
					}
					for(; x < sizeX - offsetXB ; x++){
						//ubyte* c = p0 + x + offsetP;
						
						ubyte[4] *p = cast(ubyte[4]*)pl;  //(workpad + (offsetX + x)*4 + offsetY);
						ubyte[4] src = *cast(ubyte[4]*)c;   //(c);
						ushort[4] alpha = [src[0],src[0],src[0],src[0]];
						asm{
							//pxor	XMM3, XMM3;
							movq	XMM2, alpha;
							mov		EBX, p[EBP];
							movd	XMM0, [EBX];
							movd	XMM1, src;
							punpcklbw	XMM0, XMM3;//dest
							punpcklbw	XMM1, XMM3;//src
							
							movaps	XMM4, alphaSSEConst256;
							movaps	XMM5, alphaSSEConst1;
							
							paddusw XMM5, XMM2;//1+alpha
							psubusw	XMM4, XMM2;//256-alpha
							
							pmullw	XMM0, XMM4;//dest*(256-alpha)
							pmullw	XMM1, XMM5;//src*(1+alpha)
							paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
							psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
							packuswb	XMM0, XMM3;
							movd	[EBX], XMM0;
							pxor	XMM2, XMM2;
						}
						pl+=4;
						c+=4;
					}

				}
			}
		}
	}
}