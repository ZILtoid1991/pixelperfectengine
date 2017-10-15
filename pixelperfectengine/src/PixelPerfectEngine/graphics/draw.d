﻿/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.draw module
 */

module PixelPerfectEngine.graphics.draw;

import std.stdio;
import std.math;
import std.conv;

import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.common;
//import system.etc;
/**
 * Draws into a 16bit bitmap.
 */
public class BitmapDrawer{
	public Bitmap16Bit output;
	public ushort brushTransparency;
	static const ushort[8] transparencytester8 = [0,0,0,0,0,0,0,0];
	static const ushort[4] transparencytester4 = [0,0,0,0];
	///Creates the object alongside its output.
	public this(int x, int y){
		output = new Bitmap16Bit(x, y);
		
	}
	///Draws a single line. Slanted lines are currently unimplemented.
	public void drawLine(int xa, int xb, int ya, int yb, ushort color, int brushsize = 1){
		if(brushsize > 1){
			xa = xa - brushsize / 2;
			xb = xb - brushsize / 2;
			ya = ya - brushsize / 2;
			yb = yb - brushsize / 2;
		}
		if(xa == xb){
			for(int i ; i < brushsize ; i++){
				if(ya < yb){
					for(int j ; j <= (yb - ya) ; j++){
						
						output.writePixel(xa, ya + j, color);
					}
				}else{
					for(int j ; j > (yb - ya) ; j--){
						output.writePixel(xa, ya + j, color);
					}
				}
				xa++;
				xb++;
			}
		}else if(ya == yb){
			for(int i ; i < brushsize ; i++){
				if(xa < xb){
					for(int j ; j <= (xb - xa) ; j++){
						output.writePixel(xa + j, ya, color);
					}
				}else{
					for(int j ; j > (xb - xa) ; j--){
						output.writePixel(xa + j, ya, color);
					}
				}
				ya++;
				yb++;
			}
		}else{
			if(xa < xb){
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((yb - ya) * (yb - ya))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j <= xb - xa ; j++){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya + y, color);
						}
					}
				}else{
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((ya - yb) * (ya - yb))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j <= xb - xa ; j++){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya - y, color);
						}
					}
				}
			}else{
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((yb - ya) * (yb - ya))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j >= xb - xa ; j--){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya + y, color);
						}
					}
				}else{
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((ya - yb) * (ya - yb))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j >= xb - xa ; j--){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya - y, color);
						}
					}
				}
			}
		}
	}
	///Draws a line using a brush.
	public void drawLine(int xa, int xb, int ya, int yb, Bitmap16Bit brush){
		if(xa == xb){
			
			if(ya < yb){
				for(int j ; j < (yb - ya) ; j++){
					insertBitmap(xa, ya + j, brush);
				}
			}else{
				for(int j ; j > (yb - ya) ; j--){
					insertBitmap(xa, ya + j, brush);
				}
			}
			xa++;
			xb++;
			
		}else if(ya == yb){
			
			if(xa > xb){
				for(int j ; j < (xa - xb) ; j++){
					insertBitmap(xa + j, ya, brush);
				}
			}else{
				for(int j ; j > (xa - xb) ; j--){
					insertBitmap(xa + j, ya, brush);
				}
			}
			ya++;
			yb++;
			
		}else{
			if(xa < xb){
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((yb - ya) * (yb - ya))));
					
					for(int j ; j < xb - xa ; j++){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya + y, brush);
					}
					
				}else{
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((ya - yb) * (ya - yb))));
					
					for(int j ; j < xb - xa ; j++){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya - y, brush);
					}
					
				}
			}else{
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((yb - ya) * (yb - ya))));
					
					for(int j ; j > xb - xa ; j--){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya + y, brush);
					}
					
				}else{
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((ya - yb) * (ya - yb))));
					
					for(int j ; j > xb - xa ; j--){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya - y, brush);
					}
					
				}
			}
		}
	}
	///Inserts a bitmap using blitter.
	public void insertBitmap(int x, int y, Bitmap16Bit bitmap){
		version(X86){
		ushort* psrc = bitmap.getPtr, pdest = output.getPtr;
			int pitch = output.getX;
			for(int iy ; iy < bitmap.getY ; iy++){
				int ix = bitmap.getX / 8; 
				int ix4 = bitmap.getX - ix * 8;
				int offsetY = bitmap.getX * iy;
				ushort[8]* psrc2 = cast(ushort[8]*)(psrc + offsetY), pdest2 = cast(ushort[8]*)(pdest + x + ((iy + y) * pitch));
				asm{
					mov		EDI, pdest2[EBP];
					mov		ESI, psrc2[EBP];
					mov		ECX, ix;
					//cmp		ECX, 0;
					jecxz	blt4px;
				loopstart:		//using 8 pixel blitter for the most part
				
					movups	XMM0, [ESI];
					movups	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movups	[EDI], XMM1;
				
					add		ESI, 16;
					add		EDI, 16;
					loop	loopstart;
				
					//4 pixel blitter if needed
				blt4px:
					mov		ECX, ix4;
					cmp		ECX, 4;
					jb		blt2px;
					sub		ECX, 4;
					movq	XMM0, [ESI];
					movq	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movq	[EDI], XMM1;
				
					add		ESI, 8;
					add		EDI, 8;
					//2 pixel blitter if needed
				blt2px:
					cmp		ECX, 2;
					jb		blt1px;
					sub		ECX, 2;
					movd	XMM0, [ESI];
					movd	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movd	[EDI], XMM1;
				
					add		ESI, 4;
					add		EDI, 4;
					//1 pixel "blitter" if needed
				blt1px:
					jecxz	end;
					mov		AX, [ESI];
					cmp		AX, 0;
					cmovz	AX, [EDI];
					mov		[EDI], AX;
				end:;
				}
			
			}
		}
	}
	///Inserts a midsection of the bitmap defined by slice
	public void insertBitmapSlice(int x, int y, Bitmap16Bit bitmap, Coordinate slice){
		version(X86){
			for(int iy ; iy < slice.height() ; iy++){
				int ix = slice.width() / 8;
				int offsetY = bitmap.getX * (iy + slice.top);
				int ix4 = slice.width() - ix * 8;
				ushort* psrc = bitmap.getPtr, pdest = output.getPtr;
				ushort[8]* psrc2 = cast(ushort[8]*)(psrc + offsetY + slice.left), pdest2 = cast(ushort[8]*)(pdest + ((iy + y) * output.getX));
			
				asm{
					mov		EDI, pdest2[EBP];
					mov		ESI, psrc2[EBP];
					mov		ECX, ix;
					//cmp		ECX, 0;
					jecxz	blt4px;
				loopstart:		//using 8 pixel blitter for the most part
				
					movups	XMM0, [ESI];
					movups	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movups	[EDI], XMM1;
				
					add		ESI, 16;
					add		EDI, 16;
					loop	loopstart;
					
					//4 pixel blitter if needed
				blt4px:
					mov		ECX, ix4;
					cmp		ECX, 4;
					jb		blt2px;
					sub		ECX, 4;
					movq	XMM0, [ESI];
					movq	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movq	[EDI], XMM1;
				
					add		ESI, 8;
					add		EDI, 8;
					//2 pixel blitter if needed
				blt2px:
					cmp		ECX, 2;
					jb		blt1px;
					sub		ECX, 2;
					movd	XMM0, [ESI];
					movd	XMM1, [EDI];
					movups	XMM4, transparencytester8;
					pcmpeqw	XMM4, XMM0;
					pand	XMM1, XMM4;
					por		XMM1, XMM0;
					movd	[EDI], XMM1;
				
					add		ESI, 4;
					add		EDI, 4;
					//1 pixel "blitter" if needed
				blt1px:
					jecxz	end;
					mov		AX, [ESI];
					cmp		AX, 0;
					cmovz	AX, [EDI];
					mov		[EDI], AX;
				end:;
				}
			
			
			}
		}
	}
	///Draws a rectangle.
	public void drawRectangle(int xa, int xb, int ya, int yb, ushort color, int brushsize = 1){
		drawLine(xa, xa, ya, yb, color, brushsize);
		drawLine(xb, xb, ya, yb, color, brushsize);
		drawLine(xa, xb, ya, ya, color, brushsize);
		drawLine(xa, xb, yb, yb, color, brushsize);
	}
	
	public void drawRectangle(int xa, int xb, int ya, int yb, Bitmap16Bit brush){
		xa = xa + brush.getX;
		ya = ya + brush.getY;
		xb = xb - brush.getX;
		yb = yb - brush.getY;
		drawLine(xa, xa, ya, yb, brush);
		drawLine(xb, xb, ya, yb, brush);
		drawLine(xa, xb, ya, ya, brush);
		drawLine(xa, xb, yb, yb, brush);
	}
	///Draws a filled rectangle.
	public void drawFilledRectangle(int xa, int xb, int ya, int yb, ushort color){
		//writeln(xa); writeln(ya); writeln(xb); writeln(yb);
		
		ushort[8] colorvect = [color, color, color, color, color, color, color, color];
		ushort* p = output.getPtr;
		int pitch = output.getX;
		for(int y = ya ; y < yb ; y++){
			ushort* p0 = p + xa + y * pitch;
			
			int x = xa;
			//writeln(x);
			while( x < xb - 7 ){
				ushort[8]* p1 = cast(ushort[8]*)p0;
				/*asm{
				 movups	XMM0, colorvect;
				 movups	[p0], XMM0;
				 }*/
				*p1 = colorvect;
				p0 += 8;
				x += 8;
				//writeln(x);
				//output.writePixel(x, y, color);
			}
			if(xb - x > 3){
				ushort[4]* p1 = cast(ushort[4]*)p0;
				/*asm{
				 movups	XMM0, colorvect;
				 movq	[p0], XMM0;
				 }*/
				*p1 = [color,color,color,color];
				x += 4;
				p0 += 4;
				//writeln(x);
			}
			if(xb - x > 1){
				ushort[2]* p1 = cast(ushort[2]*)p0;
				/*asm{
				 movups	XMM0, colorvect;
				 movd	[p0], XMM0;
				 }*/
				*p1 = [color,color];
				x += 2;
				p0 += 2;
				//writeln(x);
			}
			if(xb - x == 1){
				*p0 = color;
				//writeln(x);
			}
		}
	}
	///Fills the area with a pattern.
	public void patternFill(int xa, int ya, int xb, int yb, Bitmap16Bit pattern){
		
	}
	///Draws texts. (deprecated, will be removed after Version 1.0.0)
	public deprecated void drawText(int x, int y, wstring text, Bitmap16Bit[wchar] fontSet, int style = 0){
		int length;
		for(int i ; i < text.length ; i++){
			length += fontSet[text[i]].getX;
		}
		//writeln(text);
		if(style == 0){
			x = x - (length / 2);
			y -= fontSet['a'].getY() / 2;
		}
		foreach(wchar c ; text){
			
			insertBitmap(x, y, fontSet[c]);
			x = x + fontSet[c].getX();
		}
	}
	///Draws text to the given point. Styles: 0 = centered, 1 = left, 2 = right
	public void drawText(int x, int y, wstring text, Fontset fontset, int style = 0){
		int length = fontset.getTextLength(text);
		//writeln(text);
		if(style == 0){
			x = x - (length / 2);
			y -= fontset.getSize() / 2;
		}else if(style == 2){
			y -= fontset.getSize();
		}
		foreach(wchar c ; text){
			insertBitmap(x, y, fontset.letters[c]);
			x = x + fontset.letters[c].getX();
		}
	}
	///Draws colored text from monocromatic font.
	public void drawColorText(int x, int y, wstring text, Fontset fontset, ushort color, int style = 0){
		//color = 1;
		ushort[8] colorvect = [color, color, color, color, color, color, color, color];
		int length = fontset.getTextLength(text);
		//writeln(text);
		if(style == 0){
			x = x - (length / 2);
			y -= fontset.getSize() / 2;
		}else if(style == 2){
			x -= length;
		}
		foreach(wchar c ; text){
			
			insertColorLetter(x, y, fontset.letters[c], colorvect);
			x = x + fontset.letters[c].getX();
		}
	}
	public void insertColorLetter(int x, int y, Bitmap16Bit bitmap, ushort[8] colorvect){
		ushort[8] colortester = [1,1,1,1,1,1,1,1];
		ushort* psrc = bitmap.getPtr, pdest = output.getPtr;
		int pitch = output.getX;
		for(int iy ; iy < bitmap.getY ; iy++){
			int ix = bitmap.getX / 8; 
			int ix4 = bitmap.getX - ix * 8;
			int offsetY = bitmap.getX * iy;
			ushort[8]* psrc2 = cast(ushort[8]*)(psrc + offsetY), pdest2 = cast(ushort[8]*)(pdest + x + ((iy + y) * pitch));
			asm{
				mov		EDI, pdest2[EBP];
				mov		ESI, psrc2[EBP];
				movups	XMM5, colorvect;
				movups	XMM6, colortester;
				mov		ECX, ix;
				//cmp		ECX, 0;
				jecxz	blt4px;
			loopstart:		//using 8 pixel blitter for the most part
				
				movups	XMM0, [ESI];
				movups	XMM1, [EDI];
				movups	XMM4, transparencytester8;
				pcmpeqw	XMM4, XMM0;
				pcmpeqw	XMM0, XMM6;
				pand	XMM0, XMM5;
				
				pand	XMM1, XMM4;
				por		XMM1, XMM0;
				movups	[EDI], XMM1;
				
				add		ESI, 16;
				add		EDI, 16;
				loop	loopstart;
				
				//4 pixel blitter if needed
			blt4px:
				mov		ECX, ix4;
				cmp		ECX, 4;
				jb		blt2px;
				sub		ECX, 4;
				movq	XMM0, [ESI];
				movq	XMM1, [EDI];
				movups	XMM4, transparencytester8;
				pcmpeqw	XMM4, XMM0;
				pcmpeqw	XMM0, XMM6;
				pand	XMM0, XMM5;
				
				pand	XMM1, XMM4;
				por		XMM1, XMM0;
				movq	[EDI], XMM1;
				
				add		ESI, 8;
				add		EDI, 8;
				//2 pixel blitter if needed
			blt2px:
				cmp		ECX, 2;
				jb		blt1px;
				sub		ECX, 2;
				movd	XMM0, [ESI];
				movd	XMM1, [EDI];
				movups	XMM4, transparencytester8;
				pcmpeqw	XMM4, XMM0;
				pcmpeqw	XMM0, XMM6;
				pand	XMM0, XMM5;
				
				pand	XMM1, XMM4;
				por		XMM1, XMM0;
				movd	[EDI], XMM1;
				
				add		ESI, 4;
				add		EDI, 4;
				//1 pixel "blitter" if needed
			blt1px:
				jecxz	end;
				mov		AX, [ESI];
				cmp		AX, 0;
				cmovnz	AX, colorvect[0];
				cmovz	AX, [EDI];
				mov		[EDI], AX;
			end:;
			}
			
		}
	}
}
