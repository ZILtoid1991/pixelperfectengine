module pixelperfectengine.concrete.elements.listview;

import pixelperfectengine.concrete.elements.base;
import pixelperfectengine.concrete.elements.scrollbar;

import pixelperfectengine.system.etc : clamp, min, max;

import pixelperfectengine.system.input.types : TextInputFieldType;

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
			return flags & IS_EDITABLE ? true : false;
		}
		///Sets whether the field is editable. Returns the new value.
		public @property bool editable(bool val) @nogc @safe pure nothrow {
			if (val) flags |= IS_EDITABLE;
			else flags &= ~IS_EDITABLE;
			return flags & IS_EDITABLE ? true : false;
		}
		///Returns whether the field is integer only.
		public @property bool integerOnly() @nogc @safe pure nothrow const {
			return flags & INTEGER_ONLY ? true : false;
		}
		///Sets whether the field is integer only. Returns the new value.
		public @property bool integerOnly(bool val) @nogc @safe pure nothrow {
			if (val) flags |= INTEGER_ONLY;
			else flags &= ~INTEGER_ONLY;
			return flags & INTEGER_ONLY ? true : false;
		}
		///Returns whether the field is numeric only.
		public @property bool numericOnly() @nogc @safe pure nothrow const {
			return flags & NUMERIC_ONLY ? true : false;
		}
		///Sets whether the field is numeric only. Returns the new value.
		public @property bool numericOnly(bool val) @nogc @safe pure nothrow {
			if (val) flags |= NUMERIC_ONLY;
			else flags &= ~NUMERIC_ONLY;
			return flags & NUMERIC_ONLY ? true : false;
		}
		///Returns whether the field forces floating point.
		public @property bool forceFP() @nogc @safe pure nothrow const {
			return flags & FORCE_FP ? true : false;
		}
		///Sets whether the field forces floating point. Returns the new value.
		public @property bool forceFP(bool val) @nogc @safe pure nothrow {
			if (val) flags |= FORCE_FP;
			else flags &= ~FORCE_FP;
			return flags & FORCE_FP ? true : false;
		}
		///Returns the field's format flags.
		public @property FormatFlags formatFlags() @nogc @safe pure nothrow const {
			return cast(FormatFlags)(flags & FORMAT_FLAGS);
		}
		///Sets whether the field is editable. Returns the new value.
		public @property FormatFlags formatFlags(FormatFlags val) @nogc @safe pure nothrow {
			flags |= val;
			return cast(FormatFlags)(flags & FORMAT_FLAGS);
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
	this (int height, Text[] fields) @safe pure nothrow {
		this.height = height;
		this.fields.reserve = fields.length;
		foreach (Text key; fields) {
			this.fields ~= Field(key, null, Field.FormatFlags.Context);
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
	 * Creates a ListViewItem with default text formatting.
	 */
	this (int height, dstring[] ds) @safe nothrow {
		this.height = height;
		fields.reserve = ds.length;
		foreach (dstring key ; ds) {
			this.fields ~= Field(new Text(key, globalDefaultStyle.getChrFormatting("ListViewHeader")), null, 
					Field.FormatFlags.Context);
		}
	}
	/**
	 * Creates a ListViewItem with default text formatting and input type.
	 */
	this (int height, dstring[] ds, TextInputFieldType[] inputTypes) @safe nothrow {
		this.height = height;
		fields.reserve = ds.length;
		assert (ds.length == inputTypes.length, "Mismatch in inputTypes and text length");
		for (size_t i ; i < ds.length ; i++) {
			Field f = Field(new Text(ds[i], globalDefaultStyle.getChrFormatting("ListViewHeader")), null, 
					Field.FormatFlags.Context);
			final switch (inputTypes[i]) with (TextInputFieldType) {
				case Text:
					f.editable = true;
					break;
				case Numeric:
					f.numericOnly = true;
					goto case Text;
				case Integer:
					f.integerOnly = true;
					goto case Text;
				case Dec:
					f.formatFlags = Field.FormatFlags.Dec;
					goto case Integer;
				case Hex:
					f.formatFlags = Field.FormatFlags.HexH;
					goto case Integer;
				case Oct:
					f.formatFlags = Field.FormatFlags.OctH;
					goto case Integer;
				case Bin:
					f.formatFlags = Field.FormatFlags.BinH;
					goto case Integer;
				case None, ASCIIText:
					break;
			}
			fields ~= f;
		}
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
		return fields.length;
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
			t.right = min(t.left + parent.drawParams.columnWidths[i] - offset.x, target.right);
			parent.drawTextSL(t.pad(ss.drawParameters["ListViewColPadding"], ss.drawParameters["ListViewRowPadding"]), 
					fields[i].text, offset);
			t.left = t.right;
			offset.x = 0;
		}
		parent.drawParams.target.relMove(0, height - parent.drawParams.offsetFR);
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
	this(int height, int[] columnWidths, Text[] fields) @safe pure nothrow {
		assert (columnWidths.length == fields.length, "Lenght mismatch between the two arrays!");
		this.columnWidths = columnWidths;
		super(height, fields);
	}
	///CTOR for creating fields with default text formatting
	this(int height, int[] columnWidths, dstring[] ds) @safe nothrow {
		Text[] fields;
		fields.reserve = ds.length;
		foreach (dstring key; ds) {
			fields ~= new Text(key, globalDefaultStyle.getChrFormatting("ListViewHeader"));
		}
		this(height, columnWidths, fields);
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
			t.right = min(t.left + parent.drawParams.columnWidths[i] - offset.x, target.right);
			if (!offset.x) {
				parent.drawLine(t.cornerUL, t.cornerLL, ss.getColor("windowascent"));
			}
			if (t.left + parent.drawParams.columnWidths[i] < target.right) {
				Point from = t.cornerUR, to = t.cornerLR;
				from.x = from.x - 1;
				to.x = to.x - 1;
				parent.drawLine(from, to, ss.getColor("windowdescent"));
			}
			with (parent) {
				drawLine(t.cornerUL, t.cornerUR, ss.getColor("windowascent"));
				drawLine(t.cornerLL, t.cornerLR, ss.getColor("windowdescent"));
				drawTextSL(t.pad(ss.drawParameters["ListViewColPadding"], ss.drawParameters["ListViewRowPadding"]), fields[i].text, 
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
public class ListView : WindowElement, ElementContainer, TextInputListener {
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
	protected int				hSelection;		///Horizontal selection for text editing.
	protected int				tselect;		///Lenght of selected characters.
	protected int				cursorPos;		///Position of cursor.
	protected int				horizTextOffset;///Horizontal text offset if text cannot fit the cell.
	///Text editing area.
	protected Box				textArea;
	//protected Text				oldText;
	///Holds shared draw parameters that are used when the element is being drawn.
	///Should be set to null otherwise.
	public DrawParameters		drawParams;
	///Called when an item is selected
	public EventDeleg			onItemSelect;
	///Called when text input is finished and accepted
	public EventDeleg			onTextInput;
	protected static enum	EDIT_EN = 1<<9;
	protected static enum	MULTICELL_EDIT_EN = 1<<10;
	protected static enum	TEXTINPUT_EN = 1<<11;
	protected static enum	INSERT = 1<<12;
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
		if (value.length == _header.length) {
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
			if (value.length == _header.length) {
				entries ~= value;
			} else throw new Exception("Column number mismatch!");
		} else static assert (0, "Unsupported operator!");
		return value;
	}
	/**
	 * Allows to append multiple elements to the entry list.
	 */
	public ListViewItem[] opOpAssign(string op)(ListViewItem[] value) {
		static if (op == "~" || op == "+") {
			foreach (ListViewItem key; value) {
				if (key.length == _header.length) {
					entries ~= key;
				} else throw new Exception("Column number mismatch!");
			}
		} else static assert (0, "Unsupported operator!");
		return value;
	}
	override public void draw() {
		StyleSheet ss = getStyleSheet;
		if (flags & TEXTINPUT_EN) { //only redraw the editing cell in this case
			const int textPadding = ss.drawParameters["TextSpacingSides"];
			
			clearArea(textArea);
			//drawBox(position, ss.getColor("windowascent"));
			
			//draw cursor
			//if (flags & ENABLE_TEXT_EDIT) {
			//calculate cursor first
			Box cursor = Box(textArea.left + textPadding, textArea.top + textPadding, textArea.left + textPadding, 
					textArea.bottom - textPadding);
			cursor.left += text.getWidth(0, cursorPos) - horizTextOffset;
			//cursor must be at least single pixel wide
			cursor.right = cursor.left;
			if (tselect) {
				cursor.right += text.getWidth(cursorPos, cursorPos + tselect);
			} else if (flags & INSERT) {
				if (cursorPos < text.charLength) cursor.right += text.getWidth(cursorPos, cursorPos+1);
				else cursor.right += text.font.chars(' ').xadvance;
			} else {
				cursor.right++;
			}
			//Clamp down if cursor is wider than the text editing area
			cursor.right = cursor.right <= textArea.right - textPadding ? cursor.right : textArea.right - textPadding;
			//Draw cursor
			parent.drawFilledBox(cursor, ss.getColor("selection"));

			//}
			//draw text
			parent.drawTextSL(textArea - textPadding, text, Point(horizTextOffset, 0));
		} else {
			parent.clearArea(position);

			parent.drawBox(position, ss.getColor("windowascent"));
			Point upper = Point(0, position.top + _header.height);
			Point lower = Point(0, position.bottom);
			{	///Calculate first column stuff
				int offsetP, offsetC, targetC, targetP;
				if (horizSlider) { 
					offsetP = horizSlider.value();
					//int offsetC;
					for (; _header.columnWidths[offsetC] < offsetP ; offsetC++) {
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
				drawParams.offsetFR = pixelsTotal;
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
					Box target = drawParams.target - 1;
					target.bottom -= drawParams.offsetFR;
					parent.drawFilledBox(target, ss.getColor("selection"));
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
			if (horizSlider) horizSlider.draw;
			if (vertSlider) vertSlider.draw;

			drawParams = null;
		}
		if (onDraw !is null) {
			onDraw();
		}
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
	public @property int value(int val) {
		selection = val;
		draw;
		return selection;
	}
	/**
	 * Enables or disables the text editing of this element.
	 */
	public @property bool editEnable(bool val) @nogc @safe pure nothrow {
		if (val) flags |= EDIT_EN;
		else flags &= ~EDIT_EN;
		return flags & EDIT_EN ? true : false;
	}
	/**
	 * Returns true if text editing is enabled.
	 */
	public @property bool editEnable() @nogc @safe pure nothrow const {
		return flags & EDIT_EN ? true : false;
	}
	/**
	 * Enables or disables editing for multiple cells.
	 * If disabled, the first cell with editing enabled will be able to be edited.
	 */
	public @property bool multicellEditEnable(bool val) @nogc @safe pure nothrow {
		if (val) flags |= MULTICELL_EDIT_EN;
		else flags &= ~MULTICELL_EDIT_EN;
		return flags & MULTICELL_EDIT_EN ? true : false;
	}
	/**
	 * Returns true if text editing for multiple cells is enabled.
	 */
	public @property bool multicellEditEnable() @nogc @safe pure nothrow const {
		return flags & MULTICELL_EDIT_EN ? true : false;
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
		if (selection >= entries.length) selection--;
		//draw;
		return result;
	}
	/**
	 * Removes all entries in the list.
	 */
	public void clear() @safe {
		entries.length = 0;
	}
	/**
	 * Refreshes the list view.
	 * Must be called every time when adding new items is finished.
	 */
	public void refresh() {
		selection = -1;
		recalculateTotalSizes;
		draw;
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
		if (needsVSB) {
			const int maxvalue = needsHSB ? totalHeight - position.height - ss.drawParameters["HorizScrollBarSize"] : 
					totalHeight - position.height;
			
			const Box target = Box(position.right - ss.drawParameters["HorizScrollBarSize"] + 2, position.top, 
					position.right, needsVSB ? position.bottom - ss.drawParameters["VertScrollBarSize"] : position.bottom);
			vertSlider = new VertScrollBar(maxvalue, source ~ "VSB", target);
			vertSlider.setParent(this);
			vertSlider.onScrolling = &scrollBarEventOut;
		} else vertSlider = null;
		if (needsHSB){
			const int maxvalue = needsVSB ? totalWidth - position.width - ss.drawParameters["VertScrollBarSize"] : 
					totalWidth - position.width;
			const Box target = Box(position.left, position.bottom - ss.drawParameters["VertScrollBarSize"] + 2, 
					needsVSB ? position.right - ss.drawParameters["HorizScrollBarSize"] : position.right,
					position.bottom);
			horizSlider = new HorizScrollBar(maxvalue, source ~ "VSB", target);
			horizSlider.setParent(this);
			horizSlider.onScrolling = &scrollBarEventOut;
		} else horizSlider = null;
	}
	protected void scrollBarEventOut(Event ev) {
		draw;
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
	public void drawLine(Point from, Point to, ubyte color) @trusted {
		parent.drawLine(from, to, color);
	}
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted {
		parent.drawLinePattern(from, to, pattern);
	}
	///Draws an empty rectangle.
	public void drawBox(Box target, ubyte color) @trusted {
		parent.drawBox(target, color);
	}
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Box target, ubyte[] pattern) @trusted {
		parent.drawBoxPattern(target, pattern);
	}
	///Draws a filled rectangle with a specified color.
	public void drawFilledBox(Box target, ubyte color) @trusted {
		parent.drawFilledBox(target, color);
	}
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted {
		parent.bitBLT(target, source);
	}
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Box slice) @trusted {
		parent.bitBLT(target, source, slice);
	}
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Box target, ABitmap pattern) @trusted {
		parent.bitBLTPattern(target, pattern);
	}
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Box target, ABitmap pattern) @trusted {
		parent.xorBitBLT(target, pattern);
	}
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Box target, ubyte color) @trusted {
		parent.xorBitBLT(target, color);
	}
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted {
		parent.fill(target, color, background);
	}
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Box target, Text text, Point offset) @trusted {
		parent.drawTextSL(target, text, offset);
	}
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Box target, Text text, Point offset) @trusted {
		parent.drawTextML(target, text, offset);
	}
	///Clears the area within the target
	public void clearArea(Box target) @trusted {
		parent.clearArea(target);
	}
	///Passes mouse click event
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		///TODO: Handle mouse click when in text editing mode

		if (vertSlider) {
			const Box p = vertSlider.getPosition();
			if (p.isBetween(mce.x, mce.y)) {
				mce.x -= p.left - position.left;
				mce.y -= p.top - position.top;
				vertSlider.passMCE(mec, mce);
				return;
			}
		}
		if (horizSlider) {
			const Box p = horizSlider.getPosition();
			if (p.isBetween(mce.x, mce.y)) {
				mce.x -= p.left - position.left;
				mce.y -= p.top - position.top;
				horizSlider.passMCE(mec, mce);
				return;
			}
		}

		//if (mce.button != MouseButton.Left && !mce.state) return;

		mce.x -= position.left;
		mce.y -= position.top;
		if (entries.length && mce.y > _header.height && mce.button == MouseButton.Left && mce.state) {
			textArea.top = position.top;
			textArea.left = position.left;
			mce.y -= _header.height;
			int pixelsTotal = mce.y, pos;
			if (vertSlider) ///calculate outscrolled area
				pixelsTotal += vertSlider.value;
			while (pos < entries.length) {
				if (pixelsTotal > entries[pos].height) {
					pixelsTotal -= entries[pos].height;
					textArea.top += entries[pos].height;
					if (pos + 1 < entries.length)
						pos++;
				} else {
					break;
				}
			}
			if (pos >= entries.length) {
				selection = -1;
			} else if (selection == pos && (flags & EDIT_EN)) {
				//Calculate horizontal selection for Multicell editing if needed
				if (flags & MULTICELL_EDIT_EN) {

				} else {
					foreach (size_t i, ListViewItem.Field f ; entries[selection].fields) {
						if (f.editable) {
							hSelection = cast(int)i;
							if (vertSlider) textArea.top -= vertSlider.value;
							if (horizSlider) textArea.left -= horizSlider.value;
							textArea.top += _header.height;
							with (textArea) {
								bottom = entries[selection].height + textArea.top;
								right = _header.columnWidths[i] + textArea.left;
								left = max(textArea.left, position.left);
								top = max(textArea.top, position.top);
								right = min(textArea.right, position.right);
								bottom = min(textArea.bottom, position.bottom);
							}
							text = entries[selection][hSelection].text;
							cursorPos = 0;
							tselect = cast(int)text.charLength;
							//oldText = text;
							inputHandler.startTextInput(this);
							break;
						}
						textArea.left += _header.columnWidths[i];
					}
				}
				selection = pos;
			} else 
				selection = pos;

			if (onItemSelect !is null && selection != -1)
				onItemSelect(new Event(this, entries[selection], EventType.Selection, SourceType.WindowElement));
		} else if (!entries.length)
			selection = -1;
		
		draw();
	}
	///Passes mouse move event
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (vertSlider) {
			const Box p = vertSlider.getPosition();
			if (p.isBetween(mme.x, mme.y)) {
				mme.x -= p.left - position.left;
				mme.y -= p.top - position.top;
				vertSlider.passMME(mec, mme);
				return;
			}
		}
		if (horizSlider) {
			const Box p = horizSlider.getPosition();
			if (p.isBetween(mme.x, mme.y)) {
				mme.x -= p.left - position.left;
				mme.y -= p.top - position.top;
				horizSlider.passMME(mec, mme);
				return;
			}
		}
	}
	///Passes mouse scroll event
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (horizSlider) horizSlider.passMWE(mec, mwe);
		if (vertSlider) vertSlider.passMWE(mec, mwe);
	}
	/**
	 * Puts a PopUpElement on the GUI.
	 */
	public void addPopUpElement(PopUpElement p) {
		parent.addPopUpElement(p);
	}
	/**
	 * Puts a PopUpElement on the GUI at the given position.
	 */
	public void addPopUpElement(PopUpElement p, int x, int y) {
		parent.addPopUpElement(p, x, y);
	}
	/** 
	 * Ends the popup session and closes all popups.
	 */
	public void endPopUpSession(PopUpElement p) {
		parent.endPopUpSession(p);
	}
	/**
	 * Closes a single popup element.
	 */
	public void closePopUp(PopUpElement p) {
		parent.closePopUp(p);
	}
	//Interface `TextInputListener` starts here
	/**
	 * Passes the inputted text to the target, alongside with a window ID and a timestamp.
	 */
	public void textInputEvent(uint timestamp, uint windowID, dstring text) {
		if (tselect) {
			this.text.removeChar(cursorPos, tselect);
			tselect = 0;
			for(int j ; j < text.length ; j++){
				this.text.insertChar(cursorPos++, text[j]);
			}
		} else if (flags & INSERT) {
			for(int j ; j < text.length ; j++){
				this.text.overwriteChar(cursorPos++, text[j]);
			}
		} else {
			for(int j ; j < text.length ; j++){
				this.text.insertChar(cursorPos++, text[j]);
			}
		}
		const int textPadding = getStyleSheet.drawParameters["TextSpacingSides"];
		const Coordinate textPos = Coordinate(textPadding,(position.height / 2) - (this.text.font.size / 2) ,
				position.width,position.height - textPadding);
		const int x = this.text.getWidth(), cursorPixelPos = this.text.getWidth(0, cursorPos);
		if(x > textPos.width) {
			 if(cursorPos == this.text.text.length) {
				horizTextOffset = x - textPos.width;
			 } else if(cursorPixelPos < horizTextOffset) { //Test for whether the cursor would fall out from the current text area
				horizTextOffset = cursorPixelPos;
			 } else if(cursorPixelPos > horizTextOffset + textPos.width) {
				horizTextOffset = horizTextOffset + textPos.width;
			 }
		}
		draw();
	}
	/**
	 * Passes text editing events to the target, alongside with a window ID and a timestamp.
	 */
	public void textEditingEvent(uint timestamp, uint windowID, dstring text, int start, int length) {
		for (int i ; i < length ; i++) {
			this.text.overwriteChar(start + i, text[i]);
		}
		cursorPos = start + length;
	}
	/**
	 * Passes text input key events to the target, e.g. cursor keys.
	 */
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier) {
		switch(key) {
			case TextInputKey.Enter:
				entries[selection][hSelection].text = text;
				inputHandler.stopTextInput();
				if(onTextInput !is null)
					onTextInput(new CellEditEvent(this, entries[selection], selection, hSelection));
					//onTextInput(new Event(source, null, null, null, text, 0, EventType.T, null, this));
				break;
			case TextInputKey.Escape:
				//text = oldText;
				inputHandler.stopTextInput();
				

				break;
			case TextInputKey.Backspace:
				if(cursorPos > 0){
					deleteCharacter(cursorPos - 1);
					cursorPos--;
					draw();
				}
				break;
			case TextInputKey.Delete:
				if (tselect) {
					
				} else deleteCharacter(cursorPos);
				draw();
				break;
			case TextInputKey.CursorLeft:
				if (modifier != KeyModifier.Shift) {
					tselect = 0;
					if(cursorPos > 0){
						--cursorPos;
						draw();
					}
				}
				break;
			case TextInputKey.CursorRight:
				if (modifier != KeyModifier.Shift) {
					tselect = 0;
					if(cursorPos < text.charLength){
						++cursorPos;
						draw();
					}
				}
				break;
			case TextInputKey.Home:
				if (modifier != KeyModifier.Shift) {
					tselect = 0;
					cursorPos = 0;
					draw();
				}
				break;
			case TextInputKey.End:
				if (modifier != KeyModifier.Shift) {
					tselect = 0;
					cursorPos = cast(int)text.charLength;
					draw();
				}
				break;
			case TextInputKey.Insert:
				flags ^= INSERT;
				draw();
				break;
			default:
				break;
		}
	}
	/**
	 * When called, the listener should drop all text input.
	 */
	public void dropTextInput() {
		flags &= ~TEXTINPUT_EN;
		draw;
	}
	/**
	 * Called if text input should be initialized.
	 */
	public void initTextInput() {
		flags |= TEXTINPUT_EN;
	}
	private void deleteCharacter(size_t n){
		text.removeChar(n);
	}
}
