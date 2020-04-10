/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.text module
 */

module PixelPerfectEngine.graphics.text;

public import PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.bitmap;

import xml = std.xml;
import std.utf : toUTF32, toUTF8;
import std.conv : to;
import std.algorithm : countUntil;

/**
 * Implements a formatted text chunk, that can be serialized in XML form.
 * Has a linked list structure to easily link multiple chunks after each other.
 */
public class TextTempl(BitmapType = Bitmap8Bit) {

	public dstring			text;			///The text to be displayed
	public CharacterFormattingInfo!BitmapType 	formatting;	///The formatting of this text block
	public TextTempl!BitmapType	next;			///The next piece of formatted text block
	public int				frontTab;		///Space before the text chunk in pixels. Can be negative.
	public BitmapType		icon;			///Icon inserted in front of the text chunk.
	public byte				iconOffsetX;	///X offset of the icon if any
	public byte				iconOffsetY;	///Y offset of the icon if any
	public byte				iconSpacing;	///Spacing after the icon if any
	/**
	 * Creates a unit of formatted text from the supplied data.
	 */
	public this(dstring text, CharacterFormattingInfo!BitmapType formatting, TextTempl!BitmapType next = null, int frontTab = 0,
			BitmapType icon = null) @safe pure @nogc nothrow {
		this.text = text;
		this.formatting = formatting;
		this.next = next;
		this.frontTab = frontTab;
		this.icon = icon;
	}
	///Copy CTOR
	public this(TextTempl!BitmapType orig) @safe pure nothrow {
		this.text = orig.text.dup;
		this.formatting = orig.formatting;
		if(orig.next)
			this.next = new TextTempl!BitmapType(orig.next);
		this.frontTab = orig.frontTab;
		this.icon = orig.icon;
		this.iconOffsetX = orig.iconOffsetX;
		this.iconOffsetY = orig.iconOffsetY;
		this.iconSpacing = orig.iconSpacing;
	}
	/**
	 * Returns the text as a 32bit string without the formatting.
	 */
	public dstring toDString() @safe pure nothrow {
		if (next)
			return text ~ next.toDString();
		else
			return text;
	}
	/**
	 * Indexing to refer to child items.
	 * Returns null if the given element isn't available.
	 */
	public Text!BitmapType opIndex(size_t index) @safe pure nothrow {
		if (index) {
			if (next) {
				return next[index - 1];
			} else {
				return null;
			}
		} else {
			return this;
		}
	}
	/**
	 * Returns the character lenght.
	 */
	public @property size_t charLength() @safe pure nothrow @nogc const {
		if (next) return text.length + next.charLength;
		else return text.length;
	}
	/**
	 * Removes the character at the given position.
	 * Returns the removed character if within bound, or dchar.init if not.
	 */
	public dchar removeChar(size_t pos) @safe pure {
		import std.algorithm.mutation : remove;
		void _removeChar() @safe pure {
			if(pos == 0) {
				text = text[1..$];
			} else if(pos == text.length - 1) {
				text = text[0..($ - 1)];
			} else {
				text = text[0..pos] ~ text[(pos + 1)..$];
			}
		}
		if(pos < text.length) {
			const dchar result = text[pos];
			_removeChar();/+text = text.remove(pos);+/
			return result;
		} else if(next) {
			return next.removeChar(pos - text.length);
		} else return dchar.init;
	}
	/**
	 * Inserts a given character at the given position.
	 * Return the inserted character if within bound, or dchar.init if position points to a place where it
	 * cannot be inserted easily.
	 */
	public dchar insertChar(size_t pos, dchar c) @safe pure {
		import std.array : insertInPlace;
		if(pos <= text.length) {
			text.insertInPlace(pos, c);
			return c;
		} else if(next) {
			return next.insertChar(pos - text.length, c);
		} else return dchar.init;
	}
	/**
	 * Returns a character from the given position.
	 */
	public dchar getChar(size_t pos) @safe pure {
		if(pos < text.length) {
			return text[pos];
		} else if(next) {
			return next.getChar(pos - text.length);
		} else return dchar.init;
	}
	/**
	 * Returns the width of the text chain in pixels.
	 */
	public int getWidth() @safe pure nothrow {
		int localWidth;
		auto f = font;
		foreach (c; text) {
			localWidth += f.chars(c).xadvance;
		}
		if(icon) localWidth += icon.width + iconOffsetX + iconSpacing;
		if(next) return localWidth + next.getWidth();
		else return localWidth;
	}
	/**
	 * Returns the width of a slice of the text chain in pixels.
	 * Currently omits any existing embedded icons.
	 */
	public int getWidth(sizediff_t begin, sizediff_t end) @safe pure {
		if(end > text.length && next is null) 
			throw new Exception("Text boundary have been broken!");
		int localWidth;
		if(begin < text.length) {
			auto f = font;
			foreach (c; text[begin..end]) {
				localWidth += f.chars(c).xadvance;
			}
		}
		begin -= text.length;
		end -= text.length;
		if (begin < 0) begin = 0;
		if (next && end > 0) return localWidth + next.getWidth(begin, end);
		else return localWidth;
	}
	/**
	 * Returns the used font type
	 */
	public Fontset!BitmapType font() @safe @nogc pure nothrow {
		return formatting.fontType;
	}
}
alias Text = TextTempl!Bitmap8Bit;
/**
 * Parses text from XML/ETML
 *
 * See "ETML.md" for info.
 *
 * Constraints:
 * * Due to the poor documentation of the replacement XML libraries, I have to use Phobos's own and outdated library.
 * * <text> chunks are mandatory with ID.
 * * Currently line formatting (understrike, etc.) is not supported, and every line uses default formatting.
 */
