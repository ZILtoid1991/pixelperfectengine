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
	private ChrFormat				currFrmt;///currently parsed formatting
	public ChrFormat[]				chrFrmt;///All character format, that has been parsed so far
	public Fontset!BitmapType[]		fontStack;	///Fonttype formatting stack. Used for referring back to previous font types.
	public uint[]					colorStack;	///Contains a stack of color modifiers. If empty, it'll fall back to what the default formatting has.
	private ChrFormat				defFrmt;	///Default character formatting. Must be set before parsing
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
		if (stack[0].formatting is null) {
			stack[0].formatting = val;
		}
		defFrmt = val;
		return defFrmt;
	}
	///Gets the default formatting
	public CharacterFormattingInfo!BitmapType defaultFormatting() @property @safe pure nothrow @nogc {
		return defFrmt;
	}
	
	///Sets/gets the input
	public string input() @property @safe @nogc pure nothrow inout {
		return _input;
	}
	/**
	 * Parses the formatted text, then sets the output values.
	 */
	public void parse() @safe {
		auto parser = _input.lexer.parser.cursor.saxParser;
		parser.setSource(_input);

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
	/** 
	 * Begins a new text chain.
	 * Params:
	 *   attributes = Attributes are received here from textparser.
	 */
	protected void onTextElementStart(dstring[dstring] attributes) @safe {
		string textID = toUTF8(attributes["id"]);
		currTextBlock = new TextType(null, defFrmt);
		currFrmt = defFrmt;
		//Add first chunk to the output, so it can be recalled later on.
		output[textID] = currTextBlock;
	}
	protected void onPElementStart(dstring[dstring] attributes) @safe {
		if (currTextBlock.charLength) {
			currTextBlock.next = new TextType(null, currFrmt);
			currTextBlock = currTextBlock.next;
		}
		dstring paragraphSpaceStr = attributes.get("paragraphSpace", null);
		ushort paragraphSpace;
		if (paragraphSpaceStr.isInteger) {
			paragraphSpace = paragraphSpaceStr.to!ushort;
		}
		dstring rowHeightStr = attributes.get("rowHeight", null);
		short rowHeight;
		if (rowHeightStr.isInteger) {
			rowHeight = rowHeightStr.to!short;
		}
		currTextBlock.flags.newParagraph = true;
	}
	protected void onBrElement() @safe {
		currTextBlock.next = new TextType(null, currFrmt);
		currTextBlock = currTextBlock.next;
		currTextBlock.flags.newLine = true;
	}
	protected sizediff_t hasChrFormatting(ChrFormat frmt) @trusted {
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