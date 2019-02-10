/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.draw module
 */

module PixelPerfectEngine.graphics.draw;

import std.stdio;
import std.math;
import std.conv;

import PixelPerfectEngine.graphics.bitmap;
import compose = CPUblit.composing;
import draw = CPUblit.draw;
import bmfont;
public import PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.common;
//import system.etc;
/**
 * Draws into a 8bit bitmap.
 */
public class BitmapDrawer{
	public Bitmap8Bit output;
	public ubyte brushTransparency;
	///Creates the object alongside its output.
	public this(int x, int y){
		output = new Bitmap8Bit(x, y);

	}
	///Draws a single line.
	public void drawLine(int xa, int xb, int ya, int yb, ubyte color){
		draw.drawLine(xa, ya, xb, yb, color, output.getPtr(), output.width);
	}
	///Draws a line using a brush.
	public void drawLine(int xa, int xb, int ya, int yb, Bitmap8Bit brush){
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
	public void insertBitmap(int x, int y, Bitmap8Bit bitmap){
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		int length = bitmap.width;
		for(int iy ; iy < bitmap.height ; iy++){
			compose.blitter(psrc,pdest,length);
			psrc += length;
			pdest += output.width;
		}
	}
	///Inserts a color letter.
	public void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color){
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		int length = bitmap.width;
		for(int iy ; iy < bitmap.height ; iy++){
			compose.textBlitter(psrc,pdest,length,color);
			psrc += length;
			pdest += output.width;
		}
	}
	///Inserts a midsection of the bitmap defined by slice
	public void insertBitmapSlice(int x, int y, Bitmap8Bit bitmap, Coordinate slice){
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		int bmpWidth = bitmap.width;
		psrc += slice.left + bmpWidth * slice.top;
		int length = slice.width;
		for(int iy ; iy < slice.height ; iy++){
			compose.blitter(psrc,pdest,length);
			psrc += bmpWidth;
			pdest += output.width;
		}
	}
	///Inserts a midsection of the bitmap defined by slice as a color letter
	public void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color, Coordinate slice){
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		int bmpWidth = bitmap.width;
		psrc += slice.left + bmpWidth * slice.top;
		int length = slice.width;
		for(int iy ; iy < slice.height ; iy++){
			compose.textBlitter(psrc,pdest,length,color);
			psrc += bmpWidth;
			pdest += output.width;
		}
	}
	///Draws a rectangle.
	public void drawRectangle(int xa, int xb, int ya, int yb, ubyte color){
		drawLine(xa, xa, ya, yb, color);
		drawLine(xb, xb, ya, yb, color);
		drawLine(xa, xb, ya, ya, color);
		drawLine(xa, xb, yb, yb, color);
	}

	public void drawRectangle(int xa, int xb, int ya, int yb, Bitmap8Bit brush){
		xa = xa + brush.width;
		ya = ya + brush.height;
		xb = xb - brush.width;
		yb = yb - brush.height;
		drawLine(xa, xa, ya, yb, brush);
		drawLine(xb, xb, ya, yb, brush);
		drawLine(xa, xb, ya, ya, brush);
		drawLine(xa, xb, yb, yb, brush);
	}
	///Draws a filled rectangle.
	public void drawFilledRectangle(int xa, int xb, int ya, int yb, ubyte color){
		draw.drawFilledRectangle(xa, ya, xb, yb, color, output.getPtr(), output.width);
	}
	///Fills the area with a pattern.
	public void patternFill(int xa, int ya, int xb, int yb, Bitmap8Bit pattern){

	}
	///Draws texts. (deprecated, will be removed after Version 1.0.0)
	public deprecated void drawText(int x, int y, wstring text, Bitmap8Bit[wchar] fontSet, int style = 0){
		int length;
		for(int i ; i < text.length ; i++){
			length += fontSet[text[i]].width;
		}
		//writeln(text);
		if(style == 0){
			x = x - (length / 2);
			y -= fontSet['a'].height / 2;
		}
		foreach(wchar c ; text){

			insertBitmap(x, y, fontSet[c]);
			x = x + fontSet[c].width;
		}
	}
	///Draws text to the given point.
	public void drawText(int x, int y, dstring text, Fontset!(Bitmap8Bit) fontset, uint style = 0){
		int length = fontset.getTextLength(text);
		//writeln(text);
		/+if(style == 0){
			x = x - (length / 2);
			y -= fontset.getSize() / 2;
		}else if(style == 2){
			y -= fontset.getSize();
		}+/
		if(style & FontFormat.HorizCentered)
			x = x - (length / 2);
		if(style & FontFormat.VertCentered)
			y -= fontset.getSize() / 2;
		foreach(dchar c ; text){
			const Font.Char chinfo = fontset.chars[c];
			const Coordinate letterSlice = Coordinate(chinfo.x, chinfo.y, chinfo.x + chinfo.width, chinfo.y + chinfo.height);
			insertBitmapSlice(x + chinfo.xoffset, y + chinfo.yoffset, fontset.pages[chinfo.page], letterSlice);
			x += chinfo.xadvance;
		}
	}
	///Draws colored text from monocromatic font.
	public void drawColorText(int x, int y, dstring text, Fontset!(Bitmap8Bit) fontset, ubyte color, uint style = 0){
		//color = 1;
		int length = fontset.getTextLength(text);
		if(style & FontFormat.HorizCentered)
			x = x - (length / 2);
		if(style & FontFormat.VertCentered)
			y -= fontset.getSize() / 2;
		if(style & FontFormat.RightJustified)
			x -= length;
		int fontheight = fontset.getSize();
		foreach(dchar c ; text){
			const Font.Char chinfo = fontset.chars[c];
			const Coordinate letterSlice = Coordinate(chinfo.x, chinfo.y, chinfo.x + chinfo.width, chinfo.y + chinfo.height);
			insertColorLetter(x + chinfo.xoffset, y + chinfo.yoffset, fontset.pages[chinfo.page], color, letterSlice);
			x += chinfo.xadvance;
		}
	}

}

enum FontFormat : uint{
	HorizCentered			=	0x1,
	VertCentered			=	0x2,
	RightJustified			=	0x10,
}