public class TextParser(BitmapType = Bitmap8Bit)
		/+if((typeof(BitmapType) is Bitmap8Bit || typeof(BitmapType) is Bitmap16Bit ||
		typeof(BitmapType) is Bitmap32Bit) && (typeof(StringType) is string || typeof(StringType) is dstring))+/ {
	//private Text!BitmapType	 		current;	///Current element
	//private Text!BitmapType			_output;	///Root/output element
	//private Text!BitmapType[] 		stack;		///Mostly to refer back to previous elements
	public TextTempl!BitmapType[string]	output;		///All texts found within the ETML file
	private TextTempl!BitmapType chunkRoot;
	private TextTempl!BitmapType currTextBlock;
	private CharacterFormattingInfo!BitmapType	currFrmt;///currently parsed formatting
	public CharacterFormattingInfo!BitmapType[]	chrFrmt;///All character format, that has been parsed so far
	public Fontset!BitmapType[]		fontStack;	///Fonttype formatting stack. Used for referring back to previous font types.
	public uint[]					colorStack;
	private CharacterFormattingInfo!BitmapType	defFrmt;///Default character formatting. Must be set before parsing
	public Fontset!BitmapType[string]	fontsets;///Fontset name association table
	public BitmapType[string]		icons;		///Icon name association table
	private string					_input;		///The source XML/ETML document
	///Constructor with no arguments
	public this() @safe pure nothrow {
		reset();
	}
	///Creates a new instance with a select string input.
	public this(string _input) @safe pure nothrow {
		this._input = _input;
		__ctor();
	}
	///Resets the output, but keeps the public parameters.
	///Input must be set to default or to new target separately.
	public void reset() @safe pure nothrow {
		current = new Text!BitmapType("", null);
		//_output = current;
		stack ~= current;
	}
	///Sets the default formatting
	public CharacterFormattingInfo!BitmapType defaultFormatting(CharacterFormattingInfo!BitmapType val) @property @safe
			pure nothrow {
		if (stack[0].formatting is null) {
			stack[0].formatting = val;
		}
		defFrmt = val;
		return defFrmt;
	}
	///Gets the default formatting
	public CharacterFormattingInfo!BitmapType defaultFormatting()@property @safe pure nothrow @nogc {
		return defFrmt;
	}
	///Returns the root/output element
	/+public Text!BitmapType output() @property @safe @nogc pure nothrow {
		return stack[0];
	}+/
	///Sets/gets the input
	public string input() @property @safe @nogc pure nothrow inout {
		return _input;
	}
	/**
	 * Parses the formatted text, then returns the output.
	 */
	public void parse() @trusted {
		xml.check(_input);
		string currTextChunkID;
		currFrmt = new CharacterFormattingInfo!BitmapType(defFrmt);
		fontStack ~= currFrmt.fontType;
		colorStack ~= currFrmt.color;
		auto parser = new xml.DocumentParser(_input);
		parser.onStartTag["text"] = (xml.ElementParser parser) {
			currTextChunkID = parser.tag.attr["id"];
			chunkRoot = new TextTempl!BitmapType();
			currTextBlock = chunkRoot;
			
			output[currTextChunkID] = chunkRoot;
			parseRecursively(parser);
		};
		parser.parse;
	}
	//block for parsing
	private void onText(string s) {
		currTextBlock.text ~= toUTF32(s);
	}
	private void onEndTag_br(xml.Element e) {
		currTextBlock.text ~= FormattingCharacters.newLine;
	}
	private void onStartTag_p(xml.ElementParser parser) {
		currTextBlock.text ~= FormattingCharacters.newParagraph;
		if(parser.tag.attr.length) {
			currFrmt.paragraphSpace = parser.tag.attr.get("paragraphSpace", defFrmt.paragraphSpace);
			currFrmt.rowHeight = parser.tag.attr.get("rowHeight", defFrmt.paragraphSpace);
			createNextTextChunk();
		}
		parseRecursively (parser);
	}
	private void onStartTag_u(xml.ElementParser parser) {
		currFrmt.formatFlags |= FormattingFlags.underline;
		createNextTextChunk();
		parseRecursively (parser);
	}
	private void onStartTag_s(xml.ElementParser parser) {
		currFrmt.formatFlags |= FormattingFlags.strikeThrough;
		createNextTextChunk();
		parseRecursively (parser);
	}
	private void onStartTag_o(xml.ElementParser parser) {
		currFrmt.formatFlags |= FormattingFlags.overline;
		createNextTextChunk();
		parseRecursively (parser);
	}
	private void onStartTag_i(xml.ElementParser parser) {
		const string amount = parser.tag.attr.get("amount", "0");
		currFrmt.formatFlags &= !FormattingFlags.forceItalicsMask;
		switch(amount) {
			case "1/2":
				currFrmt.formatFlags |= FormattingFlags.forceItalics1per2;
				break;
			case "1/3":
				currFrmt.formatFlags |= FormattingFlags.forceItalics1per3;
				break;
			case "1/4":
				currFrmt.formatFlags |= FormattingFlags.forceItalics1per4;
				break;
			default:
				currFrmt.formatFlags |= defFrmt.formatFlags & FormattingFlags.forceItalicsMask;
				break;
		}
		createNextTextChunk();
		parseRecursively (parser);
	}
	private void onStartTag_font(xml.ElementParser parser) {
		const string fontName = parser.tag.attr.get("type", "");
		const uint color = to!uint(parser.tag.attr.get(color, colorStack[$-1]));
		Fontset!BitmapType fontType;
		if(fontType.length) {
			fontType = fontsets.get(fontName, null);
			if (fontType is null)
				throw new XMLTextParsingException("Unknown fonttype!");
		} else {
			fontType = fontStack[$-1];
		}
		fontStack ~= fontType;
		colorStack ~= color;
		currFrmt.color = cast(ubyte)color;
		currFrmt.fontType = fontType;
		createNextTextChunk();
		parseRecursively (parser);
	}
	private void onEndTag_u(xml.Element e) {
		currFrmt.formatFlags &= !FormattingFlags.underline;
		createNextTextChunk();
	}
	private void onEndTag_s(xml.Element e) {
		currFrmt.formatFlags &= !FormattingFlags.strikeThrough;
		createNextTextChunk();
	}
	private void onEndTag_o(xml.Element e) {
		currFrmt.formatFlags &= !FormattingFlags.overline;
		createNextTextChunk();
	}
	private void onEndTag_i(xml.Element e) {
		currFrmt.formatFlags &= !FormattingFlags.forceItalicsMask;
		createNextTextChunk();
	}
	private void onEndTag_font(xml.Element e) {
		currFrmt.color = cast(ubyte)colorStack[$-2];
		currFrmt.fontType = fontStack[$-2];
		colorStack.length--;
		fontStack.length--;
		createNextTextChunk();
	}
	private void onStartTag_frontTab(xml.ElementParser parser) {
		parseRecursively (parser);
	}
	private void onStartTag_image(xml.ElementParser parser) {
		parseRecursively (parser);
	}
	///Creates the next text chunk if needed, and also checks the formatting stack.
	///Called by the appropriate functions.
	///Also handles the character formatting stack
	private void createNextTextChunk() {
		if(currTextBlock.text.length || currTextBlock.icon !is null){
			currTextBlock = new TextTempl!BitmapType(null, null, currTextBlock);
			const ptrdiff_t frmtPos = countUntil(chrFrmt, currFrmt);
			if (frmtPos == -1){ 
				chrFrmt ~= new CharacterFormattingInfo(currFrmt);
				currTextBlock.formatting = chrFrmt[$-1];
			} else {
				currTextBlock.formatting = chrFrmt[frmtPos];
			}
		}
	}
	///Called for every instance when there might be additional tags to be parsed.
	private void parseRecursively(xml.ElementParser parser) {
		parser.onText = &onText;
		parser.onEndTag["br"] = &onEndTag_br;
		parser.onStartTag["p"] = &onStartTag_p;
		parser.parse;
	}
}

public class XMLTextParsingException : Exception {
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
		super(msg, file, line, nextInChain);
	}

	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line, nextInChain);
	}
}

unittest {
	TextParser!Bitmap8Bit test;

}