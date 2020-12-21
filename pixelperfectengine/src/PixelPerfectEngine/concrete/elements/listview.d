module PixelPerfectEngine.concrete.elements.listview;

import PixelPerfectEngine.concrete.elements.base;
import PixelPerfectEngine.concrete.elements.scrollbar;

import PixelPerfectEngine.system.etc : clamp;

/**
 * Defines a single item in the listview.
 * Draws directly onto the canvas to avoit using multiple framebuffers.
 * Can be inherited from, and that's when non-alphabetical ordering can be implemented.
 */
public class ListViewItem {
	/**
	 * Defines a single field (cell) in a listview.
	 */
	public struct Field {
		private uint		flags;		///Stores various flags (constraints, etc.)
		public Text			text;		///Stores the text of this field if there's any.
		public ABitmap		bitmap;		///Custom bitmap, can be 32 bit if target enables it.
		static enum IS_EDITABLE = 1 << 0;///Set if field is text editable.
		static enum INTEGER_ONLY = 1 << 1;///Set if field only accepts integer numbers.
		static enum NUMERIC_ONLY = 1 << 2;///Set if field only accepts numeric values (integer or floating-point).
		static enum FORCE_FP = 1 << 3;	///Forces number to be displayed as floating point.
		static enum FORMAT_FLAGS = 0xF0;///Used to set and read formatting flags.
		///Used to set numerical formatting styles
		///NOTE: Not all formats support decimal types
		enum FormatFlags : uint {
			Context		= 0x00,			///Detected from input context
			HexH 		= 0x10,			///Hexanumeric indicated by letter `h` at the end
			HexX		= 0x20,			///Hexanumeric indicated by `0x` at the beginning
			OctH 		= 0x30,			///Octonumeric indicated by letter `o` at the end
			OctX		= 0x40,			///Octonumeric indicated by `0o` at the beginning
			BinH 		= 0x50,			///Binary indicated by letter `b` at the end
			BinX		= 0x60,			///Binary indicated by `0b` at the beginning
			Dec			= 0x70,			///Decimal formatting
		}
		/**
		 * Default constructor.
		 */
		this(Text text, ABitmap bitmap, FormatFlags frmtFlags, bool editable = false, bool numOnly = false, bool fp = false) 
				@nogc @safe pure nothrow {
			this.text = text;
			this.bitmap = bitmap;
			this.flags = frmtFlags;
			if (editable) flags |= IS_EDITABLE;
			if (numOnly) {
				flags |= NUMERIC_ONLY;
				if (fp) {
					flags |= FORCE_FP;
				} else {
					flags |= INTEGER_ONLY;
				}
			}
		}
		///Returns whether the field is editable.
		public @property bool editable() @nogc @safe pure nothrow const {
			return flags & IS_EDITABLE;
		}
		///Sets whether the field is editable. Returns the new value.
		public @property bool editable(bool val) @nogc @safe pure nothrow {
			if (val) flags |= IS_EDITABLE;
			else flags &= ~IS_EDITABLE;
			return flags & IS_EDITABLE;
		}
		///Returns whether the field is integer only.
		public @property bool integerOnly() @nogc @safe pure nothrow const {
			return flags & INTEGER_ONLY;
		}
		///Sets whether the field is integer only. Returns the new value.
		public @property bool integerOnly(bool val) @nogc @safe pure nothrow {
			if (val) flags |= INTEGER_ONLY;
			else flags &= ~INTEGER_ONLY;
			return flags & INTEGER_ONLY;
		}
		///Returns whether the field is numeric only.
		public @property bool numericOnly() @nogc @safe pure nothrow const {
			return flags & NUMERIC_ONLY;
		}
		///Sets whether the field is numeric only. Returns the new value.
		public @property bool numericOnly(bool val) @nogc @safe pure nothrow {
			if (val) flags |= NUMERIC_ONLY;
			else flags &= ~NUMERIC_ONLY;
			return flags & NUMERIC_ONLY;
		}
		///Returns whether the field forces floating point.
		public @property bool forceFP() @nogc @safe pure nothrow const {
			return flags & FORCE_FP;
		}
		///Sets whether the field forces floating point. Returns the new value.
		public @property bool forceFP(bool val) @nogc @safe pure nothrow {
			if (val) flags |= FORCE_FP;
			else flags &= ~FORCE_FP;
			return flags & FORCE_FP;
		}
		///Returns the field's format flags.
		public @property FormatFlags formatFlags() @nogc @safe pure nothrow const {
			return cast(FormatFlags)flags & FORMAT_FLAGS;
		}
		///Sets whether the field is editable. Returns the new value.
		public @property FormatFlags formatFlags(FormatFlags val) @nogc @safe pure nothrow {
			flags |= val;
			return cast(FormatFlags)flags & FORMAT_FLAGS;
		}
	}
	/**
	 * Stores the list of items to be displayed.
	 */
	public Field[]		fields;
	///Height of this item.
	protected int		height;
	/**
	 * Creates a list view item from texts.
	 */
	this (int height, Text[] fields) @nogc @safe pure nothrow {
		this.height = height;
		foreach (Field key; fields) {
			this.field = Field(key, null, Field.FormatFlags.Context);
		}
	}
	/**
	 * Creates a ListViewItem from fields directly.
	 */
	this (int height, Field[] fields) @nogc @safe pure nothrow {
		this.height = height;
		this.fields = fields;
	}
	/**
	 * Accesses fields like an array.
	 */
	public ref Field opIndex(size_t index) @nogc @safe pure nothrow {
		return fields[index];
	}
	/**
	 * Accesses fields like an array.
	 */
	public Field opIndexAssign(Field value, size_t index) @nogc @safe pure nothrow {
		fields[index] = value;
		return value;
	}
	///Returns the amount of fields in this item.
	public size_t length() @nogc @safe pure nothrow {
		fields.length;
	}
	/**
	 * Draws the ListViewItem. Draw parameters are supplied via a nested class found in ListView.
	 */
	public void draw(ListView parent) {
		for (int i = offsetC ; i <= targetC ; i++) {

		}
	}
}
/**
 * Defines the header of a ListView.
 * Extended from a ListViewItem.
 */
