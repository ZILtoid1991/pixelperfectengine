/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.fontsets module
 */

module PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.system.exc;
import bmfont;
import dimage.base;
import dimage.tga;
import dimage.png;
public import PixelPerfectEngine.system.binarySearchTree;
static import std.stdio;
/**
 * Stores the letters and all the data associated with the font, also has functions related to text lenght and line formatting. Supports variable letter width.
 * TODO: Build fast kerning table through the use of binary search trees.
 * TODO: Add ability to load from dpk files through the use of vfiles.
 */
public class Fontset(T)
		if(T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof || T.stringof == Bitmap32Bit.stringof){
	public Font 						fontinfo;	///BMFont information on drawing the letters (might be removed later on)
	BinarySearchTree!(dchar, Font.Char)	chars;		///Contains character information in a fast lookup form
	public T[] 							pages;		///Character pages
	private string 						name;
	private int							size;
	///Empty constructor, primarily for testing purposes
	public this () {}
	/**
	 * Loads a fontset from disk.
	 */
	public this (std.stdio.File file, string basepath = "") {
		import std.path : extension;
		ubyte[] buffer;
		buffer.length = cast(size_t)file.size;
		file.rawRead(buffer);
		fontinfo = parseFnt(buffer);
		foreach(ch; fontinfo.chars){
			chars[ch.id] = ch;
		}
		size = fontinfo.info.fontSize;
		name = fontinfo.info.fontName;
		foreach (path; fontinfo.pages) {
			std.stdio.File pageload = std.stdio.File(basepath ~ path);
			switch (extension(path)) {
				case ".tga", ".TGA":
					TGA fontPage = TGA.load(pageload);
					if(!fontPage.getHeader.topOrigin){
						fontPage.flipVertical;
					}
					static if (T.stringof == Bitmap8Bit.stringof) {
						if(fontPage.getBitdepth != 8)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap8Bit(fontPage.getImageData, fontPage.width, fontPage.height);
					} else static if (T.stringof == Bitmap16Bit.stringof) {
						if(fontPage.getBitdepth != 16)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap16Bit(fontPage.getImageData, fontPage.width, fontPage.height);
					} else static if (T.stringof == Bitmap32Bit.stringof) {
						if(fontPage.getBitdepth != 32)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap32Bit(fontPage.getImageData, fontPage.width, fontPage.height);
					}
					break;
				case ".png", ".PNG":
					PNG fontPage = PNG.load(pageload);
					static if(T.stringof == Bitmap8Bit.stringof) {
						if(fontPage.getBitdepth != 8)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap8Bit(fontPage.getImageData, fontPage.width, fontPage.height);
					} else static if(T.stringof == Bitmap32Bit.stringof) {
						if(fontPage.getBitdepth != 32)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap32Bit(fontPage.getImageData, fontPage.width, fontPage.height);
					}
					break;
				default:
					throw new Exception("Unsupported file format!");
			}
		}
	}
	///Returns the name of the font
	public string getName(){
		return name;
	}
	///Returns the height of the font.
	public int getSize(){
		return size;
	}
	///Returns the width of the text.
	public int getTextLength(dstring text){
		int length;
		foreach(c; text){
			length += chars[c].xadvance;
		}

		return length;
	}
	/**
	* Breaks the input text into multiple lines according to the parameters.
	*/
	public dstring[] breakTextIntoMultipleLines(dstring input, int maxWidth, bool ignoreNewLineChars = false){
		dstring[] output;
		dstring currentWord, currentLine;
		int currentWordLength, currentLineLength;

		foreach(character; input){
			currentWordLength += chars[character].xadvance;
			if(!ignoreNewLineChars && (character == FormattingCharacters.newLine || character == FormattingCharacters.carriageReturn)){
				//initialize new line on symbols indicating new lines
				if(currentWordLength + currentLineLength <= maxWidth){
					currentLine ~= currentWord;
					output ~= currentLine;
				}else{
					output ~= currentLine;
					output ~= currentWord;
				}
				currentLine.length = 0;
				currentLineLength = 0;
				currentWord.length = 0;
				currentWordLength = 0;
			}else if(character == FormattingCharacters.space){
				//add new word to the current line if it has enough space, otherwise break the line and initialize next one
				if(currentWordLength + currentLineLength <= maxWidth){
					currentLineLength += currentWordLength;
					currentLine ~= currentWord ~ ' ';
				}else{
					output ~= currentLine;
				}
			}else{
				if(currentWordLength > maxWidth){	//Flush current word if it will be too long for a single line
					output ~= currentWord;
					currentLine.length = 0;
					currentWordLength = 0;
				}
				currentWord ~= character;

			}
		}

		return output;
	}
}
/**
 * Specifies formatting flags.
 * They usually can be mixed with others, see documentation for further info.
 */
