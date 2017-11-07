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
import std.container.rbtree;
//import system.etc;
import PixelPerfectEngine.system.exc;
import std.algorithm;
import derelict.sdl2.sdl;
import core.stdc.stdlib;
//import std.range;


static immutable ushort[4] alphaMMXmul_const256 = [256,256,256,256];
static immutable ushort[4] alphaMMXmul_const1 = [1,1,1,1];
static immutable ushort[8] alphaSSEConst256 = [256,256,256,256,256,256,256,256];
static immutable ushort[8] alphaSSEConst1 = [1,1,1,1,1,1,1,1];
static immutable ubyte[16] alphaSSEMask = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0];
static immutable uint[4] SSEUQWmaxvalue = [0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF] ;

//static immutable uint[2] alphaMMXmul_0 = [1,1];

public enum FlipRegister : ubyte {
	NORM	=	0x00,
	X		=	0x01,
	Y		=	0x02,
	XY		=	0x03
}

/**
 * The basis of all layer classes, containing functions for rendering.
 */
abstract class Layer {
	protected void delegate(void* src, void* dest, int length) mainRenderingFunction;		///Used to get around some readability issues. (void* src, void* dest, int length)
	protected void delegate(ushort* src, Color* dest, Color* palette, int length) mainColorLookupFunction;
	protected void delegate(void* src, int length) mainHorizontalMirroringFunction;
	protected void delegate(ubyte* src, Color* dest, Color* palette, int length) main8BitColorLookupFunction;
	protected void delegate(ubyte* src, Color* dest, Color* palette, int length, int offset) main4BitColorLookupFunction;
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
				mainRenderingFunction = &alphaBlend;
				break;
			case LayerRenderingMode.BLITTER:
				mainRenderingFunction = &blitter;
				break;
			default:
				mainRenderingFunction = &copyRegion;
		}
		mainColorLookupFunction = &colorLookup;
		mainHorizontalMirroringFunction = &flipHorizontal;
		main8BitColorLookupFunction = &colorLookup8bit;
		main4BitColorLookupFunction = &colorLookup4bit;
	}
	///Absolute scrolling.
	@nogc public void scroll(int x, int y){
		sX=x;
		sY=y;
	}
	///Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
	@nogc public void relScroll(int x, int y){
		sX=sX+x;
		sY=sY+y;
	}
	///Getter for the X scroll position.
	@nogc public int getSX(){
		return sX;
	}
	///Getter for the Y scroll position.
	@nogc public int getSY(){
		return sY;
	}
	/// Override this to enable output to the raster
	public abstract void updateRaster(void* workpad, int pitch, Color* palette, int[] threads);
	///Converts 16 bit indexed bitmap data into 32 bit.
	@nogc protected void colorLookup(ushort* src, Color* dest, Color* palette, int length){
		for(int i; i < length; i++){
			*dest = palette[*(src++)];
			dest++;
		}
		//}
	}
	///Converts 8 bit indexed bitmap data into 32 bit.
	@nogc protected void colorLookup8bit(ubyte* src, Color* dest, Color* palette, int length){
		for(int i; i < length; i++){
			*dest = palette[*(src++)];
			dest++;
		}
	}
	///Converts 4 bit indexed bitmap data into 32 bit.
	@nogc protected void colorLookup4bit(ubyte* src, Color* dest, Color* palette, int length, int offset){
		offset &= 1;
		length += offset;
		for(int i = offset; i < length; i++){
			ubyte temp;
			if(i & 1)
				temp = (*src)>>4;
			else
				temp = (*src)&0x0F;
			*dest = palette[temp];
			dest++;
			src++;
		}
	}
	///Creates an alpha mask if the certain version of the algorithm needs it.
	@nogc protected void createAlphaMask(void* src, void* alpha, int length){
		version(X86){
			
			asm @nogc {
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
		}else{
			ubyte a;
			for(int i ; i < length ; i++){
				a = *cast(ubyte*)src;
				*cast(uint)alpha = a * 0x01010101;
				src += 4;
				alpha += 4;
			}
		}
	}
	///Standard algorithm for alpha-blending.
	@nogc protected void alphaBlend(void* src, void* dest, int length){
		version(X86){
			version(NO_SSE2){
				int target8 = length/8, target4 = length%2;
				asm @nogc {
					//setting up the pointer registers and the counter register
					//mov		EBX, alpha[EBP];
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target8;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					//create alpha mask on the fly
					movq	MM3, [ESI];
					movq	MM1, MM3;
					pand	MM1, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movq	MM0, MM1;
					pslld	MM0, 8;
					por		MM1, MM0;	//mask is ready for RA
					pslld	MM1, 8;
					por		MM0, MM1; //mask is ready for GRA
					pslld	MM0, 8;
					por		MM1, MM0; //mask is ready for BGRA/**/
					movq	MM0, MM1;

					punpcklbw	MM0, MM2;
					punpckhbw	MM1, MM2;
					movq	MM6, alphaSSEConst256;
					movq	MM7, MM6;
					movq	MM4, alphaSSEConst1;
					movq	MM5, MM4;
			
					paddusw	MM4, MM0;	//1 + alpha01
					paddusw	MM5, MM1; //1 + alpha23 
					psubusw	MM6, MM0;	//256 - alpha01
					psubusw	MM7, MM1; //256 - alpha23
				
					//moving the values to their destinations

					movq	MM0, MM3;	//src01
					movq	MM1, MM0; //src23
					punpcklbw	MM0, MM2;
					punpckhbw	MM1, MM2;
					pmullw	MM4, MM0;	//src01 * (1 + alpha01)
					pmullw	MM5, MM1;	//src23 * (1 + alpha23)
					movq	MM0, [EDI];	//dest01
					movq	MM1, MM0;		//dest23
					punpcklbw	MM0, MM2;
					punpckhbw	MM1, MM2;
					pmullw	MM6, MM0;	//dest01 * (256 - alpha)
					pmullw	MM7, MM1; //dest23 * (256 - alpha)
			
					paddusw	MM4, MM6;	//(src01 * (1 + alpha01)) + (dest01 * (256 - alpha01))
					paddusw	MM5, MM7; //(src * (1 + alpha)) + (dest * (256 - alpha))
					psrlw	MM4, 8;		//(src * (1 + alpha)) + (dest * (256 - alpha)) / 256
					psrlw	MM5, 8;
					//moving the result to its place;
					//pxor	MM2, MM2;
					packuswb	MM4, MM5;
			
					movq	[EDI], MM4;
					//add		EBX, 16;
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

					//movd	XMM6, [EBX];//alpha
				

					movd	MM0, [EDI];
					movd	MM1, [ESI];
					punpcklbw	MM0, MM2;//dest
					punpcklbw	MM1, MM2;//src
					movups	MM6, MM1;
					pand	MM6, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movups	MM7, MM6;
					pslld	MM6, 8;
					por		MM7, MM6;	//mask is ready for RA
					pslld	MM7, 8;
					por		MM6, MM7; //mask is ready for GRA
					pslld	MM6, 8;
					por		MM7, MM6; //mask is ready for BGRA/**/
					punpcklbw	MM7, MM2;

					movaps	MM4, alphaSSEConst256;
					movaps	MM5, alphaSSEConst1;
				
					paddusw MM5, MM7;//1+alpha
					psubusw	MM4, MM7;//256-alpha
				
					pmullw	MM0, MM4;//dest*(256-alpha)
					pmullw	MM1, MM5;//src*(1+alpha)
					paddusw	MM0, MM1;//(src*(1+alpha))+(dest*(256-alpha))
					psrlw	MM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
				
					packuswb	MM0, MM2;
				
					movd	[EDI], MM0;
				
					add		ESI, 4;
					add		EDI, 4;/**/
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;

				endofalgorithm:
					emms;
				}
			}else{
				int target16 = length/4, target4 = length%4;
				asm @nogc {
					//setting up the pointer registers and the counter register
					//mov		EBX, alpha[EBP];
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					//create alpha mask on the fly
					movups	XMM3, [ESI];
					movups	XMM1, XMM3;
					pand	XMM1, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movups	XMM0, XMM1;
					pslld	XMM0, 8;
					por		XMM1, XMM0;	//mask is ready for RA
					pslld	XMM1, 8;
					por		XMM0, XMM1; //mask is ready for GRA
					pslld	XMM0, 8;
					por		XMM1, XMM0; //mask is ready for BGRA/**/
					movups	XMM0, XMM1;

					punpcklbw	XMM0, XMM2;
					punpckhbw	XMM1, XMM2;
					movups	XMM6, alphaSSEConst256;
					movups	XMM7, XMM6;
					movups	XMM4, alphaSSEConst1;
					movups	XMM5, XMM4;
			
					paddusw	XMM4, XMM0;	//1 + alpha01
					paddusw	XMM5, XMM1; //1 + alpha23 
					psubusw	XMM6, XMM0;	//256 - alpha01
					psubusw	XMM7, XMM1; //256 - alpha23
				
					//moving the values to their destinations

					movups	XMM0, XMM3;	//src01
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
					//add		EBX, 16;
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

					//movd	XMM6, [EBX];//alpha
				

					movd	XMM0, [EDI];
					movd	XMM1, [ESI];
					punpcklbw	XMM0, XMM2;//dest
					punpcklbw	XMM1, XMM2;//src
					movups	XMM6, XMM1;
					pand	XMM6, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movups	XMM7, XMM6;
					pslld	XMM6, 8;
					por		XMM7, XMM6;	//mask is ready for RA
					pslld	XMM7, 8;
					por		XMM6, XMM7; //mask is ready for GRA
					pslld	XMM6, 8;
					por		XMM7, XMM6; //mask is ready for BGRA/**/
					punpcklbw	XMM7, XMM2;

					movaps	XMM4, alphaSSEConst256;
					movaps	XMM5, alphaSSEConst1;
				
					paddusw XMM5, XMM7;//1+alpha
					psubusw	XMM4, XMM7;//256-alpha
				
					pmullw	XMM0, XMM4;//dest*(256-alpha)
					pmullw	XMM1, XMM5;//src*(1+alpha)
					paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
					psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
				
					packuswb	XMM0, XMM2;
				
					movd	[EDI], XMM0;
				
					add		ESI, 4;
					add		EDI, 4;/**/
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;

				endofalgorithm:
					;
				}
			}
		}else version(X86_64){
			int target16 = length/4, target4 = length%4;
			asm @nogc {
				//setting up the pointer registers and the counter register
				//mov		EBX, alpha[EBP];
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RCX, target16;
				cmp		RCX, 0;
				jz		fourpixelblend; //skip 16 byte operations if not needed
				movups	XMM8, alphaSSEConst256;
				movups	XMM9, alphaSSEConst1;
				pand	XMM10, alphaSSEMask;
				//iteration cycle entry point
			sixteenpixelblend:
				//create alpha mask on the fly
				movups	XMM3, [RSI];
				movups	XMM1, XMM3;
				pand	XMM1, XMM10;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
				movups	XMM0, XMM1;
				pslld	XMM0, 8;
				por		XMM1, XMM0;	//mask is ready for RA
				pslld	XMM1, 8;
				por		XMM0, XMM1; //mask is ready for GRA
				pslld	XMM0, 8;
				por		XMM1, XMM0; //mask is ready for BGRA/**/
				movups	XMM0, XMM1;

				punpcklbw	XMM0, XMM2;
				punpckhbw	XMM1, XMM2;
				movups	XMM6, XMM8;
				movups	XMM7, XMM6;
				movups	XMM4, XMM9;
				movups	XMM5, XMM4;
			
				paddusw	XMM4, XMM0;	//1 + alpha01
				paddusw	XMM5, XMM1; //1 + alpha23 
				psubusw	XMM6, XMM0;	//256 - alpha01
				psubusw	XMM7, XMM1; //256 - alpha23
				
				//moving the values to their destinations

				movups	XMM0, XMM3;	//src01
				movups	XMM1, XMM0; //src23
				punpcklbw	XMM0, XMM2;
				punpckhbw	XMM1, XMM2;
				pmullw	XMM4, XMM0;	//src01 * (1 + alpha01)
				pmullw	XMM5, XMM1;	//src23 * (1 + alpha23)
				movups	XMM0, [RDI];	//dest01
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
			
				movups	[RDI], XMM4;
				//add		EBX, 16;
				add		RSI, 16;
				add		RDI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenpixelblend;

			fourpixelblend:

				mov		RCX, target4;
				cmp		RCX, 0;
				jz		endofalgorithm;

			fourpixelblendloop:

				//movd	XMM6, [EBX];//alpha
				

				movd	XMM0, [RDI];
				movd	XMM1, [RSI];
				punpcklbw	XMM0, XMM2;//dest
				punpcklbw	XMM1, XMM2;//src
				movups	XMM6, XMM1;
				pand	XMM6, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
				movups	XMM7, XMM6;
				pslld	XMM6, 8;
				por		XMM7, XMM6;	//mask is ready for RA
				pslld	XMM7, 8;
				por		XMM6, XMM7; //mask is ready for GRA
				pslld	XMM6, 8;
				por		XMM7, XMM6; //mask is ready for BGRA/**/
				punpcklbw	XMM7, XMM2;

				movaps	XMM4, alphaSSEConst256;
				movaps	XMM5, alphaSSEConst1;
				
				paddusw XMM5, XMM7;//1+alpha
				psubusw	XMM4, XMM7;//256-alpha
				
				pmullw	XMM0, XMM4;//dest*(256-alpha)
				pmullw	XMM1, XMM5;//src*(1+alpha)
				paddusw	XMM0, XMM1;//(src*(1+alpha))+(dest*(256-alpha))
				psrlw	XMM0, 8;//(src*(1+alpha))+(dest*(256-alpha))/256
				
				packuswb	XMM0, XMM2;
				
				movd	[RDI], XMM0;
				
				add		RSI, 4;
				add		RDI, 4;/**/
				dec		RCX;
				cmp		RCX, 0;
				jnz		fourpixelblendloop;

			endofalgorithm:
				;
			}
		}else{
			for(int i ; i < length ; i++){
				ubyte[4] srcP = *cast(ubyte[4]*)src;
				switch(srcP[0]){
					case 0: 
						break;
					case 255: 
						*cast(ubyte[4]*)dest = srcP;
						break;
					default:
						ubyte[4] destP = *cast(ubyte[4]*)dest;
						destP[1] = to!ubyte((srcP[1] * (1 + srcP[0]) + destP[1] * (256 - srcP[0]) / 256));
						destP[1] = to!ubyte((srcP[2] * (1 + srcP[0]) + destP[2] * (256 - srcP[0]) / 256));
						destP[1] = to!ubyte((srcP[3] * (1 + srcP[0]) + destP[3] * (256 - srcP[0]) / 256));
						*cast(ubyte[4]*)dest = destP;
						break;
				}
				src += 4;
				dest += 4;
			}
		}
	}
	///Standard algorithm for blitter.
	@nogc protected void blitter(void* src, void* dest, int length){
		version(X86){
			version(NO_SSE2){
				int target8 = length/2, target4 = length%2;
				asm @nogc {
					//setting up the pointer registers and the counter register
					//mov		EBX, alpha[EBP];
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target8;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					//create alpha mask on the fly
					movq	MM0, [ESI];
					movq	MM2, MM0;
					pand	MM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movq	MM1, MM2;
					pslld	MM1, 8;
					por		MM2, MM1;	//mask is ready for RA
					pslld	MM2, 8;
					por		MM1, MM2; //mask is ready for GRA
					pslld	MM1, 8;
					por		MM2, MM1; //mask is ready for BGRA/**/
					//movups	XMM2, XMM1;
					movq	MM1, [EDI];	//dest01
					pcmpeqd	MM2, MM3;
					pand	MM1, MM2;
					por		MM1, MM0;
					movq	[EDI], MM1;
				
					//add		EBX, 16;
					add		ESI, 8;
					add		EDI, 8;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;

				fourpixelblend:

					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;

				fourpixelblendloop:

					movd	MM0, [ESI];
					movq	MM2, MM0;
					pand	MM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movq	MM1, MM2;
					pslld	MM1, 8;
					por		MM2, MM1;	//mask is ready for RA
					pslld	MM2, 8;
					por		MM1, MM2; //mask is ready for GRA
					pslld	MM1, 8;
					por		MM2, MM1; //mask is ready for BGRA/**/
					//movups	XMM2, XMM1;
					movd	MM1, [EDI];	//dest01
					pcmpeqd	MM2, MM3;
					pand	MM1, MM2;
					por		MM1, MM0;
					movd	[EDI], MM1;
				
					add		ESI, 4;
					add		EDI, 4;/**/
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;

				endofalgorithm:
					emms;
				}
			}else{
				int target16 = length/4, target4 = length%4;
				asm @nogc {
					//setting up the pointer registers and the counter register
					//mov		EBX, alpha[EBP];
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					//create alpha mask on the fly
					movups	XMM0, [ESI];
					movups	XMM2, XMM0;
					pand	XMM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movups	XMM1, XMM2;
					pslld	XMM1, 8;
					por		XMM2, XMM1;	//mask is ready for RA
					pslld	XMM2, 8;
					por		XMM1, XMM2; //mask is ready for GRA
					pslld	XMM1, 8;
					por		XMM2, XMM1; //mask is ready for BGRA/**/
					//movups	XMM2, XMM1;
					movups	XMM1, [EDI];	//dest01
					pcmpeqd	XMM2, XMM3;
					pand	XMM1, XMM2;
					por		XMM1, XMM0;
					movups	[EDI], XMM1;
				
					//add		EBX, 16;
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
					movups	XMM2, XMM0;
					pand	XMM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
					movups	XMM1, XMM2;
					pslld	XMM1, 8;
					por		XMM2, XMM1;	//mask is ready for RA
					pslld	XMM2, 8;
					por		XMM1, XMM2; //mask is ready for GRA
					pslld	XMM1, 8;
					por		XMM2, XMM1; //mask is ready for BGRA/**/
					//movups	XMM2, XMM1;
					movd	XMM1, [EDI];	//dest01
					pcmpeqd	XMM2, XMM3;
					pand	XMM1, XMM2;
					por		XMM1, XMM0;
					movd	[EDI], XMM1;
				
					add		ESI, 4;
					add		EDI, 4;/**/
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;

				endofalgorithm:
					;
				}
			}
			
		}else version(X86_64){
			int target16 = length/4, target4 = length%4;
			asm @nogc {
				//setting up the pointer registers and the counter register
				//mov		EBX, alpha[EBP];
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RCX, target16;
				cmp		RCX, 0;
				jz		fourpixelblend; //skip 16 byte operations if not needed
				//iteration cycle entry point
			sixteenpixelblend:
				//create alpha mask on the fly
				movups	XMM0, [RSI];
				movups	XMM2, XMM0;
				pand	XMM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
				movups	XMM1, XMM2;
				pslld	XMM1, 8;
				por		XMM2, XMM1;	//mask is ready for RA
				pslld	XMM2, 8;
				por		XMM1, XMM2; //mask is ready for GRA
				pslld	XMM1, 8;
				por		XMM2, XMM1; //mask is ready for BGRA/**/
				//movups	XMM2, XMM1;
				movups	XMM1, [RDI];	//dest01
				pcmpeqd	XMM2, XMM3;
				pand	XMM1, XMM2;
				por		XMM1, XMM0;
				movups	[RDI], XMM1;
				
				//add		EBX, 16;
				add		RSI, 16;
				add		RDI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenpixelblend;

			fourpixelblend:

				mov		RCX, target4;
				cmp		RCX, 0;
				jz		endofalgorithm;

			fourpixelblendloop:

				movd	XMM0, [RSI];
				movups	XMM2, XMM0;
				pand	XMM2, alphaSSEMask;	//pixel & 0x000000FF,0x000000FF,0x000000FF,0x000000FF
				movups	XMM1, XMM2;
				pslld	XMM1, 8;
				por		XMM2, XMM1;	//mask is ready for RA
				pslld	XMM2, 8;
				por		XMM1, XMM2; //mask is ready for GRA
				pslld	XMM1, 8;
				por		XMM2, XMM1; //mask is ready for BGRA/**/
				//movups	XMM2, XMM1;
				movd	XMM1, [RDI];	//dest01
				pcmpeqd	XMM2, XMM3;
				pand	XMM1, XMM2;
				por		XMM1, XMM0;
				movd	[RDI], XMM1;
				
				add		RSI, 4;
				add		RDI, 4;/**/
				dec		RCX;
				cmp		RCX, 0;
				jnz		fourpixelblendloop;

			endofalgorithm:
				;
			}
		}else{
			for(int i ; i < length ; i++){
				ubyte[4] srcP = *cast(ubyte[4]*)src;
				if(srcP[0]){			//This is not a true blitter algorithm, however mask creation would have taken more CPU time. Inteded as a placeholder, so the engine is usable on non-x86 systems and processors lacking any vector instructions.
					*cast(ubyte[4]*)dest = srcP;
				}
				src += 4;
				dest += 4;
			}
		}
	}
	///Standard algorithm for region copying.
	@nogc protected void copyRegion(void* src, void* dest, int length){
		version(X86){
			version(NO_SSE2){
				int target8 = length/4, target4 = length%4;
				asm @nogc {
					//setting up the pointer registers and the counter register
					//mov		EBX, alpha[EBP];
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target8;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					movq	MM0, [ESI];	
					movq	[EDI], MM0;
					add		ESI, 8;
					add		EDI, 8;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;
			
				fourpixelblend:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourpixelblendloop:

					movd	MM0, [ESI];
					movd	[EDI], MM0;
					add		ESI, 4;
					add		EDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;
			
				endofalgorithm:
					emms;
				}
			}else{
				int target16 = length/4, target4 = length%4;
				asm @nogc {
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
		}else version(X86_64){
			int target16 = length/4, target4 = length%4;
			asm @nogc {
				//setting up the pointer registers and the counter register
				//mov		EBX, alpha[EBP];
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RCX, target16;
				cmp		RCX, 0;
				jz		fourpixelblend; //skip 16 byte operations if not needed
				//iteration cycle entry point
			sixteenpixelblend:
				movups	XMM0, [RSI];	
				movups	[RDI], XMM0;
				add		RSI, 16;
				add		RDI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenpixelblend;
			
			fourpixelblend:
			
				mov		RCX, target4;
				cmp		RCX, 0;
				jz		endofalgorithm;
			
			fourpixelblendloop:

				movd	XMM0, [RSI];
				movd	[RDI], XMM0;
				add		RSI, 4;
				add		RDI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		fourpixelblendloop;
			
			endofalgorithm:
				;
			}
		}else{
			for(int i ; i < length ; i++){
				*cast(ubyte[4]*)dest = *cast(ubyte[4]*)src;
				
				src += 4;
				dest += 4;
			}
		}
	}
	///Does XOR blitter with the given single colorvector (format: ARGB)
	@nogc protected void xorBlitter(void* dest, Color vector, int length){
		version(X86){
			version(NO_SSE2){
				uint[2] vector0 = [vector.raw, vector.raw];
				int target8 = length/2, target4 = length%2;
				asm @nogc {
					mov		EDI, dest[EBP];
					movq	MM1, vector0;
					mov		ECX, target8;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					movq	MM0, [EDI];
					pxor	MM0, MM1;	
					movq	[EDI], MM0;
					add		EDI, 8;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;
			
				fourpixelblend:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourpixelblendloop:

					movd	MM0, [EDI];
					pxor	MM0, MM1;	
					movd	[EDI], MM0;
					add		EDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;
				
				endofalgorithm:
					emms;
				}
			}else{
				uint[4] vector0 = [vector.raw, vector.raw, vector.raw, vector.raw];
				int target16 = length/4, target4 = length%4;
				asm @nogc {
					mov		EDI, dest[EBP];
					movups	XMM1, vector0;
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					movups	XMM0, [EDI];
					pxor	XMM0, XMM1;	
					movups	[EDI], XMM0;
					add		EDI, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;
			
				fourpixelblend:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourpixelblendloop:

					movd	XMM0, [EDI];
					pxor	XMM0, XMM1;	
					movd	[EDI], XMM0;
					add		EDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;
				
				endofalgorithm:
					;
				}
			}
		}else version(X86_64){
			uint[4] vector0 = [vector.raw, vector.raw, vector.raw, vector.raw];
			int target16 = length/4, target4 = length%4;
			asm @nogc {
				mov		RDI, dest[RBP];
				movups	XMM1, vector0;
				mov		RCX, target16;
				cmp		RCX, 0;
				jz		fourpixelblend; //skip 16 byte operations if not needed
				//iteration cycle entry point
			sixteenpixelblend:
				movups	XMM0, [RDI];
				pxor	XMM0, XMM1;	
				movups	[RDI], XMM0;
				add		RDI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenpixelblend;
			
			fourpixelblend:
			
				mov		RCX, target4;
				cmp		RCX, 0;
				jz		endofalgorithm;
			
			fourpixelblendloop:

				movd	XMM0, [RDI];
				pxor	XMM0, XMM1;	
				movd	[RDI], XMM0;
				add		RDI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		fourpixelblendloop;
			
			endofalgorithm:
				;
			}
		}else{
			for(int i ; i < length ; i++){
				*cast(uint*)dest ^= src.raw;
			}
		}
	}
	/**
	 *
	 */
	@nogc protected void xorBlitter(void* src, void* dest, int length){
		version(X86){
			version(NO_SSE2){
				//uint[2] vector0 = [vector.raw, vector.raw];
				int target8 = length/2, target4 = length%2;
				asm @nogc {
					mov		EDI, dest[EBP];
					mov		ESI, src[EBP];
					//movq	MM1, vector0;
					mov		ECX, target8;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					movq	MM0, [EDI];
					movq	MM1, [ESI];
					pxor	MM0, MM1;	
					movq	[EDI], MM0;
					add		EDI, 8;
					add		ESI, 8;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;
			
				fourpixelblend:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourpixelblendloop:

					movd	MM0, [EDI];
					movd	MM1, [ESI];
					pxor	MM0, MM1;	
					movd	[EDI], MM0;
					
				endofalgorithm:
					emms;
				}
			}else{
				
				int target16 = length/4, target4 = length%4;
				asm @nogc {
					mov		EDI, dest[EBP];
					mov		EDI, src[EBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourpixelblend; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenpixelblend:
					movups	XMM0, [EDI];
					movups	XMM1, [ESI];
					pxor	XMM0, XMM1;	
					movups	[EDI], XMM0;
					add		EDI, 16;
					add		ESI, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenpixelblend;
			
				fourpixelblend:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourpixelblendloop:

					movd	XMM0, [EDI];
					movd	XMM1, [ESI];
					pxor	XMM0, XMM1;	
					movd	[EDI], XMM0;
					add		EDI, 4;
					add		ESI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourpixelblendloop;
				
				endofalgorithm:
					;
				}
			}
		}else version(X86_64){
			
			int target16 = length/4, target4 = length%4;
			asm @nogc {
				mov		RDI, dest[RBP];
				mov		RSI, dest[RBP];
				mov		RCX, target16;
				cmp		RCX, 0;
				jz		fourpixelblend; //skip 16 byte operations if not needed
				//iteration cycle entry point
			sixteenpixelblend:
				movups	XMM0, [RDI];
				movups	XMM1, [RDI];
				pxor	XMM0, XMM1;	
				movups	[RDI], XMM0;
				add		RDI, 16;
				add		RSI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenpixelblend;
			
			fourpixelblend:
			
				mov		RCX, target4;
				cmp		RCX, 0;
				jz		endofalgorithm;
			
			fourpixelblendloop:

				movd	XMM0, [RDI];
				movd	XMM1, [RSI];
				pxor	XMM0, XMM1;	
				movd	[RDI], XMM0;
				add		RDI, 4;
				add		RSI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		fourpixelblendloop;
			
			endofalgorithm:
				;
			}
		}else{
			for(int i ; i < length ; i++){
				*cast(uint*)dest ^= *cast(uint*)src;
			}
		}
	}
	///Standard algorithm for horizontal mirroring
	@nogc protected void flipHorizontal(void* src, int length){
		version(NO_SSE2){
			int c = length / 2, dest = length * 4;
			asm @nogc{
				mov		ESI, src[EBP];
				mov		EDI, ESI;
				add		EDI, dest;
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
			void* dest = src + length * 4;
			asm @nogc{
				mov		ESI, src[EBP];
				//mov		EDI, ESI;
				mov		EDI, dest;
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
			asm @nogc{
				mov		RSI, src[RBP];
				mov		RDI, RSI;
				add		RDI, dest;
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
			Color keeper;
			void* dest = src + (Color.sizeof * length);
			for(int i ; i < length ; i++){
				keeper = *cast(Color*)src;
				*cast(Color*)src = *cast(Color*)dest;
				*cast(Color*)dest = keeper;
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

/*public interface ITileLayer8Bit : ITileLayer{
	public void addTile(Bitmap8Bit t, wchar id);
	public Bitmap8Bit getTile(wchar id);
}

public interface ITileLayer16Bit : ITileLayer{
	public void addTile(Bitmap16Bit t, wchar id);
	public Bitmap16Bit getTile(wchar id);
}

public interface ITileLayer32Bit : ITileLayer{
	public void addTile(Bitmap32Bit t, wchar id);
	public Bitmap32Bit getTile(wchar id);
}*/
/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Can use any kind of bitmaps thanks to code restructuring.
 */
public class TileLayer : Layer, ITileLayer{
	private int tileX, tileY, mX, mY;
	private int totalX, totalY;
	private wchar[] mapping;
	private BitmapAttrib[] tileAttributes;
	Color[][8] src;
	private ABitmap[wchar] tileSet;
	private bool wrapMode; 
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
	/// Wrapmode: if enabled, the layer will be turned into an "infinite" mode.
	public void setWrapMode(bool w){
		wrapMode = w;
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
		if(wrapMode){
			x %= mX;
			y %= mY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return 0xFFFF;
		return mapping[x + y*mX];
	}
	///Returns the tile's attribute at the given pixel
	@nogc public BitmapAttrib tileAttributeByPixel(int x, int y){
		x /= tileX;
		y /= tileY;
		if(wrapMode){
			x %= mX;
			y %= mY;
		}
		if(x >= mX || y >= mY || x < 0 || y < 0) return BitmapAttrib(false,false);
		return tileAttributes[x + y*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, Color* palette, int[] threads){
		//Color* src;
		//src = cast(Color*)alloca(tileX * 4);
		//int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
		//src.length = tileX * 4;
		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		
		int y = sY < 0 && !wrapMode ? sY * -1 : 0;
		int sY0 = cast(int)(cast(uint)(sY) & 0b0111_1111_1111_1111_1111_1111_1111_1111);
		//int sX0 = cast(int)(cast(uint)(sX) & 0b0111_1111_1111_1111_1111_1111_1111_1111);
		int offsetP = y*pitch;	// The offset of the line that is being written
		int offsetY = sY0 % tileY;		//Scroll offset upwards
		int offsetY0 = (sY + rasterY) % tileY;
		int offsetXA = sX%tileX;	// tile offset of the first column
		//for( ; y < rasterY ; y+=tileY){
		while(y < rasterY){
			//int offsetY = tileX * ((y + sY)%tileY);		
			int offsetYA = !y ? offsetY : 0;	//top offset for first tile, 0 otherwise
			int offsetYB = y + tileY > rasterY ? offsetY0 : tileY;	//bottom offset of last tile, equals tileY otherwise
			int x = sX < 0 && !wrapMode ? sX * -1 : 0;
			int targetX = totalX - sX > rasterX && !wrapMode ? rasterX : rasterX - (totalX - sX);
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
					tileYOffset *= tileAttrib.vertMirror ? -1 : 1;
					int pitchOffset = pitch * threads.length;
					/+switch(ab.classinfo){
						case typeid(Bitmap4Bit):+/
					if(ab.classinfo == typeid(Bitmap4Bit)){
						//tileYOffset >>=1;
						foreach(int threadOffset; threads.parallel){
							void* p1 = p0;
							Bitmap4Bit bmp = cast(Bitmap4Bit)(ab);
							ubyte* c = bmp.getPtr();
							c += tileAttrib.vertMirror ? (tileY - offsetYA - 1 + threadOffset) * tileX : (offsetYA + threadOffset) * tileX;
							for(int y0 = offsetYA + threadOffset ; y0 < offsetYB ; y0+=threads.length){
								main4BitColorLookupFunction(c, src[threadOffset].ptr, ab.getPalettePtr, tileX, 0);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									mainHorizontalMirroringFunction(src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(src[threadOffset].ptr + xp, p1, tileXtarget);
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
								main8BitColorLookupFunction(c, src[threadOffset].ptr, ab.getPalettePtr, tileX);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									mainHorizontalMirroringFunction(src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(src[threadOffset].ptr + xp, p1, tileXtarget);
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
								mainColorLookupFunction(c, src[threadOffset].ptr, palette, tileX);
								if(tileAttrib.horizMirror){//Horizontal mirroring
									mainHorizontalMirroringFunction(src[threadOffset].ptr, tileX);
								}
								mainRenderingFunction(src[threadOffset].ptr + xp, p1, tileXtarget);
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
									copyRegion(c, src[threadOffset].ptr, tileX);
									mainHorizontalMirroringFunction(src[threadOffset].ptr, tileX);
									mainRenderingFunction(src[threadOffset].ptr + xp, p1, tileXtarget);
								}else{
									mainRenderingFunction(c + xp, p1, tileXtarget);
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
							main4BitColorLookupFunction(p1, src[threadOffset], ab.getPalettePtr(), length, offsetXA);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								mainHorizontalMirroringFunction(src[threadOffset], length);
							}
							mainRenderingFunction(src[threadOffset], dest, length);
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
							main8BitColorLookupFunction(p1, src[threadOffset], ab.getPalettePtr(), length);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								mainHorizontalMirroringFunction(src[threadOffset], length);
							}
							mainRenderingFunction(src[threadOffset], dest, length);
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
							mainColorLookupFunction(p1, src[threadOffset], palette, length);
							if(spriteAttributes[i].horizMirror){//Flips lines if needed
								mainHorizontalMirroringFunction(src[threadOffset], length);
							}
							mainRenderingFunction(src[threadOffset], dest, length);
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
								copyRegion(p1, src[threadOffset], length);
								mainHorizontalMirroringFunction(src[threadOffset], length);
								mainRenderingFunction(src[threadOffset], dest, length);
							}else{
								mainRenderingFunction(p1, dest, length);
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
		foreach(int i; commandListPriorities){
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
		}
	}
	
}