public class ListViewHeader : ListViewItem {
	public int[]				columnWidths;	///Width of each columns
	///Default CTOR
	this (int height, int[] columnWidths, Text[] fields) @nogc @safe pure nothrow {
		assert (_columnWidths.length == fields.length, "Lenght mismatch between the two arrays!");
		this.columnWidths = columnWidths;
		super(height, fields);
	}
	/**
	 * Draws the header. Draw parameters are supplied via a nested class found in ListView.
	 */
	public override void draw(ListView parent) {
		for (int i = parent.drawParams.offsetC ; i <= parent.drawParams.targetC ; i++) {

		}
	}
}
/**
 * Implements a basic ListView 
 */
public class ListView : WindowElement, ElementContainer {
	///Supplies draw parameters to the items
	public class DrawParameters {
		///StyleSheet that is being used currently
		StyleSheet 				ss;
		///Contains the reference to the header's columnWidth attribute
		int[]					columnWidths;
		///The first column to be drawn
		const int				offsetC;
		///The last column to be drawn
		const int				targetC;
		///Offset in pixels for the first column
		const int				offsetP;
		///Last column offset
		const int				targetP;
		///Offset of the first row. Should be set to zero after the first row has been drawn.
		int						offsetFR;
		///The prelimiter where the item should be drawn.
		Box						target;
		///CTOR
		this (StyleSheet ss, int[] columnWidths, const int offsetC, const int targetC, const int offsetP, const int targetP,
				int offsetFR) @safe @nogc pure nothrow {
			this.ss = ss;
			this.columnWidths = columnWidths;
			this.offsetC = offsetC;
			this.targetC = targetC;
			this.offsetP = offsetP;
			this.targetP = targetP;
			this.offsetFR = offsetFR;
		}
	}
	protected HorizScrollBar	horizSlider;	///Horizontal scroll bar.
	protected VertScrollBar		vertSlider;		///Vertical scroll bar.
	///The header of the ListView. 
	///Accessed in a safe manner to ensure it's being updated on the output raster.
	protected ListViewHeader	_header;
	///Entries in the ListView.
	///Accessed in a safe manner to ensure it's being updated on the output raster.
	protected ListViewItem[]	entries;
	protected int				totalHeight;	///Total height of the scrollable field.
	///Holds shared draw parameters that are used when the element is being drawn.
	///Should be set to null otherwise.
	public DrawParameters		drawParams;
	/**
	 * Accesses data entries in a safe manner.
	 */
	public ref ListViewItem opIndex(size_t index) {
		return entries[index];
	}
	
	override public void draw() {
		{	///Calculate first column stuff
			int offsetP = horizSlider.value();
			int offsetC;
			for (; _header.columnWidths[OffsetC] < offsetP ; offsetC++) {
				offsetP -= _header.columnWidths[offsetC];
			}
			///Calculate last column number
			int targetC;
			int targetP = horizSlider.value() + position.width;
			for (; _header.columnWidths[targetC] < targetP ; targetC++) {
				targetP -= _header.columnWidths[targetC];
			}
			targetP = _header.columnWidths[targetC] - targetP;
			drawParams = new DrawParameters(getStyleSheet, _header.columnWidths, offsetC, targetC, offsetP, targetP, 0);
		}
	}
	/**
	 * Returns the absolute position of the element.
	 */
	public Box getAbsolutePosition(WindowElement sender) {
		return parent.getAbsolutePosition(sender);
	}
	/**
	 * Gives focus to the element if applicable
	 */
	public void requestFocus(WindowElement sender) {
		
	}
	/**
	 * Sets the cursor to the given type on request.
	 */
	public void requestCursor(CursorType type) {

	}
	///Draws a line.
	public void drawLine(Point from, Point to, ubyte color) @trusted pure {
		parent.drawLine(from, to, color);
	}
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted pure {
		parent.drawLinePattern(from, to, pattern);
	}
	///Draws an empty rectangle.
	public void drawBox(Box target, ubyte color) @trusted pure {
		parent.drawBox(target, color);
	}
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Box target, ubyte[] pattern) @trusted pure {
		parent.drawBoxPattern(target, pattern);
	}
	///Draws a filled rectangle with a specified color.
	public void drawFilledBox(Box target, ubyte color) @trusted pure {
		parent.drawFilledBox(target, color);
	}
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted pure {
		parent.bitBLT(target, source);
	}
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Box slice) @trusted pure {
		parent.bitBLT(target, source, slice);
	}
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Box target, ABitmap pattern) @trusted pure {
		parent.bitBLTPattern(target, pattern);
	}
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Box target, ABitmap pattern) @trusted pure {
		parent.xorBitBLT(target, pattern);
	}
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Box target, ubyte color) @trusted pure {
		parent.xorBitBLT(target, color);
	}
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted pure {
		parent.fill(target, color, background);
	}
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Box target, Text text, Point offset) @trusted pure {
		parent.drawTextSL(target, text, offset);
	}
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Box target, Text text, Point offset) @trusted pure {
		parent.drawTextML(target, text, offset);
	}
	///Clears the area within the target
	public void clearArea(Box target) @trusted pure {
		parent.clearArea(target);
	}
}