public enum FormattingFlags : uint {
	reset				=	0b0000_0000_0000_0000_0000_0000_0000_0000,
	//Mask used for detecting complex formatting flags
	justifyMask			=	0b0000_0000_0000_0000_0000_0000_0000_1111,
	ulMask				=	0b0000_0000_0000_0000_0000_0000_0111_0000,
	ulLineMultiplier	=	0b0000_0000_0000_0000_0000_0001_1000_0000,
	ulLineStyle			=	0b0000_0000_0000_0000_0000_1110_0000_0000,
	forceItalicsMask	=	0b0000_0000_0000_0000_1100_0000_0000_0000,

	leftJustify			=	0b0000_0000_0000_0000_0000_0000_0000_0001,
	rightJustify		=	0b0000_0000_0000_0000_0000_0000_0000_0010,
	centerJustify		=	0b0000_0000_0000_0000_0000_0000_0000_0011,
	fillEntireLine		=	0b0000_0000_0000_0000_0000_0000_0000_1000,

	underline			=	0b0000_0000_0000_0000_0000_0000_0001_0000,
	underlinePerWord	=	0b0000_0000_0000_0000_0000_0000_0010_0000,

	underlineDouble		=	0b0000_0000_0000_0000_0000_0000_1000_0000,
	underlineTriple		=	0b0000_0000_0000_0000_0000_0001_0000_0000,
	underlineQuadruple	=	0b0000_0000_0000_0000_0000_0001_1000_0000,

	underlineDotted		=	0b0000_0000_0000_0000_0000_0010_0000_0000,
	underlineWavy		=	0b0000_0000_0000_0000_0000_0100_0000_0000,
	underlineWavySoft	=	0b0000_0000_0000_0000_0000_0110_0000_0000,
	underlineStripes	=	0b0000_0000_0000_0000_0000_1000_0000_0000,

	overLine			=	0b0000_0000_0000_0000_0001_0000_0000_0000,
	strikeThrough		=	0b0000_0000_0000_0000_0010_0000_0000_0000,
	//Forced italic fonts. The upper portions of the letters get shifted to the right by a certain amount set by the flags.
	//If all clear, then the text will be displayed normally from its bitmap form.
	forceItalics1per4	=	0b0000_0000_0000_0000_0100_0000_0000_0000,
	forceItalics1per3	=	0b0000_0000_0000_0000_1000_0000_0000_0000,
	forceItalics1per2	=	0b0000_0000_0000_0000_1100_0000_0000_0000,
}
/**
 * Stores character formatting info.
 */
public class CharacterFormattingInfo(T) {
	public Fontset!T		fontType;		///The type of the font
	static if(T.stringof == Bitmap8Bit.stringof)
		public ubyte			color;		///The displayed color
	else static if(T.stringof == Bitmap16Bit.stringof)
		public ushort			color;		///The displayed color
	else static if(T.stringof == Bitmap32Bit.stringof)
		public Color			color;		///The displayed color
	public uint				formatFlags;	///Styleflags to be set for different purposes (eg, orientation, understrike style)
	public ushort			paragraphSpace;	///The space between paragraphs in pixels
	public short			rowHeight;		///Modifies the space between rows of text within a single formatting unit
	static if(T.stringof == Bitmap8Bit.stringof) {
		///Constructs a CFI from the supplied data.
		public this(Fontset!T fontType, ubyte color, uint formatFlags, ushort paragraphSpace, short rowHeight) {
			this.fontType = fontType;
			this.color = color;
			this.formatFlags = formatFlags;
			this.paragraphSpace = paragraphSpace;
			this.rowHeight = rowHeight;
		}
	}
	///Copy constructor
	public this(CharacterFormattingInfo!T source) {
		this.fontType = source.fontType;
		this.color = source.color;
		this.formatFlags = source.formatFlags;
		this.paragraphSpace = source.paragraphSpace;
		this.rowHeight = source.rowHeight;
	}
	/**
	 * Checks if two instances hold the same character formatting information.
	 */
	public bool opEquals(CharacterFormattingInfo!T rhs) @trusted {
		return this.color == rhs.color && this.fontType == rhs.fontType && this.formatFlags == rhs.formatFlags &&
				this.paragraphSpace == rhs.paragraphSpace && this.rowHeight == rhs.rowHeight;
	}
	/**
	 * Legacy override.
	 */
	public override bool opEquals(Object o) {
		return super.opEquals(o);
	}
}
///Defines formatting characters.
///DC1 is repurposed to initialize binary embedded CharacterFormattingInfo.
///DC2 is repurposed to initialize length of formatted text blocks.
public enum FormattingCharacters : dchar{
	horizontalTab	=	0x09,
	newLine			=	0x0A,
	newParagraph	=	0x0B,
	carriageReturn	=	0x0D,
	binaryDLE		=	0x10,		///
	binaryCFI		=	0x11,		///Use DC1 to initialize binary embedded CFI
	binaryLI		=	0x12,		///Use DC2 to initialize binary length indicator of text blocks in bytes
	space			=	0x20,
}
///Defines what kind of encoding the text use
public enum TextType : ubyte {
	ASCII		=	1,
	UTF8		=	2,
	UTF16		=	3,
	UTF32		=	4,
}
