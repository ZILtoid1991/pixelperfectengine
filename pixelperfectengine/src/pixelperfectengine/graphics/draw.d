/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.draw module
 */

module pixelperfectengine.graphics.draw;

import std.stdio;
import std.math;
import std.conv;

import pixelperfectengine.graphics.bitmap;
import compose = CPUblit.composing;
import specblt = CPUblit.composing.specblt;
//import draw = CPUblit.draw;
import draw = CPUblit.drawing.line;
import draw0 = CPUblit.drawing.foodfill;
import bmfont;
public import pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.common;
import pixelperfectengine.graphics.text : Text, isWhiteSpaceMB;
//import system.etc;
/**
 * Draws into a 8bit bitmap.
 */
public class BitmapDrawer {
	public Bitmap8Bit output;
	protected immutable ubyte[2] dottedLine = [0x00, 0xFF];
	protected immutable ubyte[8] stripesLine = [0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF];
	///Creates the object alongside its output.
	public this(int x, int y) pure {
		output = new Bitmap8Bit(x, y);

	}
	/**
	 * Draws a single line.
	 * Parameters:
	 *  from = The beginning of the line.
	 *  to = The endpoint of the line.
	 *  color = The color index to be used for the line.
	 */
	public void drawLine(Point from, Point to, ubyte color) pure {
		draw.drawLine(from.x, from.y, to.x, to.y, color, output.pixels, output.width);
	}
	/**
	 * Draws a line with a pattern.
	 * Parameters:
	 *  from = The beginning of the line.
	 *  to = The end of the line.
	 *  pattern = Contains the color indexes for the line, to draw the pattern.
	 */
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) pure {
		draw.drawLinePattern(from.x, from.y, to.x, to.y, pattern, output.pixels, output.width);
	}
	/**
	 * Draws a box.
	 * Parameters:
	 *  target = Containst the coordinates of the box to be drawn.
	 *  color = The color index which the box will be drawn.
	 */
	public void drawBox(Box target, ubyte color) pure {
		draw.drawLine(target.left, target.top, target.right, target.top, color, output.pixels, output.width);
		draw.drawLine(target.left, target.top, target.left, target.bottom, color, output.pixels, output.width);
		draw.drawLine(target.left, target.bottom, target.right, target.bottom, color, output.pixels, output.width);
		draw.drawLine(target.right, target.top, target.right, target.bottom, color, output.pixels, output.width);
	}
	/**
	 * Draws a box with the supplied pattern as the 
	 * Parameters:
	 *  target = Containst the coordinates of the box to be drawn.
	 *  color = The color index which the box will be drawn.
	 */
	public void drawBox(Box target, ubyte[] pattern) pure {
		draw.drawLinePattern(target.left, target.top, target.right, target.top, pattern, output.pixels, output.width);
		draw.drawLinePattern(target.left, target.top, target.left, target.bottom, pattern, output.pixels, output.width);
		draw.drawLinePattern(target.left, target.bottom, target.right, target.bottom, pattern, output.pixels, output.width);
		draw.drawLinePattern(target.right, target.top, target.right, target.bottom, pattern, output.pixels, output.width);
	}
	/**
	 * Draws a filled box.
	 * Parameters:
	 *  target = The position of the box.
	 *  color = The color of the box (both the line and fill color).
	 */
	public void drawFilledBox(Box target, ubyte color) pure {
		if (target.left >= output.width) target.left = output.width - 1;
		if (target.right >= output.width) target.right = output.width - 1;
		if (target.top >= output.height) target.top = output.height - 1;
		if (target.bottom >= output.height) target.bottom = output.height - 1;
		draw.drawFilledRectangle(target.left, target.top, target.right, target.bottom, color, output.pixels, 
				output.width);
	}
	public void floodFill(Point target, ubyte color, ubyte transparency = 0) pure {
		draw0.floodFill(target.x, target.y, color, output.pixels, output.width, transparency);
	}
	/**
	 * Copies a bitmap to the canvas using 0th index transparency.
	 * Parameters:
	 *  target = Where the top-left corner should fall.
	 *  source = The bitmap to be copied into the output.
	 */
	public void bitBLT(Point target, Bitmap8Bit source) pure {
		ubyte* src = source.getPtr;
		ubyte* dest = output.getPtr + (output.width * target.y) + target.x;
		for (int y ; y < source.height ; y++){
			compose.blitter(src, dest, source.width);
			src += source.width;
			dest += output.width;
		}
	}
	/**
	 * Copies a bitmap slice to the canvas using 0th index transparency.
	 * Parameters:
	 *  target = Where the top-left corner should fall.
	 *  source = The bitmap to be copied into the output.
	 *  slice = Defines what  part of the bitmap should be copied.
	 */
	public void bitBLT(Point target, Bitmap8Bit source, Coordinate slice) pure {
		ubyte* src = source.getPtr + (source.width * slice.top) + slice.left;
		ubyte* dest = output.getPtr + (output.width * target.y) + target.x;
		for (int y ; y < slice.height ; y++){
			compose.blitter(src, dest, slice.width);
			src += source.width;
			dest += output.width;
		}
	}
	/**
	 * Fills the specified area with a pattern.
	 * Parameters:
	 *  pos = The area that needs to be filled with the pattern.
	 *  pattern = The pattern to be used.
	 */
	public void bitBLTPattern(Box pos, Bitmap8Bit pattern) pure {
		const int targetX = pos.width / pattern.width;
		const int targetX0 = pos.width % pattern.width;
		const int targetY = pos.height / pattern.height;
		const int targetY0 = pos.height % pattern.height;
		for(int y ; y < targetY ; y++) {
			for(int x ; x < targetX; x++) 
				bitBLT(Point(pos.left + (x * pattern.width), pos.top + (y * pattern.height)), pattern);
			if(targetX0) 
				bitBLT(Point(pos.left + (pattern.width * targetX), pos.top + (y * pattern.height)), pattern,
						Box(0, 0, targetX0, pattern.height - 1));
		}
		if(targetY0) {
			for(int x ; x < targetX; x++) 
				bitBLT(Point(pos.left + (x * pattern.width), pos.top + (targetY * pattern.height)), pattern,
						Box(0, 0, pattern.width - 1, targetY0));
			if(targetX0) 
				bitBLT(Point(pos.left + (pattern.width * targetX), pos.top + (targetY * pattern.height)), pattern,
						Box(0, 0, targetX0, targetY0));
		}
	}
	/**
	 * XOR blits a repeated bitmap pattern over the specified area.
	 * Parameters:
	 *  target = The area to be XOR blitted.
	 *  pattern = Specifies the pattern to be used.
	 */
	public void xorBitBLT(Box target, Bitmap8Bit pattern) pure {
		import CPUblit.composing.specblt;
		ubyte* dest = output.getPtr + target.left + (target.top * output.width);
		for (int y ; y < target.height ; y++) {
			for (int x ; x < target.width ; x += pattern.width) {
				const size_t l = x + pattern.width <= target.width ? pattern.width : target.width - pattern.width;
				const size_t lineNum = (y % pattern.height);
				xorBlitter(pattern.getPtr + pattern.width * lineNum, dest + output.width * y, l);
			}
		}
	}
	/**
	 * XOR blits a color index over a specified area.
	 * Parameters:
	 *  target = The area to be XOR blitted.
	 *  color = The color index to be used.
	 */
	public void xorBitBLT(Box target, ubyte color) pure {
		import CPUblit.composing.specblt;
		ubyte* dest = output.getPtr + target.left + (target.top * output.width);
		for (int y ; y < target.height ; y++) {
			xorBlitter(dest + output.width * y, target.width, color);
		}
	}
	
	///Inserts a color letter.
	public void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color) pure {
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		int length = bitmap.width;
		for(int iy ; iy < bitmap.height ; iy++){
			specblt.textBlitter(psrc,pdest,length,color);
			psrc += length;
			pdest += output.width;
		}
	}
	/* ///Inserts a midsection of the bitmap defined by slice (DEPRECATED)
	public deprecated void insertBitmapSlice(int x, int y, Bitmap8Bit bitmap, Coordinate slice) pure {
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
	} */
	/* ///Inserts a midsection of the bitmap defined by slice as a color letter (DEPRECATED)
	public deprecated void insertColorLetter(int x, int y, Bitmap8Bit bitmap, ubyte color, Coordinate slice) pure {
		if(slice.width - 1 <= 0) return;
		if(slice.height - 1 <= 0) return;
		ubyte* psrc = bitmap.getPtr, pdest = output.getPtr;
		pdest += x + output.width * y;
		const int bmpWidth = bitmap.width;
		psrc += slice.left + bmpWidth * slice.top;
		//int length = slice.width;
		for(int iy ; iy < slice.height ; iy++){
			specblt.textBlitter(psrc,pdest,slice.width,color);
			psrc += bmpWidth;
			pdest += output.width;
		}
	} */
		
	/* ///Draws colored text from monocromatic font.
	public void drawColorText(int x, int y, dstring text, Fontset!(Bitmap8Bit) fontset, ubyte color, uint style = 0) pure {
		//color = 1;
		const int length = fontset.getTextLength(text);
		if(style & FontFormat.HorizCentered)
			x = x - (length / 2);
		if(style & FontFormat.VertCentered)
			y -= fontset.size / 2;
		if(style & FontFormat.RightJustified)
			x -= length;
		//int fontheight = fontset.getSize();
		foreach(dchar c ; text){
			const Font.Char chinfo = fontset.chars(c);
			const Coordinate letterSlice = Coordinate(chinfo.x, chinfo.y, chinfo.x + chinfo.width, chinfo.y + chinfo.height);
			insertColorLetter(x + chinfo.xoffset, y + chinfo.yoffset, fontset.pages[chinfo.page], color, letterSlice);
			x += chinfo.xadvance;
		}
	} */
	/**
	 * Draws fully formatted text within a given prelimiter specified by pos.
	 * Offset specifies how much of the text is being obscured from the left hand side.
	 * lineOffset specifies how much lines in pixels are skipped on the top.
	 * Return value contains state flags on wheter certain portions of the text were out of bound.
	 */
	public uint drawMultiLineText(Box pos, Text text, int offset = 0, int lineOffset = 0) {
		Text[] lineChunks = text.breakTextIntoMultipleLines(pos.width);
		assert (lineChunks.length);
		return drawMultiLineText(pos, lineChunks, offset, lineOffset);
	}
	/**
	 * Draws fully formatted text within a given prelimiter specified by pos.
	 * Offset specifies how much of the text is being obscured from the left hand side.
	 * lineOffset specifies how much lines in pixels are skipped on the top.
	 * Return value contains state flags on wheter certain portions of the text were out of bound.
	 */
	public uint drawMultiLineText(Box pos, Text[] lineChunks, int offset = 0, int lineOffset = 0) {
		//Text[] lineChunks = text.breakTextIntoMultipleLines(pos.width);
		int lineNum;
		const int maxLines = lineOffset + pos.height;
		/* if(lineCount >= lineOffset) {	//draw if linecount is greater or equal than offset
			//special
		} */
		int currLine = lineOffset * -1;
		
		while (currLine < maxLines && lineNum < lineChunks.length) {
			Box currPos = Box.bySize(pos.left, pos.top + currLine, pos.width, lineChunks[lineNum].getHeight);
			if (currPos.top >= 0) {
				drawSingleLineText(currPos, lineChunks[lineNum], 0, 0);
			} else if (currPos.bottom >= 0) {
				drawSingleLineText(currPos, lineChunks[lineNum], 0, currPos.top * -1);
			}
			currLine += lineChunks[lineNum].getHeight;
			if (lineChunks[lineNum].flags & Text.Flags.newParagraph) currLine += lineChunks[lineNum].formatting.paragraphSpace;
			lineNum++;
		}
		return 0;
	}
	/**
	 * Draws a single line fully formatted text within a given prelimiter specified by pos.
	 * Offset specifies how much of the text is being obscured from the left hand side.
	 * lineOffset specifies how much lines in pixels are skipped on the top.
	 * Return value contains state flags on wheter certain portions of the text were out of bound.
	 */
	public uint drawSingleLineText(Box pos, Text text, int offset = 0, int lineOffset = 0) {
		uint status;						//contains status flags
		bool needsIcon; 					//set to true if icon is inserted or doesn't exist.
		dchar prevChar;						//previous character, used for kerning

		const int textWidth = text.getWidth();	//Total with of the text
		if (textWidth < offset) return TextDrawStatus.TooMuchOffset;
		if (text.font.size < lineOffset) return TextDrawStatus.TooMuchLineOffset;
		int pX = text.frontTab;							//The current position, where the first letter will be drawn
		
		//Currently it was chosen to use a workpad to make things simpler
		//TODO: modify the algorithm to work without a workpad
		Bitmap8Bit workPad = new Bitmap8Bit(textWidth + 1, text.font.size * 2);
		///Inserts a color letter.
		void _insertColorLetter(Point pos, Bitmap8Bit bitmap, ubyte color, Box slice, int italics) pure nothrow {
			if(slice.width <= 0) return;
			if(slice.height <= 0) return;
			ubyte* psrc = bitmap.getPtr, pdest = workPad.getPtr;
			pdest += pos.x + workPad.width * pos.y;
			const int bmpWidth = bitmap.width;
			psrc += slice.left + bmpWidth * slice.top;
			//int length = slice.width;
			for(int iy ; iy < slice.height ; iy++) {
				const int italicsOffset = italics != 1 ? (slice.height - iy) / italics : 0;
				specblt.textBlitter(psrc, pdest + italicsOffset, slice.width, color);
				psrc += bmpWidth;
				pdest += workPad.width;
			}
		}
		///Copies a bitmap to the canvas using 0th index transparency.
		void _bitBLT(Point target, Bitmap8Bit source) pure nothrow {
			ubyte* src = source.getPtr;
			ubyte* dest = workPad.getPtr + (workPad.width * target.y) + target.x;
			for (int y ; y < source.height ; y++){
				compose.blitter(src, dest, source.width);
				src += source.width;
				dest += workPad.width;
			}
		}
		void _drawUnderlineSegment(uint style, int vOffset, int from, int to, ubyte color) pure {
			switch (style & FormattingFlags.ulLineStyle) {
			case FormattingFlags.underlineDotted:
				for (int x = from ; x <= to ; x++) {
					workPad.writePixel(x, vOffset, dottedLine[x & 1] & color);
				}
				break;
			case FormattingFlags.underlineStripes:
				for (int x = from ; x <= to ; x++) {
					workPad.writePixel(x, vOffset, stripesLine[x & 7] & color);
				}
				break;
			default:
				/* for (int i = (style & FormattingFlags.ulLineMultiplier) ; i >= 0 ; i--){
					if (vOffset + ((i>>7) * 2) > workPad.height) continue; */
				for (int x = from ; x <= to ; x++) {
					workPad.writePixel(x, vOffset/*  + ((i>>7) * 2) */, color);
				}
				/* } */
				break;
			}	
		}
		void _drawOtherLines(uint style, int vOffset, int from, int to, ubyte color) pure {
			if (style & FormattingFlags.strikeThrough) {
				for (int x = from ; x <= to ; x++) {
					workPad.writePixel(x, vOffset / 2, color);
				}
			}
			if (style & FormattingFlags.overline) {
				for (int x = from ; x <= to ; x++) {
					workPad.writePixel(x, 0, color);
				}
			}
		}
		//const int targetX = textWidth - offset > pos.width ? pos.right : pos.left + textWidth;
		Text currTextChunk = text;
		int currCharPos;// = text.offsetAmount(offset);
		if (currCharPos == 0 && currTextChunk.icon && offset < currTextChunk.icon.width + currTextChunk.iconOffsetX)
			needsIcon = true;
		//pX += currTextChunk.frontTab - offset > 0 ? currTextChunk.frontTab - offset : 0;
		/+int firstCharOffset = offset;// - text.getWidth(0, currCharPos);

		if (currCharPos > 0)
			firstCharOffset -= text.getWidth(0, currCharPos);+/
		
		while (pX < textWidth) {	//Per character/symbol drawing
			if(needsIcon) {
				//if there's enough space for the icon, then draw it
				pX += currTextChunk.iconOffsetX >= 0 ? currTextChunk.iconOffsetX : 0;
				//if(pX + currTextChunk.icon.width < targetX) {
				//const int targetHeight = pos.height > currTextChunk.icon.height - lineOffset ? currTextChunk.icon.height : pos.height;
				_bitBLT(Point(pX, currTextChunk.iconOffsetY), currTextChunk.icon);
				pX += text.iconSpacing;
				needsIcon = false;
				//} else return status | TextDrawStatus.RHSOutOfBound;
			} else {
				//check if there's any characters left in the current text chunk, if not step onto the next one if any, if not then return
				if(currCharPos >= currTextChunk.text.length) {
					if(currTextChunk.next) currTextChunk = currTextChunk.next;
					else return status;
					if(currTextChunk.icon) needsIcon = true;
					else needsIcon = false;
					currCharPos = 0;
					pX += currTextChunk.frontTab;
				} else {
					//if there's enough space for the next character, then draw it
					const dchar chr = currTextChunk.text[currCharPos];
					Font.Char chrInfo = text.font.chars(chr);
					//check if the character exists in the fontset, if not, then substitute it and set flag for missing character
					if(chrInfo.id == 0xFFFD && chr != 0xFFFD) status |= TextDrawStatus.CharacterNotFound;
					/* Box letterSrc = Box(chrInfo.x, chrInfo.y, chrInfo.x + chrInfo.width, chrInfo.y + 
							chrInfo.height); */
					Box letterSrc = Box.bySize(chrInfo.x, chrInfo.y, chrInfo.width, chrInfo.height);
					Point chrPos = Point (pX + chrInfo.xoffset, chrInfo.yoffset);
					_insertColorLetter(chrPos, currTextChunk.font.pages[chrInfo.page], currTextChunk.formatting.color, letterSrc, 
							currTextChunk.formatting.getItalicsAm);
					//draw underline if needed
					if ((currTextChunk.formatting.formatFlags & FormattingFlags.underline) && 
							!((currTextChunk.formatting.formatFlags & FormattingFlags.underlinePerWord) && isWhiteSpaceMB(chr)))
						_drawUnderlineSegment(currTextChunk.formatting.formatFlags, currTextChunk.formatting.font.size, pX, 
								pX + chrInfo.xadvance, currTextChunk.formatting.color);
					_drawOtherLines(currTextChunk.formatting.formatFlags, currTextChunk.formatting.font.size, pX, 
							pX + chrInfo.xadvance, currTextChunk.formatting.color);
					pX += chrInfo.xadvance + currTextChunk.formatting.getKerning(prevChar, chr);
					currCharPos++;
					prevChar = chr;
				}
			}
		}
		Point renderTarget = Point(pos.left,pos.top);
		//Offset text vertically in needed
		if (text.formatting.formatFlags & FormattingFlags.slHorizCenter) {
			renderTarget.y += (pos.height / 2) - (text.font.size);
		}
		//Offset text to the right if needed
		if (pos.width > textWidth) {
			switch (text.formatting.formatFlags & FormattingFlags.justifyMask) {
				case FormattingFlags.centerJustify:
					renderTarget.x += (pos.width - textWidth) / 2;
					break;
				case FormattingFlags.rightJustify:
					renderTarget.x += pos.width - textWidth;
					break;
				default: break;
			}
		}
		Box textSlice = Box(offset, lineOffset + text.formatting.offsetV, workPad.width - 1, workPad.height - 1);
		if (textSlice.width > pos.width) textSlice.width = pos.width;	//clamp down text width
		if (textSlice.height > pos.height) textSlice.height = pos.height;	//clamp down text height
		if (textSlice.width > 0 && textSlice.height > 0)
			bitBLT(renderTarget, workPad, textSlice);
		return status;
	}
	
}
/**
 * Font formatting flags. DEPRECATED!
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
	LHSOutOfBound			=	0x00_01,	///Left hand side out of bound
	RHSOutOfBound			=	0x00_02,	///Right hand side out of bound
	TPOutOfBound			=	0x00_04,	///Top portion out of bound
	BPOutOfBound			=	0x00_08,	///Bottom portion out of bound
	TooMuchOffset			=	0x1_00_00,
	TooMuchLineOffset		=	0x1_00_01,
}
