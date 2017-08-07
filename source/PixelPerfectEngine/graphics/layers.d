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
	protected void delegate(void* src, void* dest, void* alpha, int length) mainRenderingFunction;		///Used to get around some readability issues. (void* src, void* dest, void* alpha, int length)
	protected void delegate(ushort* src, void* dest, ubyte* palette, int length) mainColorLookupFunction;
	protected void delegate(void* src, int length) mainHorizontalMirroringFunction;
	protected void delegate(ubyte* src, void* dest, ubyte* palette, int length) main8BitColorLookupFunction;
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
	public abstract void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads);
	///Converts 16 bit indexed bitmap data into 32 bit.
	@nogc protected void colorLookup(ushort* src, void* dest, ubyte* palette, int length){
		version(X86){
			asm @nogc {
				//setting up the pointer registers and the counter registers
				mov		ESI, src[EBP];
				mov		EDI, dest[EBP];
				mov		EBX, palette[EBP];
				mov		ECX, length;
				//iteration cycle entry point
			clut:
				xor		EAX, EAX;
				mov		AX, [ESI];
				mov		EDX, 4;
				mul		AX, DX;
				add		EAX, EBX;
				movd	XMM0, [EAX];
				movd	[EDI], XMM0;
				add		ESI, 2;
				add		EDI, 4;
				dec		ECX;
				cmp		ECX, 0;
				jnz		clut;
			}
		}else version(X86_64){
			asm @nogc {
				//setting up the pointer registers and the counter registers
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RBX, palette[RBP];
				mov		RCX, length;
				//iteration cycle entry point
			clut:
				mov		AX, [RSI];
				mov		EDX, 4;
				mul		AX, DX;
				add		RAX, RBX;
				movd	XMM0, [RAX];
				movd	[RDI], XMM0;
				add		RSI, 2;
				add		RDI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		clut;
			}
		}else{
			for(int i; i < length; i++){
				*cast(ubyte[4]*)dest = *cast(ubyte[4]*)(palette + 4 * *(src+i));
				dest += 4;
			}
		}
	}
	///Converts 8 bit indexed bitmap data into 32 bit.
	@nogc protected void colorLookup8bit(ubyte* src, void* dest, ubyte* palette, int length){
		version(X86){
			asm @nogc {
				//setting up the pointer registers and the counter registers
				mov		ESI, src[EBP];
				mov		EDI, dest[EBP];
				mov		EBX, palette[EBP];
				mov		ECX, length;
				//iteration cycle entry point
			clut:
				xor		EAX, EAX;
				mov		AL, [ESI];
				mov		EDX, 4;
				mul		AX, DX;
				add		EAX, EBX;
				movd	XMM0, [EAX];
				movd	[EDI], XMM0;
				inc		ESI;
				add		EDI, 4;
				dec		ECX;
				cmp		ECX, 0;
				jnz		clut;
			}
		}else version(X86_64){
			asm @nogc {
				//setting up the pointer registers and the counter registers
				mov		RSI, src[RBP];
				mov		RDI, dest[RBP];
				mov		RBX, palette[RBP];
				mov		RCX, length;
				//iteration cycle entry point
			clut:
				mov		AL, [RSI];
				mov		EDX, 4;
				mul		AX, DX;
				add		RAX, RBX;
				movd	XMM0, [RAX];
				movd	[RDI], XMM0;
				inc		RSI;
				add		RDI, 4;
				dec		RCX;
				cmp		RCX, 0;
				jnz		clut;
			}
		}else{
			for(int i; i < length; i++){
				*cast(ubyte[4]*)dest = *cast(ubyte[4]*)(palette + 4 * *(src+i));
				dest += 4;
			}
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
		}
		else{
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
	@nogc protected void alphaBlend(void* src, void* dest, void* alpha, int length){
		
		//if(target4) writeln(length);
		version(X86){
			//createAlphaMask(src, alpha, length);
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
				punpcklbw	XMM6, XMM2;

				movaps	XMM4, alphaSSEConst256;
				movaps	XMM5, alphaSSEConst1;
				
				paddusw XMM5, XMM6;//1+alpha
				psubusw	XMM4, XMM6;//256-alpha
				
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
				punpcklbw	XMM6, XMM2;

				movaps	XMM4, alphaSSEConst256;
				movaps	XMM5, alphaSSEConst1;
				
				paddusw XMM5, XMM6;//1+alpha
				psubusw	XMM4, XMM6;//256-alpha
				
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
	@nogc protected void blitter(void* src, void* dest, void* alpha, int length){
		version(X86){
			//createAlphaMask(src, alpha, length);
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
	///Standard algorithm for region copying. Alpha is placeholder for delegate usage.
	@nogc protected void copyRegion(void* src, void* dest, void* alpha, int length){
		version(X86){
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
	@nogc protected void xorBlitter(void* dest, ubyte[4] vector, int length){
		version(X86){
			ubyte[16] vector0 = [vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3]];
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
		}else version(X86_64){
			ubyte[16] vector0 = [vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3],vector[0],vector[1],vector[2],vector[3]];
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
			void* src = cast(void*)vector.ptr;
			for(int i ; i < length ; i++){
				*cast(uint*)dest ^= *cast(uint*) src;
			}
		}
	}
	///Standard algorithm for horizontal mirroring
	@nogc protected void flipHorizontal(void* src, int length){
		version(X86){
			int c = length / 2, dest = length * 4;
			asm @nogc{
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
			void* dest = src + (4 * length);
			for(int i ; i < length / 2 ; i++){
				*cast(ubyte[4]*)dest = *cast(ubyte[4]*)src;
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
	public void loadMapping(int x, int y, wchar[] map);
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
}

public interface ITileLayer8Bit : ITileLayer{
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
}
/**
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Uses 16 bit bitmaps.
 */
public class TileLayer : Layer, ITileLayer16Bit{
	private int tileX, tileY, mX, mY;
	private int totalX, totalY;
	private wchar[] mapping;
	
	private Bitmap16Bit[wchar] tileSet;
	private bool wrapMode; 
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
	}
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
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, wchar w){
		mapping[x+(mX*y)]=w;
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, wchar[] map){
		mX=x;
		mY=y;
		mapping = map;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(Bitmap16Bit t, wchar id){
		if(t.getX()==tileX && t.getY()==tileY){
			tileSet[id]=t;
		}
		else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		tileSet.remove(id);
	}
	///Returns which tile is at the given pixel
	@nogc public wchar tileByPixel(int x, int y){
		if(x/tileX + (y/tileY)*mX < 0 || x/tileX + (y/tileY)*mX >= mapping.length) return 0xFFFF;
		return mapping[x/tileX + (y/tileY)*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		ubyte[] src, alpha;
		//int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
		src.length = tileX * 4;
		alpha.length = tileX * 4;
		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		
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
					mainColorLookupFunction(c, src.ptr, palette, tileXtarget);
					//createAlphaMask(src.ptr, alpha.ptr, tileXtarget);
					mainRenderingFunction(src.ptr, p0, alpha.ptr, tileXtarget);
					p0 += (tileX - xp) * 4;
					x+=tileX - xp;
				}else{
					x+=tileX;
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
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Uses 32 bit bitmaps.
 */
public class TileLayer32Bit : Layer, ITileLayer32Bit{
	private int tileX, tileY, mX, mY;
	private int totalX, totalY;
	private wchar[] mapping;
	
	private Bitmap32Bit[wchar] tileSet;
	private bool wrapMode; 
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
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
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, wchar[] map){
		mX=x;
		mY=y;
		mapping = map;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(Bitmap32Bit t, wchar id){
		if(t.getX()==tileX && t.getY()==tileY){
			tileSet[id]=t;
		}
		else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		tileSet.remove(id);
	}
	///Returns which tile is at the given pixel
	public wchar tileByPixel(int x, int y){
		if(x/tileX + (y/tileY)*mX < 0 || x/tileX + (y/tileY)*mX >= mapping.length) return 0xFFFF;
		return mapping[x/tileX + (y/tileY)*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		//ubyte[] src, alpha;
		//int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
		//src.length = tileX * 4;
		//alpha.length = tileX * 4;
		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		
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
					ubyte *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
					c += offsetY;
					c += xp * 4;
					//mainColorLookupFunction(c, src.ptr, palette, tileXtarget);
					//createAlphaMask(src.ptr, alpha.ptr, tileXtarget);
					mainRenderingFunction(c, p0, null, tileXtarget);
					p0 += (tileX - xp) * 4;
					x+=tileX - xp;
				}else{
					x+=tileX;
				}


			}
					
		}
				
		
	}
	
	public BLInfo getLayerInfo(){
		return BLInfo(tileX,tileY,mX,mY);
	}
	public Bitmap32Bit getTile(wchar id){
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
 * General purpose TileLayer with palette support, mainly for backgrounds.
 * Use multiple of this class for paralax scrolling.
 * Uses 8 bit bitmaps.
 */
public class TileLayer8Bit : Layer, ITileLayer8Bit{
	private int tileX, tileY, mX, mY;
	private int totalX, totalY;
	private wchar[] mapping;
	
	private Bitmap8Bit[wchar] tileSet;
	private bool wrapMode; 
	///Constructor. tX , tY : Set the size of the tiles on the layer.
	this(int tX, int tY, LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		tileX=tX;
		tileY=tY;
		setRenderingMode(renderMode);
	}
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
	///Writes to the map. x , y : Position. w : ID of the tile.
	@nogc public void writeMapping(int x, int y, wchar w){
		mapping[x+(mX*y)]=w;
	}
	///Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
	///x*y=map.length
	public void loadMapping(int x, int y, wchar[] map){
		mX=x;
		mY=y;
		mapping = map;
		totalX=mX*tileX;
		totalY=mY*tileY;
	}
	///Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
	public void addTile(Bitmap8Bit t, wchar id){
		if(t.getX()==tileX && t.getY()==tileY){
			tileSet[id]=t;
		}
		else{
			throw new TileFormatException("Incorrect tile size!", __FILE__, __LINE__, null);
		}
	}
	///Removes the tile with the ID from the set.
	public void removeTile(wchar id){
		tileSet.remove(id);
	}
	///Returns which tile is at the given pixel
	@nogc public wchar tileByPixel(int x, int y){
		if(x/tileX + (y/tileY)*mX < 0 || x/tileX + (y/tileY)*mX >= mapping.length) return 0xFFFF;
		return mapping[x/tileX + (y/tileY)*mX];
	}
	
	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		ubyte[] src;// alpha;
		//int length = sizeX - offsetXA - offsetXB, l4 = length * 4;
		src.length = tileX * 4;
		//alpha.length = tileX * 4;
		if((sX + rasterX <= 0 || sX > totalX) && !wrapMode) return;
		
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
					ubyte *c = tileSet[currentTile].getPtr();	// pointer to the current tile's pixeldata
					c += offsetY;
					c += xp;
					main8BitColorLookupFunction(c, src.ptr, palette, tileXtarget);
					//createAlphaMask(src.ptr, alpha.ptr, tileXtarget);
					mainRenderingFunction(src.ptr, p0, null, tileXtarget);
					p0 += (tileX - xp) * 4;
					x+=tileX - xp;
				}else{
					x+=tileX;
				}


			}
					
		}
				
		
	}
	
	public BLInfo getLayerInfo(){
		return BLInfo(tileX,tileY,mX,mY);
	}
	public Bitmap8Bit getTile(wchar id){
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
	public Coordinate[int] getCoordinates();
	///Returns all flipregisters.
	public FlipRegister[int] getFlipRegisters();
	public int[int] getSpriteSorter();
	
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
}
/**
 *General SpriteLayer interface with 16bit related sprite operations.
 */
public interface ISpriteLayer16Bit : ISpriteLayer{
	///Adds a sprite to the layer.
	public void addSprite(Bitmap16Bit s, int n, Coordinate c);
	///Adds a sprite to the layer.
	public void addSprite(Bitmap16Bit s, int n, int x, int y);
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(Bitmap16Bit s, int n);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap16Bit s, int n, int x, int y);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap16Bit s, int n, Coordinate c);
}
/**
 *General SpriteLayer interface with 32bit related sprite operations.
 */
public interface ISpriteLayer32Bit : ISpriteLayer{
	///Adds a sprite to the layer.
	public void addSprite(Bitmap32Bit s, int n, Coordinate c);
	///Adds a sprite to the layer.
	public void addSprite(Bitmap32Bit s, int n, int x, int y);
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(Bitmap32Bit s, int n);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap32Bit s, int n, int x, int y);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap32Bit s, int n, Coordinate c);
}
/**
 *General SpriteLayer interface with 8bit related sprite operations.
 */
public interface ISpriteLayer8Bit : ISpriteLayer{
	///Adds a sprite to the layer.
	public void addSprite(Bitmap8Bit s, int n, Coordinate c);
	///Adds a sprite to the layer.
	public void addSprite(Bitmap8Bit s, int n, int x, int y);
	///Replaces the sprite. If the new sprite has a different dimension, the old sprite's upper-left corner will be used.
	public void replaceSprite(Bitmap8Bit s, int n);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap8Bit s, int n, int x, int y);
	///Replaces the sprite and moves to the given position.
	public void replaceSprite(Bitmap8Bit s, int n, Coordinate c);
}
/**
 *Use it to call the collision detector
 */
public interface SpriteMovementListener{
	///Called when a sprite is moved.
	void spriteMoved(int ID);
}
/**
 *Sprite controller and renderer.
 */
public class SpriteLayer : Layer, ISpriteCollision, ISpriteLayer16Bit{
	private Bitmap16Bit[int] spriteSet;			///Stores the sprites.
	private Coordinate[int] coordinates;		///Stores the coordinates.
	private FlipRegister[int] flipRegisters;	///Stores the flip registers.
	private int[] spriteSorter;					///Stores the priorities.
	public SpriteMovementListener[int] collisionDetector;
	//Constructors. 
	/*public this(int n){
	 spriteSet.length = n;
	 coordinates.length = n;
	 flipRegisters.length = n;
	 }*/
	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		setRenderingMode(renderMode);
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
	
	public Coordinate getSpriteCoordinate(int n){
		return coordinates[n];
	}

	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		foreach_reverse(int i ; spriteSorter){
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				int offsetXA = sX > coordinates[i].left ? sX - coordinates[i].left : 0;
				int offsetXB = sX + rasterX < coordinates[i].right ? coordinates[i].right - rasterX : 0; 
				int offsetYA = sY > coordinates[i].top ? sY - coordinates[i].top : 0; 
				int offsetYB = sY + rasterY < coordinates[i].bottom ? coordinates[i].bottom - rasterY : 0;
				int sizeX = coordinates[i].width(), offsetX = coordinates[i].left - sX;
				ushort* p0 = spriteSet[i].getPtr();
				p0 += offsetXA + (sizeX * offsetYA);
				ubyte[] src;//, alpha;
				int length = sizeX - offsetXA - offsetXB, lfour = length * 4;
				src.length = lfour;
				//alpha.length = lfour;
				int offsetY = sY < coordinates[i].top ? (coordinates[i].top-sY)*pitch : 0;
				void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
				for(int y = offsetYA ; y < coordinates[i].height() - offsetYB ; y++){		
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						mainColorLookupFunction(p0, src.ptr, palette, length);
						mainHorizontalMirroringFunction(src.ptr, length);
						mainRenderingFunction(src.ptr, dest, null, length);
					}else{ //for non flipped sprites
						mainColorLookupFunction(p0, src.ptr, palette, length);
						mainRenderingFunction(src.ptr, dest, null, length);
					}
					dest += pitch;
					p0 += sizeX;
				}
			}
		}
		
	}

}
/**
 *Sprite controller and renderer for 8 bit sprites.
 */
