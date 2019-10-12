/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.text module
 */

module PixelPerfectEngine.concrete.text;

public import PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.bitmap;

//import std.xml;
import std.experimental.xml.sax;
import dom = std.experimental.xml.dom;
import std.experimental.xml.lexers;
import std.experimental.xml.parser;

/**
 * Implements a formatted text chunk, that can be serialized in XML form.
 * Has a linked list structure to easily link multiple chunks after each other.
 */
public class Text(BitmapType = Bitmap8Bit) {

	public dstring			text;			///The text to be displayed
	public CharacterFormattingInfo!BitmapType 	formatting;	///The formatting of this text block
	public Text				next;			///The next piece of formatted text block
	public int				frontTab;		///Space before the text chunk in pixels. Can be negative.
	public BitmapType		icon;			///Icon inserted in front of the text chunk.
	public byte				iconOffsetX;	///X offset of the icon if any
	public byte				iconOffsetY;	///Y offset of the icon if any
	/**
	 * Creates a unit of formatted text from the supplied data.
	 */
	public this(dstring text, CharacterFormattingInfo!BitmapType formatting, Text next = null, int frontTab = 0,
			BitmapType icon = null) @safe pure @nogc nothrow {
		this.text = text;
		this.formatting = formatting;
		this.next = next;
		this.frontTab = frontTab;
		this.icon = icon;
	}
	/**
	 * Parses formatted text from binary.
	 * Header is the first 4 bytes of the stream.
	 */
	public this(ubyte[] stream, Fontset!BitmapType[uint] fonts) @safe pure {
		import PixelPerfectEngine.system.etc : reinterpretCast, reinterpretGet;
		assert (stream.length > 4, "Bytestream too short!");
		const uint header = reinterpretGet!uint(stream[0..4]);
		stream = stream[4..$];
		switch (header & 0xF) {
			case TextType.UTF8:
				__ctor(TextType.UTF8, stream, fonts);
				break;
			case TextType.UTF32:
				__ctor(TextType.UTF32, stream, fonts);
				break;
			default:
				throw new Exception ("Binary character formatting stream error!");
		}
	}
	private this(TextType type, ubyte[] stream, Fontset!BitmapType[uint] fonts) @safe pure {
		import PixelPerfectEngine.system.etc : reinterpretCast, reinterpretGet;
		import std.utf : toUTF32;
		//uint header = reinterpretGet!uint(stream[0..4]);
		//stream = stream[4..$];
		if (stream[0] == FormattingCharacters.binaryCFI) {
			stream = stream[1..$];
			Fontset!BitmapType fontType = fonts[reinterpretGet!uint(stream[0..4])];
			const ubyte color = stream[7];
			const uint formatFlags = reinterpretGet!uint(stream[8..12]);
			const ushort paragraphSpace = reinterpretGet!ushort(stream[12..14]);
			const short rowHeight = reinterpretGet!short(stream[14..16]);
			formatting = new CharacterFormattingInfo!BitmapType(fontType, color, formatFlags, paragraphSpace, rowHeight);
			stream = stream[16..$];
		} else throw new Exception("Binary character formatting stream error!");
		if (stream[0] == FormattingCharacters.binaryLI) {
			stream = stream[1..$];
			const uint charStrmL = reinterpretGet!uint(stream[0..4]);
			if (charStrmL <= stream.length) {
				stream = stream[4..$];
				if(type == TextType.UTF8)
					text = toUTF32(reinterpretCast!char(stream[0..charStrmL]));
				else if(type == TextType.UTF32)
					text = reinterpretCast!dchar(stream[0..charStrmL]);
				stream = stream[charStrmL..$];
			} else throw new Exception("Binary character formatting stream error!");
			if (stream.length) {
				next = new Text!BitmapType(type, stream, fonts);
			}
		}
	}
	/**
	 * Returns the text as a 32bit string without the formatting.
	 */
	public dstring toDString() @safe pure nothrow {
		if (next)
			return text ~ next.toDString;
		else
			return text;
	}
}

/**
 * Parses text from XML/ETML
 *
 * See "ETML.md" for info.
 */
