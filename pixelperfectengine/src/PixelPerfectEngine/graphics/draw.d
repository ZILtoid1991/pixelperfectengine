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
import PixelPerfectEngine.graphics.text : Text;
//import system.etc;
/**
 * Draws into a 8bit bitmap.
 */
public class BitmapDrawer{
	public Bitmap8Bit output;
	public ubyte brushTransparency;
	///Creates the object alongside its output.
	public this(int x, int y) pure {
		output = new Bitmap8Bit(x, y);

	}
	///Draws a single line.
	public void drawLine(int xa, int xb, int ya, int yb, ubyte color) pure {
		draw.drawLine(xa, ya, xb, yb, color, output.getPtr(), output.width);
	}
	///Draws a line using a brush.
	public void drawLine(int xa, int xb, int ya, int yb, Bitmap8Bit brush) pure {
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
	public void insertBitmap(int x, int y, Bitmap8Bit bitmap) pure {
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
	public void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color) pure {
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
	public void insertBitmapSlice(int x, int y, Bitmap8Bit bitmap, Coordinate slice) pure {
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
	public void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color, Coordinate slice) pure {
		if(slice.width <= 0) return;
		if(slice.height <= 0) return;
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		const int bmpWidth = bitmap.width;
		psrc += slice.left + bmpWidth * slice.top;
		//int length = slice.width;
		for(int iy ; iy < slice.height ; iy++){
			compose.textBlitter(psrc,pdest,slice.width,color);
			psrc += bmpWidth;
			pdest += output.width;
		}
	}
	///Draws a rectangle.
	public void drawRectangle(int xa, int xb, int ya, int yb, ubyte color) pure {
		drawLine(xa, xa, ya, yb, color);
		drawLine(xb, xb, ya, yb, color);
		drawLine(xa, xb, ya, ya, color);
		drawLine(xa, xb, yb, yb, color);
	}

	public void drawRectangle(int xa, int xb, int ya, int yb, Bitmap8Bit brush) pure {
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
	public void drawFilledRectangle(int xa, int xb, int ya, int yb, ubyte color) pure {
		draw.drawFilledRectangle(xa, ya, xb, yb, color, output.getPtr(), output.width);
	}
	///Fills the area with a pattern.
	public void patternFill(Coordinate pos, Bitmap8Bit pattern) pure {
		const int targetX = pos.width / pattern.width;
		const int targetX0 = pos.width % pattern.width;
		const int targetY = pos.height / pattern.height;
		const int targetY0 = pos.height % pattern.height;
		for(int y ; y < targetY ; y++) {
			for(int x ; x < targetX; x++) 
				insertBitmap(pos.left + (x * pattern.width), pos.top + (y * pattern.height), pattern);
			if(targetX0) 
				insertBitmapSlice(pos.left + (pattern.width * targetX), pos.top + (y * pattern.height), pattern,
						Coordinate(0, 0, targetX0, pattern.height));
		}
		if(targetY0) {
			for(int x ; x < targetX; x++) 
				insertBitmapSlice(pos.left + (x * pattern.width), pos.top + (targetY * pattern.height), pattern,
						Coordinate(0, 0, pattern.width, targetY0));
			if(targetX0) 
				insertBitmapSlice(pos.left + (pattern.width * targetX), pos.top + (targetY * pattern.height), pattern,
						Coordinate(0, 0, targetX0, targetY0));
		}
	}
	///Draws texts. (deprecated, will be removed after Version 0.10.0)
	/+public deprecated void drawText(int x, int y, wstring text, Bitmap8Bit[wchar] fontSet, int style = 0){
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
	}+/
	///Draws text to the given point.
	public void drawText(int x, int y, dstring text, Fontset!(Bitmap8Bit) fontset, uint style = 0) pure {
		const int length = fontset.getTextLength(text);
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
			const Font.Char chinfo = fontset.chars(c);
			const Coordinate letterSlice = Coordinate(chinfo.x, chinfo.y, chinfo.x + chinfo.width, chinfo.y + chinfo.height);
			insertBitmapSlice(x + chinfo.xoffset, y + chinfo.yoffset, fontset.pages[chinfo.page], letterSlice);
			x += chinfo.xadvance;
		}
	}
	///Draws colored text from monocromatic font.
	public void drawColorText(int x, int y, dstring text, Fontset!(Bitmap8Bit) fontset, ubyte color, uint style = 0) pure {
		//color = 1;
		const int length = fontset.getTextLength(text);
		if(style & FontFormat.HorizCentered)
			x = x - (length / 2);
		if(style & FontFormat.VertCentered)
			y -= fontset.getSize() / 2;
		if(style & FontFormat.RightJustified)
			x -= length;
		//int fontheight = fontset.getSize();
		foreach(dchar c ; text){
			const Font.Char chinfo = fontset.chars(c);
			const Coordinate letterSlice = Coordinate(chinfo.x, chinfo.y, chinfo.x + chinfo.width, chinfo.y + chinfo.height);
			insertColorLetter(x + chinfo.xoffset, y + chinfo.yoffset, fontset.pages[chinfo.page], color, letterSlice);
			x += chinfo.xadvance;
		}
	}
	/**
	 * Draws fully formatted text within a given prelimiter specified by pos.
	 * Offset specifies how much of the text is being obscured from the left hand side.
	 * lineOffset specifies how much lines in pixels are skipped on the top.
	 * Return value contains state flags on wheter certain portions of the text were out of bound.
	 */
	public uint drawMultiLineText(Coordinate pos, Text text, int offset = 0, int lineOffset = 0) pure {
		int lineCount = lineOffset;
		const int maxLines = pos.height + lineOffset;
			if(lineCount >= lineOffset) {	//draw if linecount is greater or equal than offset
				//special
			}
		do {

		} while(lineCount < maxLines);
		return 0;
	}
	/**
	 * Draws a single line fully formatted text within a given prelimiter specified by pos.
	 * Offset specifies how much of the text is being obscured from the left hand side.
	 * lineOffset specifies how much lines in pixels are skipped on the top.
	 * Return value contains state flags on wheter certain portions of the text were out of bound.
	 */
	public uint drawSingleLineText(Coordinate pos, Text text, int offset = 0, int lineOffset = 0) {
		uint status;
		const int textWidth = text.getWidth();
		if(textWidth <= pos.width){
			if(text.formatting.formatFlags & FormattingFlags.rightJustify) {
				pos.left += pos.width - textWidth;
			} else if(text.formatting.formatFlags & FormattingFlags.centerJustify) {
				pos.left += (pos.width - textWidth) / 2;
			}
		}
		int pX = pos.left;
		const int targetX = textWidth - offset > pos.width ? pos.right : pos.left + textWidth;
		Text currTextChunk = text;
		int currCharPos = text.icon ? -1 : 0;
		pX += currTextChunk.frontTab - offset > 0 ? currTextChunk.frontTab - offset : 0;
		
		while (pX < targetX) {	//Per character/symbol drawing
			if(currCharPos == -1) {
				//if there's enough space for the icon, then draw it
				pX += text.iconOffsetX;
				if(pX + text.icon.width < targetX) {
					const int targetHeight = pos.height > text.icon.height - lineOffset ? text.icon.height : pos.height;
					if(pX >= offset) 
						insertBitmapSlice(pX, pos.top + text.iconOffsetY, text.icon, Coordinate(0, lineOffset, text.icon.width, 
								targetHeight));
					else if(pX + text.icon.width >= offset) 
						insertBitmapSlice(pX, pos.top + text.iconOffsetY, text.icon, Coordinate(pX - offset, lineOffset, text.icon.width, 
								targetHeight));
					pX += text.iconSpacing;
					currCharPos++;
				} else return status | TextDrawStatus.RHSOutOfBound;
			} else {
				//check if there's any characters left in the current text chunk, if not step onto the next one if any, if not then return
				if(currCharPos >= currTextChunk.text.length) {
					if(currTextChunk.next) currTextChunk = currTextChunk.next;
					else return status;
					if(currTextChunk.icon) currCharPos = -1;
					else currCharPos = 0;
					pX += currTextChunk.frontTab;
				} else {
					//if there's enough space for the next character, then draw it
					const dchar chr = text.text[currCharPos];
					Font.Char chrInfo = text.font.chars(chr);
					//check if the character exists in the fontset, if not, then substitute it and set flag for missing character
					if(chrInfo.id == 0xFFFD) status |= TextDrawStatus.CharacterNotFound;
					if(pX < targetX) {
						if(pX + chrInfo.xadvance >= offset) {	
							Coordinate letterSlice = Coordinate(chrInfo.x, chrInfo.y + lineOffset, chrInfo.x + chrInfo.width, chrInfo.y + 
								chrInfo.height);
							const int xOffset = pX < offset ? offset - pX : 0;
							letterSlice.left += xOffset > chrInfo.xoffset ? xOffset : 0; //Draw portion of letter if it's partly obscured at the left
							letterSlice.top += lineOffset > chrInfo.yoffset ? chrInfo.yoffset - lineOffset : 0;
							if(pX + chrInfo.xoffset + chrInfo.width >= targetX){//Draw portion of letter if it's partly obscured at the left
								letterSlice.right -= targetX - (pX + chrInfo.xoffset + chrInfo.width);
								status |= TextDrawStatus.RHSOutOfBound;
							}
							/+letterSlice.right -= pX + chrInfo.xoffset + chrInfo.width >= targetX ? 
									(pX - chrInfo.xoffset) - (targetX - chrInfo.xoffset) : 0;+/
							insertColorLetter(pX + chrInfo.xoffset - xOffset, pos.top + chrInfo.yoffset - lineOffset, 
									text.font.pages[chrInfo.page], text.formatting.color, letterSlice);
						}
						pX += chrInfo.xadvance;
						currCharPos++;
					} else return status | TextDrawStatus.RHSOutOfBound;
				}
			}
		}
		return status;
	}
}
/**
 * Font formatting flags.
 */
enum FontFormat : uint {
	HorizCentered			=	0x1,
	VertCentered			=	0x2,
	RightJustified			=	0x10,
	SingleLine				=	0x100,	///Forces text as single line
}
/**
 * Text drawing return flags.
 */
enum TextDrawStatus : uint {
	CharacterNotFound		=	0x01_00,	///Set if there's any character that was not found in the character set
	LHSOutOfBound			=	0x00_01,
	RHSOutOfBound			=	0x00_02,
	TPOutOfBound			=	0x00_04,
	BPOutOfBound			=	0x00_08,
}