public class SpriteLayer8Bit : Layer, ISpriteCollision, ISpriteLayer8Bit{
	private Bitmap8Bit[int] spriteSet;			///Stores the sprites.
	private Coordinate[int] coordinates;		///Stores the coordinates.
	private FlipRegister[int] flipRegisters;	///Stores the flip registers.
	private int[] spriteSorter;					///Stores the priorities.
	public SpriteMovementListener[int] collisionDetector;
	//Constructors. 
	/*public this(int n){
	 spriteSet.length = n;
	 coordinates.length = n;
	 flipRegisters.length = n;
	 }*/
	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		setRenderingMode(renderMode);
	}
	
	public void addSprite(Bitmap8Bit s, int n, Coordinate c){
		spriteSet[n] = s;
		coordinates[n] = c;
		flipRegisters[n] = FlipRegister.NORM;
		spriteSorter ~= n;
		//sortSprites();
		spriteSorter.sort();
		
	}
	
	public void addSprite(Bitmap8Bit s, int n, int x, int y){
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
	public void replaceSprite(Bitmap8Bit s, int n){

		if(!(s.getX == spriteSet[n].getX && s.getY == spriteSet[n].getY)){
			coordinates[n] = Coordinate(coordinates[n].left,coordinates[n].top,coordinates[n].left + s.getX,coordinates[n].top + s.getY);
		}
		spriteSet[n] = s;
	}

	public void replaceSprite(Bitmap8Bit s, int n, int x, int y){
		spriteSet[n] = s;
		coordinates[n] = Coordinate(x,y,x+s.getX(),y+s.getY());
	}

	public void replaceSprite(Bitmap8Bit s, int n, Coordinate c){
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
	
	public Bitmap8Bit[int] getSpriteSet(){
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
	
	public Coordinate getSpriteCoordinate(int n){
		return coordinates[n];
	}

	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		foreach_reverse(int i ; spriteSorter){
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				int offsetXA = sX > coordinates[i].left ? sX - coordinates[i].left : 0;
				int offsetXB = sX + rasterX < coordinates[i].right ? coordinates[i].right - rasterX : 0; 
				int offsetYA = sY > coordinates[i].top ? sY - coordinates[i].top : 0; 
				int offsetYB = sY + rasterY < coordinates[i].bottom ? coordinates[i].bottom - rasterY : 0;
				int sizeX = coordinates[i].width(), offsetX = coordinates[i].left - sX;
				ubyte* p0 = spriteSet[i].getPtr();
				p0 += offsetXA + (sizeX * offsetYA);
				ubyte[] src;//, alpha;
				int length = sizeX - offsetXA - offsetXB, lfour = length * 4;
				src.length = lfour;
				//alpha.length = lfour;
				int offsetY = sY < coordinates[i].top ? (coordinates[i].top-sY)*pitch : 0;
				void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
				for(int y = offsetYA ; y < coordinates[i].height() - offsetYB ; y++){		
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						main8BitColorLookupFunction(p0, src.ptr, palette, length);
						mainHorizontalMirroringFunction(src.ptr, length);
						mainRenderingFunction(src.ptr, dest, null, length);
					}else{ //for non flipped sprites
						main8BitColorLookupFunction(p0, src.ptr, palette, length);
						mainRenderingFunction(src.ptr, dest, null, length);
					}
					dest += pitch;
					p0 += sizeX;
				}
			}
		}
		
	}

}
/**
 *Sprite controller and renderer for 32 bit sprites.
 */
