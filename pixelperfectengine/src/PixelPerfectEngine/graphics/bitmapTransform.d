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
	private bool horizScaleWay;		///True == upscale; False == downscale
	private ubyte corHorizScale;	///Determines how many pixels would be skipped (downscale), or how much each pixel will be multiplyed (upscale).
	private ushort fineHorizScale;	///Determines which pixels will be skipped (downscale), or doubled (upscale).
	private bool vertScaleWay;		///True == upscale; False == downscale
	private ubyte corVertScale;		///Determines how many pixels would be skipped (downscale), or how much each pixel will be multiplyed (upscale).
	private ushort fineVertScale;	///Determines which pixels will be skipped (downscale), or doubled (upscale). Might refer to multiple pixels.

	private ubyte rotateBy90;

	private bool horizShearWay;		///True == right; False == left
	private ubyte corHorizShear;	///Determines how much each line will be offsetted.
	private ushort fineHorizShear;	///Determines which lines will be offsetted by one.
	private bool vertShearWay;		///True == up; False == down
	private ubyte corVertShear;		///Determines how much each column will be offsetted.
	private ushort fineVertShear;	///Determines which columns will be offsetted by one.
	private bool horizMirror;
	private bool vertMirror;
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
	}else static if(T.stringof == Layer.stringof){
		private Layer[int] layers;
		private int[] layerSorter;	///Handles multiple layers to save processor time with transform effect.
		private Bitmap32Bit source;
		public Bitmap32Bit output;
		this(Layer[int] layers, int backBufferWidth, int backBufferHeight, int outputWidth, int outputHeight, int[] threads = [0]){
			this.layers = layers;
			this.threads = threads;
			source = new Bitmap32Bit(backBufferWidth, backBufferHeight);
			output = new Bitmap32Bit(outputWidth, outputHeight);
		}
	}else static assert(`Template argument '` ~ T.stringof ~ `' not supported by class BitmapTransformer(T)!`);

	public void refresh(){
		//Calculate output size for bitmaps, resize if needed
		static if(T.mangleof != Layer.mangleof){
			int nX, nY;//New sizes for bitmap
			if(horizScaleWay){
				nX = source.width * corHorizScale + source.width / fineHorizScale;
				nY = source.height * corVertScale + source.height / fineVertScale;
			}else{
				nX = source.width / corHorizScale - source.width / fineHorizScale;
				nY = source.height / corVertScale - source.height / fineVertScale;
			}
			nX *= corHorizShear + 1;
			nX *= corVertShear + 1;
			nX += nY / fineHorizShear;
			nY += nX / fineVertShear;
			if(rotateBy90 & 1){
				int k = nX;
				nX = nY;
				nY = k;
			}
			if(output.width != nX || output.height != nY){
				static if(T == Bitmap4Bit){
					output = new Bitmap4Bit(nX, nY, source.getPalettePtr());
				}else static if(T == Bitmap8Bit){
					output = new Bitmap8Bit(nX, nY, source.getPalettePtr());
				}else static if(T == Bitmap16Bit){
					output = new Bitmap16Bit(nX, nY);
				}else{
					output = new Bitmap32Bit(nX, nY);
				}
			}
			//Perform scaling only
			if(!corHorizShear && !fineHorizShear && !corVertShear && !fineVertShear){
				int xSrc, xDest, xWay;
				int ySrc, yDest, yWay;
				switch(rotateBy90 & 3){
					case 0, 2:
						xSrc = horizMirror ? source.width : 0; 
						xDest = horizMirror ? 0 : source.width; 
						xWay = horizMirror ? -1 : 1; 
						ySrc = vertMirror ? source.height : 0; 
						yDest = vertMirror ? 0 : source.height; 
						yWay = vertMirror ? -1 : 1;
						break;
					case 1, 3:
						xSrc = horizMirror ? source.height : 0; 
						xDest = horizMirror ? 0 : source.height; 
						xWay = horizMirror ? -1 : 1; 
						ySrc = vertMirror ? source.width : 0; 
						yDest = vertMirror ? 0 : source.width; 
						yWay = vertMirror ? -1 : 1;
						break;
					default:
						break;
				}
				int cX, cY;	//corase counters
				int fX, fY; //fine counters
				int sX, sY; //source counters
				int kX = -1, kY = -1; //keeper values
				//bool bX, bY; //
				
				//Create a line buffer to reduce CPU stress
				static if(T == Bitmap4Bit){
					ubyte[] lineBuf;
					lineBuf.length = nX / 2;
				}else static if(T == Bitmap8Bit){
					ubyte[] lineBuf;
					lineBuf.length = nX;
				}else static if(T == Bitmap16Bit){
					ushort[] lineBuf;
					lineBuf.length = nX;
				}else{
					Color[] lineBuf;
					lineBuf.length = nX;
				}
				for(int y ; y < nY ; y++){
					if(sY != kY){
						for(int x ; x < nX ; x++){
							static if(T == Bitmap4Bit){
								if(rotateBy90 & 1){
									if(x & 1){
										lineBuf[x/2] |= source.readPixel(ySrc,xSrc)<<4;
									}else{
										lineBuf[x/2] = source.readPixel(ySrc,xSrc);
									}
								}else{
									if(x & 1){
										lineBuf[x/2] |= source.readPixel(xSrc,ySrc)<<4;
									}else{
										lineBuf[x/2] = source.readPixel(xSrc,ySrc);
									}
								}
							}else static if(T == Bitmap8Bit){
								if(rotateBy90 & 1)
									lineBuf[x] = source.readPixel(ySrc,xSrc);
								else
									lineBuf[x] = source.readPixel(xSrc,ySrc);
							}else static if(T == Bitmap16Bit){
								if(rotateBy90 & 1)
									lineBuf[x] = source.readPixel(ySrc,xSrc);
								else
									lineBuf[x] = source.readPixel(xSrc,ySrc);
							}else{
								if(rotateBy90 & 1)
									lineBuf[x] = source.readPixel(ySrc,xSrc);
								else
									lineBuf[x] = source.readPixel(xSrc,ySrc);
							}
							fX++;
							if(horizScaleWay){
								cX++;
								if(fX == fineHorizScale){
									fX = 0;
									cX--;
								}
								if(cX == corHorizScale){
									cX = 0;
									xSrc+=xWay;
								}else{
									xSrc+=xWay * corHorizScale;
									if(fX == fineHorizScale){
										fX = 0;
										xSrc-=xWay;
									}
								}
							}
						}
						kY = sY;
					}/*else{					}*/
					static if(T == Bitmap4Bit){
						memCpy8(lineBuf.ptr, output.getPtr(), (nX * y)/2);
					}else static if(T == Bitmap8Bit){
						memCpy8(lineBuf.ptr, output.getPtr(), nX * y);
					}else static if(T == Bitmap16Bit){
						memCpy8(lineBuf.ptr, output.getPtr(), (nX * y)*2);
					}else static if(T == Bitmap32Bit){
						memCpy32(lineBuf.ptr, output.getPtr(), nX * y);
					}
					fY++;
					if(vertScaleWay){
						cY++;
						if(fY == fineVertScale){
							fY = 0;
							cY--;
						}
						if(cY == corVertScale){
							cY = 0;
							ySrc+=yWay;
						}
					}else{
						ySrc+=yWay * corVertScale;
						if(fY == fineVertScale){
							fY = 0;
							ySrc-=yWay;
						}
					}
				}
			}else if(!corHorizScale && !corVertScale && !fineHorizScale && !fineVertScale){		//perform shear-mapping only
				int xSrc, xDest, xWay;
				int ySrc, yDest, yWay;
				switch(rotateBy90 & 3){
					case 0, 2:
						xSrc = horizMirror ? source.width : 0; 
						xDest = horizMirror ? 0 : source.width; 
						xWay = horizMirror ? -1 : 1; 
						ySrc = vertMirror ? source.height : 0; 
						yDest = vertMirror ? 0 : source.height; 
						yWay = vertMirror ? -1 : 1;
						break;
					case 1, 3:
						xSrc = horizMirror ? source.height : 0; 
						xDest = horizMirror ? 0 : source.height; 
						xWay = horizMirror ? -1 : 1; 
						ySrc = vertMirror ? source.width : 0; 
						yDest = vertMirror ? 0 : source.width; 
						yWay = vertMirror ? -1 : 1;
						break;
					default:
						break;
				}
				int cX, cY;	//corase counters
				int fX, fY; //fine counters
				int kX = -1, kY = -1; //keeper values
				int segmentLength = src.width - src.width / fineVertShear;
				/*
				1) Calculate the new position for each new line
				2) Move to their new position
				*/
				
				/*static if(T == Bitmap4Bit){
					memCpy8(lineBuf.ptr, output.getPtr(), (nX * y)/2);
				}else static if(T == Bitmap8Bit){
					memCpy8(lineBuf.ptr, output.getPtr(), nX * y);
				}else static if(T == Bitmap16Bit){
					memCpy8(lineBuf.ptr, output.getPtr(), (nX * y)*2);
				}else static if(T == Bitmap32Bit){
					memCpy32(lineBuf.ptr, output.getPtr(), nX * y);
				}*/
			}else{		//perform both
				
			}
		}

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