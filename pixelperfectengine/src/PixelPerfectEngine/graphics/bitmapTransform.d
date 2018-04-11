module PixelPerfectEngine.graphics.bitmapTransform;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.layers module
 */
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;

alias LayerTransformer = BitmapTransformer!(Layer);
/**
 * Performs integer-based horizontal and vertical scaling, shear-mapping, rotation, reflection, etc.
 * T refers to bitmap or layer types. Can be used as a way to create transformable tile layers, uses a Bitmap32Bit as its own framebuffer.
 */
public class BitmapTransformer(T){
	private int scale_x;
	private int scale_y;
	private int shear_x;
	private int shear_y;
	private int[] threads;
	//private int inoffsetX, inoffsetY, outoffsetX, outoffsetY;

	static if(T.mangleof == Bitmap4Bit.mangleof || T.mangleof == Bitmap8Bit.mangleof || T.mangleof == Bitmap16Bit.mangleof || T.mangleof == Bitmap32Bit.mangleof){
		private Coordinate recalculatedBox;
		private T source;
		public T output;
		this(T source){
			this.source = source;
			static if(T == Bitmap4Bit){
				output == new Bitmap4Bit(source.width, source.height, source.getPalettePtr());
			}else static if(T == Bitmap8Bit){
				output == new Bitmap8Bit(source.width, source.height, source.getPalettePtr());
			}else static if(T == Bitmap16Bit){
				output == new Bitmap16Bit(source.width, source.height);
			}else static if(T == Bitmap32Bit){
				output == new Bitmap32Bit(source.width, source.height);
			}
			recalculatedBox = Coordinate(0,0,source.width,source.height);
		}
	}else static assert(`Template argument '` ~ T.stringof ~ `' not supported by class BitmapTransformer(T)!`);

	public void refresh(){
		//calculate new output size

	}

	protected @nogc void memCpy8(void* src, void* dest, size_t length){
		version(X86){
			version(NO_SSE2){
				size_t target8 = length/8, target1 = length - target16;
				asm @nogc {
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		onebytecopy; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenbytecopy:
					movd	MM0, [ESI];	
					movd	[EDI], MM0;
					add		ESI, 8;
					add		EDI, 8;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenbytecopy;

				onebytecopy:
					
					mov		ECX, target1;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				onebytecopyloop:

					mov		AL, [ESI];
					mov		[EDI], AL;
					inc		ESI;
					inc		EDI;
					dec		ECX;
					cmp		ECX, 0;
					jnz		onebytecopyloop;

				endofalgorithm:;
				}
			}else{
				size_t target16 = length/16, target4 = (length - target16)%4, target1 = length - target16 - target4;
				asm @nogc {
					mov		ESI, src[EBP];
					mov		EDI, dest[EBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourbytecopy; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenbytecopy:
					movups	XMM0, [ESI];	
					movups	[EDI], XMM0;
					add		ESI, 16;
					add		EDI, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenbytecopy;
			
				fourbytecopy:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		onebytecopy;
			
				fourbytecopyloop:

					movd	XMM0, [ESI];
					movd	[EDI], XMM0;
					add		ESI, 4;
					add		EDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourbytecopyloop;

				onebytecopy:
					
					mov		ECX, target1;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				onebytecopyloop:

					mov		AL, [ESI];
					mov		[EDI], AL;
					inc		ESI;
					inc		EDI;
					dec		ECX;
					cmp		ECX, 0;
					jnz		onebytecopyloop;

				endofalgorithm:;
				}
			}
		}else version(X86_64){
			size_t target16 = length/16, target4 = (length - target16)%4, target1 = length - target16 - target4;
				asm @nogc {
					mov		RSI, src[RBP];
					mov		RDI, dest[RBP];
					mov		ECX, target16;
					cmp		ECX, 0;
					jz		fourbytecopy; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenbytecopy:
					movups	XMM0, [RSI];	
					movups	[RDI], XMM0;
					add		RSI, 16;
					add		RDI, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenbytecopy;
			
				fourbytecopy:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		onebytecopy;
			
				fourbytecopyloop:

					movd	XMM0, [RSI];
					movd	[RDI], XMM0;
					add		RSI, 4;
					add		RDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourbytecopyloop;

				onebytecopy:
					
					mov		ECX, target1;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				onebytecopyloop:

					mov		AL, [RSI];
					mov		[RDI], AL;
					inc		RSI;
					inc		RDI;
					dec		ECX;
					cmp		ECX, 0;
					jnz		onebytecopyloop;

				endofalgorithm:;
				}
		}else{
			for(int i ; i < length ; i++){
				*cast(ubyte*)dest++ = *cast(ubyte*)src++;
				
			}
		}
	}
	protected @nogc void memCpy32(void* src, void* dest, size_t length){
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
					jz		fourbytecopy; //skip 16 byte operations if not needed
					//iteration cycle entry point
				sixteenbytecopy:
					movups	XMM0, [ESI];	
					movups	[EDI], XMM0;
					add		ESI, 16;
					add		EDI, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		sixteenbytecopy;
			
				fourbytecopy:
			
					mov		ECX, target4;
					cmp		ECX, 0;
					jz		endofalgorithm;
			
				fourbytecopyloop:

					movd	XMM0, [ESI];
					movd	[EDI], XMM0;
					add		ESI, 4;
					add		EDI, 4;
					dec		ECX;
					cmp		ECX, 0;
					jnz		fourbytecopyloop;
			
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
				jz		fourbytecopy; //skip 16 byte operations if not needed
				//iteration cycle entry point
			sixteenbytecopy:
				movups	XMM0, [RSI];	
				movups	[RDI], XMM0;
				add		RSI, 16;
				add		RDI, 16;
				dec		RCX;
				cmp		RCX, 0;
				jnz		sixteenbytecopy;
			
			fourbytecopy:
			
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
}