public class TextParser(BitmapType = Bitmap8Bit, StringType = string)
		/+if((typeof(BitmapType) is Bitmap8Bit || typeof(BitmapType) is Bitmap16Bit ||
		typeof(BitmapType) is Bitmap32Bit) && (typeof(StringType) is string || typeof(StringType) is dstring))+/ {
	private Text!BitmapType	 		current;	///Current element
	//private Text!BitmapType			_output;	///Root/output element
	private Text!BitmapType[] 		stack;		///Mostly to refer back to previous elements
	private CharacterFormattingInfo!BitmapType	currFrmt;///currently parsed formatting
	public CharacterFormattingInfo!BitmapType[]	chrFrmt;///All character format, that has been parsed so far
	private CharacterFormattingInfo!BitmapType	defFrmt;///Default character formatting. Must be set before parsing
	public Fontset!BitmapType[string]	fontsets;///Fontset name association table
	public BitmapType[string]		icons;		///Icon name association table
	private StringType				_input;		///The source XML/ETML document
	///Constructor with no arguments
	public this() @safe pure nothrow {
		reset();
	}
	///Creates a new instance with a select string input.
	public this(StringType _input) @safe pure nothrow {
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
	public Text!BitmapType output() @property @safe @nogc pure nothrow {
		return stack[0];
	}
	///Sets/gets the input
	public StringType input() @property @safe @nogc pure nothrow inout {
		return _input;
	}
	/**
	 * Parses the formatted text, then returns the output.
	 */
	public Text!BitmapType parse() @trusted {
		import std.conv : to;
		static struct XMLHandler(T) {
			private void finalizeFormatting() {
				if (current.text.length) {	//finalize text chunk if new format is used
					//check for duplicates in the previous ones, if there's none, then add the new one
					CharacterFormattingInfo!BitmapType f0;
					foreach (f; chrFrmt) {
						if (f == currFrmt) {
							f0 = f;
						}
					}
					if (f0) {
						current.formatting = f0;
					} else {
						current.formatting = currFrmt;
						chrFrmt ~= currFrmt;
					}

					Text!BitmapType nextChunk = new Text!BitmapType(null, current.formatting, null);
					current.next = nextChunk;
					current = nextChunk;
				}
			}
			//Create a new text instance for every new tag
			void onElementStart (ref T node) {
				import std.ascii : toLower;
				dom.Element!StringType node0 = cast(dom.Element!StringType)node;
				void parseLineStrikeFormatting() {
					bool updateFormat;
					if (node0.hasAttribute("style")) {
						switch (toLower(node0.getAttribute("style"))) {
							case "normal":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineStyle);
								//currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.
								break;
							case "dotted":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineStyle);
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineDotted;
								break;
							case "wavy":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineStyle);
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineWavy;
								break;
							case "wavySoft":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineStyle);
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineWavySoft;
								break;
							case "stripes":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineStyle);
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineStripes;
								break;
							default:
								break;
						}
						updateFormat = true;
					}
					if (node0.hasAttribute("lines")) {
						switch (toLower(node0.getAttribute("lines"))) {
							currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineMultiplier);
							/+case "single":
								currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulLineMultiplier);
								break;+/
							case "double":
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineDouble;
								break;
							case "triple":
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineTriple;
								break;
							case "quad", "quadruple":
								currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.underlineQuadruple;
								break;
							default:
								break;
						}
						updateFormat = true;
					}
					if (node0.hasAttribute("perWord")) {
						if (toLower(node0.getAttribute("perWord")) == "true") {
							currFrmt.formatFlags = currFrmt.formatFlags | FormattingFlags.ulPerWord;
						} else {
							currFrmt.formatFlags = currFrmt.formatFlags & (uint.max ^ FormattingFlags.ulPerWord);
						}
						updateFormat = true;
					}
					return updateFormat;
				}
				void parseFontFormatting() {
					bool updateFormat;
					if (node0.hasAttribute("type")) {
						currFrmt.fontType = fontsets[node0.getAttribute("type")];
						updateFormat = true;
					}
					if (node0.hasAttribute("color")) {
						static if(BitmapType.stringof == Bitmap32Bit.stringof) {
							//currFrmt.color =
						} else static if(BitmapType.stringof == Bitmap8Bit.stringof) {
							currFrmt.color = to!ubyte(node0.getAttribute("color"));
						} else static if(BitmapType.stringof == Bitmap16Bit.stringof) {
							currFrmt.color = to!ushort(node0.getAttribute("color"));
						}
						updateFormat = true;
					}
					return updateFormat;
				}
				switch (node0.localName) {
					case "p":
						if (node0.hasAttributes) {
							parseFontFormatting();
						}
						break;
					case "u":
						currFrmt.formatFlags |= FormattingFlags.underline;
						parseLineStrikeFormatting();
						break;
					case "o":
						currFrmt.formatFlags |= FormattingFlags.overline;
						parseLineStrikeFormatting();
						break;
					case "s":
						currFrmt.formatFlags |= FormattingFlags.strikeThrough;
						parseLineStrikeFormatting();
						break;
					case "font":
						parseFontFormatting();
						break;
					default:
						break;
				}
				//Start new chunk on beginning then push it to the stack
				Text!BitmapType nextChunk = new Text!BitmapType(null, current.formatting, null);
				current.next = nextChunk;
				current = nextChunk;
				stack ~= current;
			}
			//Finalize the current text instance
			void onElementEnd (ref T node) {
				//if (node.localName == "p") {//Insert new paragraph character at the end of a paragraph
					current ~= FormattingCharacters.newParagraph;
				//} else if (node.localName == "font") {

				//}
				finalizeFormatting();
				if(stack.length > 1)
					stack.length = stack.length - 1;
			}
			void onElementEmpty (ref T node) {

				dom.Element!StringType node0 = cast(dom.Element!StringType)node;
				switch (node0.localName) {
					case "br":
						current ~= FormattingCharacters.newLine;
						break;
					case "icon":
						if (node0.hasAttributes) {

							if (node0.hasAttribute("src")) {
								string a = to!string(node0.getAttribute("src"));
								if (current.text == "") {
									current.icon = icons[a];
								} else {
									Text!BitmapType nextChunk = new Text!BitmapType(null, current.formatting, null, 0, icons[a]);
									current.next = nextChunk;
									current = nextChunk;
									//stack[$-1] = current;
								}
							} else {
								throw new XMLTextParsingException("Missing src attribute from tag \"</ icon>\"!");
							}
							if (node0.hasAttribute("offsetX")) {
								current.iconOffsetX = to!byte(node0.getAttribute("offsetX"));
							}
							if (node0.hasAttribute("offsetY")) {
								current.iconOffsetY = to!byte(node0.getAttribute("offsetY"));
							}
						} else {
							throw new XMLTextParsingException("Missing src attribute from tag \"</ icon>\"!");
						}
						break;
					default:
						break;
				}
			}
        	void onProcessingInstruction (ref T node) {	}
			//
			void onText (ref T node) @safe {
				import std.utf : toUTF32;
				dom.Text!StringType text = cast(dom.Text!StringType)node;
				current.text = text.data;
			}
			void onDocument (ref T node) {	}
			void onComment (ref T node) {	}
		}
		/+auto xmlParser = xml.lexer.parser.cursor.saxParser!XMLHandler;
		xmlParser.setSource(_input);
		xmlParser.processDocument();+/
		return stack[0];
	}
}

static TextParser!(Bitmap8Bit) test;

unittest {
	TextParser!(Bitmap8Bit) parser;
	string exampleFormattedText = `
		<?xml encoding = "utf-8">
		<text>
			<p>
				This is an example formatted text for the PixelPerfectEngine's "concrete" module.
				</ br>
				This example contains <i>italic</ i>, <u>underline</ u>, <o>overline</ o>, and <s>strike out</ s> text.
				<icon src = "Jeffrey"/>
				<font color = "15">This text has the color 15.</ font>
			</ p>
		</ text>
	`
	parser = new TextParser!(Bitmap8Bit)(exampleFormattedText);
}
public class XMLTextParsingException : Exception {
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
		super(msg, file, line, nextInChain);
	}

	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line, nextInChain);
	}
}
