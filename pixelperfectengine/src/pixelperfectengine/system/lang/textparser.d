module pixelperfectengine.system.lang.textparser;

public import pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.bitmap;

public import pixelperfectengine.graphics.text;
public import pixelperfectengine.system.exc;

import xml = undead.xml;
import std.utf : toUTF32, toUTF8;
import std.conv : to;
import std.algorithm : countUntil;

/**
 * Parses text from XML/ETML
 *
 * See "ETML.md" for info.
 *
 * Constraints:
 * * Due to the poor documentation of the replacement XML libraries, I have to use Phobos's own and outdated library.
 * * <text> chunks are mandatory with ID.
 * * Certain functions may not be fully implemented.
 */
/+
public class TextParserTempl(BitmapType = Bitmap8Bit)
		 {
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
	public CharacterFormattingInfo!BitmapType defaultFormatting() @property @safe pure nothrow @nogc {
		return defFrmt;
	}
	///Returns the root/output element
	
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
}+/
//alias TextParser = TextParserTempl!Bitmap8Bit;
public class XMLTextParsingException : PPEException {
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
			{
		super(msg, file, line, nextInChain);
	}

	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line, nextInChain);
	}
}