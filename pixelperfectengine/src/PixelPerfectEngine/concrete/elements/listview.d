module PixelPerfectEngine.concrete.elements.listview;

import PixelPerfectEngine.concrete.elements.base;
import PixelPerfectEngine.concrete.elements.scrollbar;

import PixelPerfectEngine.system.etc : clamp, min;

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
	public int			height;
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
		StyleSheet ss = parent.drawParams.ss;
		Box target = parent.drawParams.target;
		Box t = Box(target.left, target.top, target.left, target.bottom);
		Point offset = Point(parent.drawParams.offsetP, parent.drawParams.offsetFR);
		for (int i = parent.drawParams.offsetC ; i <= parent.drawParams.targetC ; i++) {
			t.right = min(t.left + parent.drawParams.columnWidths[i], target.right);
			parent.drawTextSL(t.pad(ss.drawParameters["ListViewColPadding"], ss.drawParameters["ListViewRowPadding"]), fields[i],
					offset);
			t.left = t.right;
			offset.x = 0;
		}
		parent.drawParams.target.relMove(0, height);
		parent.drawParams.offsetFR = 0;
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
		if (!height) return;
		StyleSheet ss = parent.drawParams.ss;
		Box target = parent.drawParams.target;
		Box t = Box(target.left, target.top, target.left, target.bottom);
		Point offset = Point(parent.drawParams.offsetP, 0);
		for (int i = parent.drawParams.offsetC ; i <= parent.drawParams.targetC ; i++) {
			t.right = min(t.left + parent.drawParams.columnWidths[i], target.right);
			if (!offset.x) {
				parent.drawLine(t.cornerUL, t.cornerLL, ss.getColor("windowascent"));
			}
			if (t.left + parent.drawParams.columnWidths[i] < target.right) {
				parent.drawLine(t.cornerUR, t.cornerLR, ss.getColor("windowdescent"));
			}
			with (parent) {
				drawLine(t.cornerUL, t.cornerUR, ss.getColor("windowascent"));
				drawLine(t.cornerLL, t.cornerLR, ss.getColor("windowdescent"));
				drawTextSL(t.pad(ss.drawParameters["ListViewColPadding"], ss.drawParameters["ListViewRowPadding"]), fields[i],
						offset);
			}
			t.left = t.right;
			offset.x = 0;
		}
		parent.drawParams.target.relMove(0, height);
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
		///Offset of the first row. Should be set to zero after the first row has been drawn.
		int						offsetFR;
		///The prelimiter where the item should be drawn.
		Box						target;
		///CTOR
		this (StyleSheet ss, int[] columnWidths, const int offsetC, const int targetC, const int offsetP, 
				int offsetFR) @safe @nogc pure nothrow {
			this.ss = ss;
			this.columnWidths = columnWidths;
			this.offsetC = offsetC;
			this.targetC = targetC;
			this.offsetP = offsetP;
			this.offsetFR = offsetFR;
		}
	}
	protected HorizScrollBar	horizSlider;	///Horizontal scroll bar.
	protected VertScrollBar		vertSlider;		///Vertical scroll bar.
	///The header of the ListView. 
	///Accessed in a safe manner to ensure it's being updated on the output raster.
	protected ListViewHeader	_header;
	///Entries in the ListView.
	///Accessed in a safe manner to ensure it's being updated on the output raster and that the number of columns match.
	protected ListViewItem[]	entries;
	protected int				selection;		///Selected item's number, or -1 if none selected.
	///Holds shared draw parameters that are used when the element is being drawn.
	///Should be set to null otherwise.
	public DrawParameters		drawParams;
	///Standard CTOR
	public this(ListViewHeader header, ListViewItem[] entries, string source, Box position) {
		_header = header;
		this.entries = entries;
		this.source = source;
		this.position = position;
		recalculateTotalSizes();
	}
	/**
	 * Accesses data entries in a safe manner.
	 */
	public ListViewItem opIndex(size_t index) @nogc @safe pure nothrow {
		return entries[index];
		/+scope(exit) {
			assert(entries[index].length == _header.length, "Column number mismatch error!");
		}+/
	}
	/**
	 * Accesses data entries in a safe manner.
	 */
	public ListViewItem opIndexAssign(ListViewItem value, size_t index) @safe pure {
		if (value.length == header.length) {
			if (entries.length == index) {
				entries ~= value;
			} else {
				entries[index] = value;
			}
		} else throw new Exception("Column number mismatch!");
		return value;
	}
	/**
	 * Allows to append a single element to the entry list.
	 */
	public ListViewItem opOpAssign(string op)(ListViewItem value) {
		static if (op == "~" || op == "+") {
			if (value.length == header.length) {
				entries ~= value;
			} else throw new Exception("Column number mismatch!");
		} else static assert (0, "Unsupported operator!");
		return this;
	}
	/**
	 * Allows to append multiple elements to the entry list.
	 */
	public ListViewItem opOpAssign(string op)(ListViewItem[] value) {
		static if (op == "~" || op == "+") {
			if (value.length == header.length) {
				entries ~= value;
			} else throw new Exception("Column number mismatch!");
		} else static assert (0, "Unsupported operator!");
		return this;
	}
	override public void draw() {
		StyleSheet ss = getStyleSheet;
		parent.clearArea(position);
		parent.drawBox(position, ss.getColor("windowascent"));
		Point upper = Point(0, position.top + _header.height);
		Point lower = Point(0, position.bottom);
		{	///Calculate first column stuff
			int offsetP, offsetC, targetC, targetP;
			if (horizSlider) { 
				offsetP = horizSlider.value();
				//int offsetC;
				for (; _header.columnWidths[OffsetC] < offsetP ; offsetC++) {
					offsetP -= _header.columnWidths[offsetC];
				}
				///Calculate last column number
				//int targetC;
				targetP = horizSlider.value() + position.width;
				for (; _header.columnWidths[targetC] < targetP ; targetC++) {
					targetP -= _header.columnWidths[targetC];
				}
				//targetP = _header.columnWidths[targetC] - targetP;
				lower.y -= horizSlider.getPosition().height;
			} else {
				targetC = cast(int)_header.columnWidths.length - 1;
			}
			drawParams = new DrawParameters(ss, _header.columnWidths, offsetC, targetC, offsetP, 0);
		}
		
		drawParams.target = Box(position.left, position.top, position.right, position.top + _header.height);
		
		if (vertSlider) {
			drawParams.target.right -= vertSlider.getPosition.width;

		}
		
		_header.draw(this);
		/+Point upper = Point(drawParams.columnWidths[drawParams.offsetC] + position.left, position.top + _header.height);
		Point lower = Point(upper.x, position.bottom);+/
		int firstRow, lastRow;
		if (vertSlider) {
			int pixelsTotal = vertSlider.value();
			for (; entries[firstRow].height < pixelsTotal ; firstRow++) {
				pixelsTotal -= entries[firstRow].height;
			}
			drawParams.offsetFR = entries[firstRow].height - pixelsTotal;
			pixelsTotal += position.height;
			pixelsTotal -= _header.height;
			if (horizSlider) pixelsTotal -= horizSlider.getPosition().height;
			lastRow = firstRow;
			for (; entries[lastRow].height < pixelsTotal ; lastRow++) {
				pixelsTotal -= entries[lastRow].height;
			}
		} else {
			lastRow = cast(int)entries.length - 1;
		}
		
		for (int i = firstRow ; i <= lastRow ; i++) {
			if (ss.getColor("ListViewHSep") && i != lastRow) {
				parent.drawLine(drawParams.target.cornerLL, drawParams.target.cornerLR, ss.getColor("ListViewHSep"));
			}
			if (selection == i) {
				parent.drawFilledBox(drawParams.target, ss.getColor("selection"));
			}
			entries[i].draw(this);	
		}

		if (ss.getColor("ListViewVSep")) {
			for (int i = drawParams.offsetC ; i <= drawParams.targetC ; i++) {
				upper.x = drawParams.columnWidths[i];
				lower.x = drawParams.columnWidths[i];
				parent.drawLine(upper, lower, ss.getColor("ListViewVSep"));
			}
		}
		horizSlider.draw;
		vertSlider.draw;

		drawParams = null;
	}
	/**
	 * Returns the number of the selected item.
	 */
	public @property int value() @nogc @safe pure nothrow const {
		return selection;
	}
	/**
	 * Sets the selected item and then does a redraw.
	 */
	public int value(int val) {
		selection = val;
		draw;
		return selection;
	}
	/**
	 * Sets a new header, also able to supply new entries.
	 */
	public void setHeader(ListViewHeader header, ListViewItem[] entries) {
		_header = header;
		foreach (ListViewItem key; entries) {
			assert(key.length == header.length);
		}
		this.entries = entries;
		refresh();
		draw();
	}
	/**
	 * Removes an item from the entries.
	 * Returns the removed entry.
	 */
	public ListViewItem removeEntry(size_t index) {
		import std.algorithm.mutation : remove;
		ListViewItem result = entries[index];
		entries = entries.remove(index);
		return result;
	}
	/**
	 * Refreshes the list view.
	 * Must be called every time when adding new items was finished.
	 */
	public void refresh() {
		selection = -1;
		recalculateTotalSizes;
	}
	/**
	 * Recalculates the total width and height of the list view's field, also generates scrollbars if needed.
	 */
	protected void recalculateTotalSizes() {
		int totalWidth, totalHeight;
		foreach (i ; _header.columnWidths) {
			totalWidth += i;
		}
		foreach (ListViewItem key; entries) {
			totalHeight += key.height;
		}
		totalHeight += _header.height;
		StyleSheet ss = getStyleSheet();
		bool needsVSB, needsHSB;
		if (totalWidth > position.width) 
			needsHSB = true;
		if (totalHeight > position.height)
			needsVSB = true;
		if (needsVSB && totalWidth > position.width - ss.drawParameters["VertScrollBarSize"])
			needsHSB = true;
		if (needsHSB && totalHeight > position.height - ss.drawParameters["HorizScrollBarSize"])
			needsVSB = true;
		totalHeight -= _header.height;
		if (needsVSB && !vertSlider) {
			const int maxvalue = needsHSB ? totalHeight - position.height - ss.drawParameters["HorizScrollBarSize"] : 
					totalHeight - position.height;
			const Box target = Box(position.left, position.bottom - ss.drawParameters["VertScrollBarSize"], 
					needsHSB ? position.right - ss.drawParameters["HorizScrollBarSize"] : position.right,
					position.bottom);
			vertSlider = new VertScrollBar(maxvalue, source ~ "VSB", target);
		}
		if (needsHSB){
			const int maxvalue = needsVSB ? totalWidth - position.width - ss.drawParameters["VertScrollBarSize"] : 
					totalWidth - position.width;
			const Box target = Box(position.right - ss.drawParameters["HorizScrollBarSize"], position.top, 
					position.right, needsVSB ? position.bottom - ss.drawParameters["VertScrollBarSize"] : position.bottom);
			horizSlider = new HorizScrollBar(maxvalue, source ~ "VSB", target);
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