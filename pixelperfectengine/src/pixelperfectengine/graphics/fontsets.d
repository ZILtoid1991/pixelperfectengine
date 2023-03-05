/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.fontsets module
 */

module pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.bitmap;
public import pixelperfectengine.system.exc;
import bmfont;
import dimage;
//public import pixelperfectengine.system.binarySearchTree;
import collections.treemap;
import collections.sortedlist;
static import std.stdio;
/**
 * Stores the letters and all the data associated with the font, also has functions related to text lenght and line formatting. Supports variable letter width.
 * TODO: Add ability to load from dpk files through the use of vfiles.
 */
public class Fontset(T)
		if(T.stringof == Bitmap8Bit.stringof || T.stringof == Bitmap16Bit.stringof || T.stringof == Bitmap32Bit.stringof) {
	//If the kerning map will cost too much memory etc, this will be used instead.
	/+protected struct KerningInfo {
	align(2):
		dchar		a;
		dchar		b;
		short		amount;
	}+/
	//public Font 						fontinfo;	///BMFont information on drawing the letters (might be removed later on)
	alias CharMap = TreeMap!(dchar, Font.Char, true);
	alias KerningMapB = TreeMap!(dchar, short, true);
	alias KerningMap = TreeMap!(dchar, KerningMapB, true);
	protected CharMap					_chars;		///Contains character information in a fast lookup form
	protected KerningMap				_kerning;	///Contains kerning information
	public T[] 							pages;		///Character pages
	private Fontset!T[]					fallbacks;	///Provides fallbacks to other fontsets in case of missing characters
	private string 						name;		///Name of the font
	private int							_size;		///Height of the font
	///Empty constructor, primarily for testing purposes
	public this () {}
	/**
	 * Loads a fontset from disk.
	 */
	public this (std.stdio.File file, string basepath = "") {
		import std.path : extension;
		import bitleveld.reinterpret;
		
		ubyte[] buffer;
		buffer.length = cast(size_t)file.size;
		file.rawRead(buffer);
		Font fontinfo = parseFnt(buffer);
		foreach(ch; fontinfo.chars){
			_chars[ch.id] = ch;
		}
		foreach(krn; fontinfo.kernings){
			KerningMapB* mapB = _kerning.ptrOf(krn.first);
			if (mapB !is null) {
				(*mapB)[krn.second] = krn.amount;
			} else {
				KerningMapB newMap;
				newMap[krn.second] = krn.amount;
				_kerning[krn.first] = newMap;
			}
			//_kerning[krn.first][krn.second] = krn.amount;
		}
		_size = fontinfo.info.fontSize;
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
						pages ~= new Bitmap8Bit(fontPage.imageData.raw, fontPage.width, fontPage.height);
					} else static if (T.stringof == Bitmap16Bit.stringof) {
						if(fontPage.getBitdepth != 16)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap16Bit(reinterpretCast!ushort(fontPage.imageData.raw), fontPage.width, fontPage.height);
					} else static if (T.stringof == Bitmap32Bit.stringof) {
						if(fontPage.getBitdepth != 32)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap32Bit(reinterpretCast!Color(fontPage.imageData.raw), fontPage.width, fontPage.height);
					}
					break;
				case ".png", ".PNG":
					PNG fontPage = PNG.load(pageload);
					static if(T.stringof == Bitmap8Bit.stringof) {
						if(fontPage.getBitdepth != 8)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap8Bit(fontPage.imageData.raw, fontPage.width, fontPage.height);
					} else static if(T.stringof == Bitmap32Bit.stringof) {
						if(fontPage.getBitdepth != 32)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap32Bit(reinterpretCast!Color(fontPage.imageData.raw), fontPage.width, fontPage.height);
					}
					break;
				case ".bmp", ".BMP":
					BMP fontPage = BMP.load(pageload);
					static if(T.stringof == Bitmap8Bit.stringof) {
						if(fontPage.getBitdepth != 8)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap8Bit(fontPage.imageData.raw, fontPage.width, fontPage.height);
					} else static if(T.stringof == Bitmap32Bit.stringof) {
						if(fontPage.getBitdepth != 32)
							throw new BitmapFormatException("Bitdepth mismatch exception!");
						pages ~= new Bitmap32Bit(fontPage.imageData.raw, fontPage.width, fontPage.height);
					}
					break;
				default:
					throw new Exception("Unsupported file format!");
			}
		}
	}
	///Returns the name of the font
	public string getName() @nogc @safe nothrow pure @property const {
		return name;
	}
	///Returns the height of the font.
	///WILL BE DEPRECATED!
	public deprecated int getSize() @nogc @safe nothrow pure const {
		return _size;
	}
	///returns the height of the font.
	public int size() @nogc @safe nothrow pure @property const {
		return _size;
	}
	///Returns the width of the text in pixels.
	public int getTextLength(dstring text) @nogc @safe nothrow pure {
		int length;
		foreach(c; text){
			length += chars(c).xadvance;
		}
		return length;
	}
	/**
	 * Returns the character info if present, or a substitute from either a fallback font if it found in them or 
	 * the default substitute character (0xFFFD)
	 */
	public Font.Char chars(dchar i) @nogc @trusted nothrow pure {
		Font.Char result = _chars[i];
		if(result.id != dchar.init) return result;
		else {
			foreach(fntSt ; fallbacks) {
				result = fntSt.chars(i);
				if(result.id != dchar.init) return result;
			}
		}
		return _chars[0xFFFD];
	}
	/**
	 * Returns the kerning for the given character pair if there's any, or 0.
	 * Should be called through CharacterFormattingInfo, which can bypass it if formatting flag is enabled.
	 */
	public final short getKerning(const dchar first, const dchar second) @nogc @safe pure nothrow {
		return _kerning[first][second];
	}
	/**
	 * Breaks the input text into multiple lines according to the parameters.
	 */
	public dstring[] breakTextIntoMultipleLines(dstring input, int maxWidth, bool ignoreNewLineChars = false){
		dstring[] output;
		dstring currentWord, currentLine;
		int currentWordLength, currentLineLength;

		foreach(character; input){
			currentWordLength += chars(character).xadvance;
			if(!ignoreNewLineChars && currentWordLength && (character == FormattingCharacters.newLine || 
						character == FormattingCharacters.carriageReturn || character == FormattingCharacters.newParagraph)) {
				//initialize new line on symbols indicating new lines
				if(currentWordLength + currentLineLength <= maxWidth){
					currentLine ~= currentWord;
					output ~= currentLine;
				}else{
					output ~= currentLine;
					currentLine = currentWord;
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
	justifyMask			=	0b0000_0000_0000_0000_0000_0000_0000_0111,
	ulMask				=	0b0000_0000_0000_0000_0000_0000_0111_0000,
	ulLineMultiplier	=	0b0000_0000_0000_0000_0000_0001_1000_0000,
	ulLineStyle			=	0b0000_0000_0000_0000_0000_1110_0000_0000,
	forceItalicsMask	=	0b0000_0000_0000_0000_1100_0000_0000_0000,

	leftJustify			=	0b0000_0000_0000_0000_0000_0000_0000_0000,
	rightJustify		=	0b0000_0000_0000_0000_0000_0000_0000_0001,
	centerJustify		=	0b0000_0000_0000_0000_0000_0000_0000_0010,
	fillEntireLine		=	0b0000_0000_0000_0000_0000_0000_0000_0100,
	slHorizCenter		=	0b0000_0000_0000_0000_0000_0000_0000_1000,

	underline			=	0b0000_0000_0000_0000_0000_0000_0001_0000,
	underlinePerWord	=	0b0000_0000_0000_0000_0000_0000_0010_0000,

	underlineDouble		=	0b0000_0000_0000_0000_0000_0000_1000_0000,
	underlineTriple		=	0b0000_0000_0000_0000_0000_0001_0000_0000,
	underlineQuadruple	=	0b0000_0000_0000_0000_0000_0001_1000_0000,

	underlineDotted		=	0b0000_0000_0000_0000_0000_0010_0000_0000,
	underlineWavy		=	0b0000_0000_0000_0000_0000_0100_0000_0000,
	underlineWavySoft	=	0b0000_0000_0000_0000_0000_0110_0000_0000,
	underlineStripes	=	0b0000_0000_0000_0000_0000_1000_0000_0000,

	overline			=	0b0000_0000_0000_0000_0001_0000_0000_0000,
	strikeThrough		=	0b0000_0000_0000_0000_0010_0000_0000_0000,
	//Forced italic fonts. The upper portions of the letters get shifted to the right by a certain amount set by the flags.
	//If all clear, then the text will be displayed normally from its bitmap form.
	forceItalics1per4	=	0b0000_0000_0000_0000_0100_0000_0000_0000,
	forceItalics1per3	=	0b0000_0000_0000_0000_1000_0000_0000_0000,
	forceItalics1per2	=	0b0000_0000_0000_0000_1100_0000_0000_0000,

	disableKerning		=	0b0000_0000_0000_0001_0000_0000_0000_0000,
}
/**
 * Stores character formatting info.
 */
public class CharacterFormattingInfo(T) {
	public Fontset!T		font;		///The type of the font
	static if(T.stringof == Bitmap8Bit.stringof)
		public ubyte			color;		///The displayed color
	else static if(T.stringof == Bitmap16Bit.stringof)
		public ushort			color;		///The displayed color
	else static if(T.stringof == Bitmap32Bit.stringof)
		public Color			color;		///The displayed color
	public uint				formatFlags;	///Styleflags to be set for different purposes (eg, orientation, understrike style)
	public ushort			paragraphSpace;	///The space between paragraphs in pixels
	public short			rowHeight;		///Modifies the space between rows of text within a single formatting unit
	public ushort			offsetV;		///Upper-part offseting. The amount of lines which should be skipped (single line), or moved upwards (multi line)
	static if(T.stringof == Bitmap8Bit.stringof) {
		/**
		 * Creates character formatting from the supplied data.
		 * Params:
		 *   font = The fontset to be used for the formatting.
		 *   color = The color of the text.
		 *   formatFlags = Formatting flags, some combination of FormattingFlags ORed together.
		 *   paragraphSpace = Spaces between new paragraphs.
		 *   rowHeight = Total height of a row (fontsize + space between lines).
		 *   offsetV = Vertical offset on singleline texts.
		 */
		public this(Fontset!T font, ubyte color, uint formatFlags, ushort paragraphSpace, short rowHeight, ushort offsetV) 
				@safe {
			this.font = font;
			this.color = color;
			this.formatFlags = formatFlags;
			this.paragraphSpace = paragraphSpace;
			this.rowHeight = rowHeight;
			this.offsetV = offsetV;
		}
	}
	///Copy constructor
	public this(CharacterFormattingInfo!T source) @safe {
		this.font = source.font;
		this.color = source.color;
		this.formatFlags = source.formatFlags;
		this.paragraphSpace = source.paragraphSpace;
		this.rowHeight = source.rowHeight;
		this.offsetV = source.offsetV;
	}
	/**
	 * Returns the kerning amount, or zero if disabled by formatting.
	 */
	public short getKerning(const dchar first, const dchar second) @nogc @safe pure nothrow {
		if (!(formatFlags & FormattingFlags.disableKerning)) 
			return font.getKerning(first, second);
		else 
			return short.init;
	}
	/**
	 * Checks if two instances hold the same character formatting information.
	 */
	public bool opEquals(CharacterFormattingInfo!T rhs) {
		return this.color == rhs.color && this.font == rhs.font && this.formatFlags == rhs.formatFlags &&
				this.paragraphSpace == rhs.paragraphSpace && this.rowHeight == rhs.rowHeight;
	}
	alias opEquals = Object.opEquals;
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
