module pixelperfectengine.system.lang.textparser;

public import pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.bitmap;

public import pixelperfectengine.graphics.text;
public import pixelperfectengine.system.exc;
public import pixelperfectengine.system.etc : isInteger;

import newxml;
import std.utf : toUTF32, toUTF8;
import std.conv : to;
import std.algorithm : countUntil;
import std.exception : enforce;

/**
 * Parses text from XML/ETML
 *
 * See "ETML.md" for info.
 *
 * Constraints:
 * * <text> chunks are mandatory with ID.
 * * Certain functions may not be fully implemented as of now.
 */
public class TextParserTempl(BitmapType = Bitmap8Bit)
		if (is(BitmapType == Bitmap8Bit) || is(BitmapType == Bitmap16Bit) || is(BitmapType Bitmap32Bit)) {
	alias TextType = TextTempl!BitmapType;
	alias ChrFormat = CharacterFormattingInfo!BitmapType;
	public TextType[string]			output;		///All texts found within the ETML file
	private TextType				chunkRoot;
	private TextType				currTextBlock;
	//private ChrFormat				currFrmt;///currently parsed formatting
	public ChrFormat[]				chrFrmt;///All character format, that has been parsed so far
	public ChrFormat[]				frmtStack;	///Character formatting stack.
	//public Fontset!BitmapType[]		fontStack;	///Fonttype formatting stack. Used for referring back to previous font types.
	//public uint[]					colorStack;	///Contains a stack of color modifiers. If empty, it'll fall back to what the default formatting has.
	//private ChrFormat				defFrmt;	///Default character formatting. Must be set before parsing
	//alias defFrmt = chrFrmt[0];
	public Fontset!BitmapType[string]	fontsets;///Fontset name association table
	public BitmapType[string]		icons;		///Icon name association table
	public dstring[dstring]			customEntities;///Custom entities that are loaded during parsing.
	private dstring					_input;		///The source XML/ETML document
	
	///Creates a new instance with a select string input.
	public this(dstring _input) @safe pure nothrow {
		this._input = _input;
		
	}
	///Sets the default formatting
	public CharacterFormattingInfo!BitmapType defaultFormatting(CharacterFormattingInfo!BitmapType val) @property @safe
			pure nothrow {
		//defFrmt = val;
		chrFrmt = [val];
		return defFrmt;
	}
	///Gets the default formatting
	public CharacterFormattingInfo!BitmapType defaultFormatting() @property @safe pure nothrow @nogc {
		return defFrmt;
	}
	private final ChrFormat currFrmt() @property @safe pure nothrow @nogc {
		return frmtStack[$ - 1];
	}
	private final ref ChrFormat defFrmt() @property @safe pure nothrow @nogc {
		return chrFrmt[0];
	}
	///Sets/gets the input
	public dstring input() @property @safe @nogc pure nothrow inout {
		return _input;
	}
	/**
	 * Parses the formatted text, then sets the output values.
	 */
	public void parse() @safe {
		auto parser = _input.lexer.parser.cursor.saxParser;
		parser.setSource(_input);
		parser.onElementStart = &onElementStart;
		parser.onElementEnd = &onElementEnd;
	}
	protected void onText(dstring content) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(content, currFrmt);
			currTextBlock = currTextBlock.next;
		} else {
			currTextBlock.text = content;
		}
	}
	protected void onElementStart(dstring name, dstring[dstring] attr) @safe {
		switch (name) {
			case "text":
				onTextElementStart(attr);
				break;
			default:
				break;
		}
	}
	protected void onElementEmpty(dstring name, dstring[dstring] attr) @safe {
		switch (name) {
			case "br":
				onBrElement();
				break;
			default:
				break;
		}
	}
	protected void onElementEnd(dstring name) @safe {
		switch (name) {
			case "text":
				
				break;
			default:
				break;
		}
	}
	/** 
	 * Begins a new text chain, and flushes the font stack.
	 * Params:
	 *   attributes = Attributes are received here from textparser.
	 */
	protected void onTextElementStart(dstring[dstring] attributes) @safe {
		string textID = toUTF8(attributes["id"]);
		currTextBlock = new TextType(null, defFrmt);
		//currFrmt = defFrmt;
		frmtStack = [defFrmt];
		//Add first chunk to the output, so it can be recalled later on.
		output[textID] = currTextBlock;
	}
	protected void onPElementStart(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		ChrFormat newFrmt = new ChrFormat(currFrmt);
		dstring paragraphSpaceStr = attributes.get("paragraphSpace", null);
		if (paragraphSpaceStr.isInteger) {
			newFrmt.paragraphSpace = paragraphSpaceStr.to!ushort;
		}
		dstring rowHeightStr = attributes.get("rowHeight", null);
		if (rowHeightStr.isInteger) {
			newFrmt.rowHeight = rowHeightStr.to!short;
		}
		testFormatting(newFrmt);
		currTextBlock.formatting = currFrmt;
		currTextBlock.flags.newParagraph = true;
	}
	protected void onLineFormatElementStart(string Type)(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		ChrFormat newFrmt = new ChrFormat(currFrmt);
		static if (Type == "u") {
			dstring style = attributes.get("style", null);
			newFrmt.formatFlags |= FormattingFlags.underline;
			if (style.length)
				newFrmt.formatFlags &= ~FormattingFlags.ulLineMultiplier;
			switch (style) {
				case "double":
					newFrmt.formatFlags |= FormattingFlags.underlineDouble;
					break;
				case "triple":
					newFrmt.formatFlags |= FormattingFlags.underlineDouble;
					break;
				case "quad":
					newFrmt.formatFlags |= FormattingFlags.underlineDouble;
					break;
				default:
					break;
			}
			dstring lines = attributes.get("lines", null);
			if (lines.length)
				newFrmt.formatFlags &= ~FormattingFlags.ulLineStyle;
			switch (lines) {
				case "dotted":
					newFrmt.formatFlags |= FormattingFlags.underlineDouble;
					break;
				case "wavy":
					newFrmt.formatFlags |= FormattingFlags.underlineWavy;
					break;
				case "wavySoft":
					newFrmt.formatFlags |= FormattingFlags.underlineWavySoft;
					break;
				case "stripes":
					newFrmt.formatFlags |= FormattingFlags.underlineStripes;
					break;
				default:
					break;
			}
			dstring perWord = attributes.get("perWord", null);
			if (perWord == "true") {
				newFrmt.formatFlags |= FormattingFlags.underlinePerWord;
			} else {
				newFrmt.formatFlags &= ~FormattingFlags.underlinePerWord;
			}
		} else static if (Type == "s") {
			newFrmt.formatFlags |= FormattingFlags.strikeThrough;
		} else static if (Type == "o") {
			newFrmt.formatFlags |= FormattingFlags.overline;
		}
		testFormatting(newFrmt);
		currTextBlock.formatting = currFrmt;
	}
	protected void onIElementStart(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		ChrFormat newFrmt = new ChrFormat(currFrmt);
		dstring amount = attributes.get("amount", null);
		newFrmt.formatFlags &= ~FormattingFlags.forceItalicsMask;
		switch (amount) {
			case "1/3":
				newFrmt.formatFlags |= FormattingFlags.forceItalics1per3;
				break;
			case "1/2":
				newFrmt.formatFlags |= FormattingFlags.forceItalics1per2;
				break;
			default:	//case "1/4":
				newFrmt.formatFlags |= FormattingFlags.forceItalics1per4;
				break;
		}
		testFormatting(newFrmt);
		currTextBlock.formatting = currFrmt;
	}
	protected void onFontElementStart(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		ChrFormat newFrmt = new ChrFormat(currFrmt);
		string type = toUTF8(attributes.get("font", null));
		if (type.length) {
			newFrmt.font = fontsets[type];
		}
		string color = toUTF8(attributes.get("color", null));
		if (color.length) {
			static if (is(BitmapType == Bitmap8Bit)) {
				newFrmt.color = color.to!ubyte();
			} else static if (is(BitmapType == Bitmap16Bit)) {
				newFrmt.color = color.to!ushort();
			} else {

			}
		}
		testFormatting(newFrmt);
		currTextBlock.formatting = currFrmt;
	}
	protected void onFormatElementStart(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		ChrFormat newFrmt = new ChrFormat(currFrmt);
	}
	protected void onBrElement() @safe {
		currTextBlock.next = new TextType(null, currFrmt);
		currTextBlock = currTextBlock.next;
		currTextBlock.flags.newLine = true;
	}
	protected void onFrontTabElement(dstring[dstring] attributes) @safe {

	}
	protected void onImageElement(dstring[dstring] attributes) @safe {

	}
	protected final void removeTopFromFrmtStack() @safe {
		frmtStack = frmtStack[0..$-1];
		enforce!XMLTextParsingException(frmtStack.length >= 1, "Formatting stack is empty!");
	}
	protected final void testFormatting(ChrFormat frmt) @safe {
		sizediff_t frmtNum = hasChrFormatting(frmt);
		if (frmtNum == -1) {	///New formatting found, add this to overall formatting
			chrFrmt ~= frmt;
			frmtStack ~= frmt;
		} else {				///Already used formatting found, use that instead
			frmtStack ~= chrFrmt[frmtNum];
		}
	}
	protected final sizediff_t hasChrFormatting(ChrFormat frmt) @trusted {
		return countUntil(chrFrmt, frmt);
	}
}
alias TextParser = TextParserTempl!Bitmap8Bit;
public class XMLTextParsingException : PPEException {
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
			{
		super(msg, file, line, nextInChain);
	}

	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line, nextInChain);
	}
}