public class SpriteLayer32Bit : Layer, ISpriteCollision, ISpriteLayer32Bit{
	private Bitmap32Bit[int] spriteSet;
	private Coordinate[int] coordinates;		//Use moveSprite() and relMoveSprite() instead to move sprites
	private FlipRegister[int] flipRegisters;
	private int[] spriteSorter;
	public SpriteMovementListener[int] collisionDetector;

	
	public this(LayerRenderingMode renderMode = LayerRenderingMode.ALPHA_BLENDING){
		setRenderingMode(renderMode);
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
	
	public Coordinate getSpriteCoordinate(int n){
		return coordinates[n];
	}

	public override void updateRaster(void* workpad, int pitch, ubyte* palette, int[] threads){
		/*foreach_reverse(int i ; spriteSorter){
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				int offsetXA = sX > coordinates[i].left ? sX - coordinates[i].left : 0;
				int offsetXB = sY > coordinates[i].top ? sY - coordinates[i].top : 0; 
				int offsetYA = sX + rasterX < coordinates[i].right ? coordinates[i].right - rasterX : 0; 
				int offsetYB = sY + rasterY < coordinates[i].bottom ? coordinates[i].bottom - rasterY : 0;
				int sizeX = coordinates[i].width(), offsetX = coordinates[i].left - sX;
				ubyte* src = spriteSet[i].getPtr();
				src += offsetXA;
				ubyte[] alpha, src2;
				int length = sizeX - offsetXA - offsetXB, lfour = length * 4;
				alpha.length = lfour;
				src2.length = lfour;
				int offsetY = (coordinates[i].top - sY)*pitch;
				void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
				for(int y = offsetYA ; y < coordinates[i].height() - offsetYB ; y++){
					//src + offsetXA + offsetP;
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						
					}
					else{ //for non flipped sprites
						
						mainRenderingFunction(src, dest, alpha.ptr, length);
					}
					dest += pitch;
					src += lfour;
				}
			}
		}*/
		foreach_reverse(int i ; spriteSorter){
			if((coordinates[i].right > sX && coordinates[i].bottom > sY) && (coordinates[i].left < sX + rasterX && coordinates[i].top < sY + rasterY)) {
				int offsetXA = sX > coordinates[i].left ? sX - coordinates[i].left : 0;
				int offsetXB = sX + rasterX < coordinates[i].right ? coordinates[i].right - rasterX : 0; 
				int offsetYA = sY > coordinates[i].top ? sY - coordinates[i].top : 0; 
				int offsetYB = sY + rasterY < coordinates[i].bottom ? coordinates[i].bottom - rasterY : 0;
				int sizeX = coordinates[i].width(), offsetX = coordinates[i].left - sX;
				ubyte* p0 = spriteSet[i].getPtr();
				p0 += (offsetXA + (sizeX * offsetYA)) * 4;
				ubyte[] src2;//, alpha;
				int length = sizeX - offsetXA - offsetXB, lfour = sizeX * 4;
				if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
					src2.length = lfour;
				}
				//alpha.length = lfour;
				int offsetY = sY < coordinates[i].top ? (coordinates[i].top-sY)*pitch : 0;
				void* dest = workpad + (offsetX + offsetXA)*4 + offsetY;
				for(int y = offsetYA ; y < coordinates[i].height() - offsetYB ; y++){		
					if(flipRegisters[i] == FlipRegister.X || flipRegisters[i] == FlipRegister.XY){
						copyRegion(p0, src2.ptr, null, length);
						mainHorizontalMirroringFunction(src2.ptr, length);
						mainRenderingFunction(src2.ptr, dest, null, length);
					}else{ //for non flipped sprites
						mainRenderingFunction(p0, dest, null, length);
					}
					dest += pitch;
					p0 += lfour;
				}
			}
		}		

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
		public ubyte[4][] colors;
		public ushort[] indexedColors;
		public int[] values;
		public this(CommandType command, Coordinate[] coordinates, ubyte[4][] colors, int[] values = null){
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

	override public void updateRaster(void* workpad,int pitch,ubyte* palette,int[] threads) {
		foreach(int i; commandListPriorities){
			switch(commandList[i].command){
				case CommandType.XORBLITTERLINE:
					int offset = (commandList[i].coordinates[0].top * pitch) + commandList[i].coordinates[0].left;
					if(commandList[i].indexedColors is null){
						xorBlitter(workpad + offset,commandList[i].colors[0],commandList[i].coordinates[0].width());
					}else{
						xorBlitter(workpad + offset,*cast(ubyte[4]*)(palette+(4*commandList[i].indexedColors[0])),commandList[i].coordinates[0].width());
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
					copyRegion(workpad + offset, workpad + offset + commandList[i].values[0], null, commandList[i].coordinates[0].width());
					break;
				default: 
					break;
			}
		}
	}
	
}