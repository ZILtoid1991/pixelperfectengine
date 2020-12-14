module PixelPerfectEngine.concrete.elements.panel;

import PixelPerfectEngine.concrete.elements.base;

import PixelPerfectEngine.system.etc : clamp;

import collections.linkedlist;


/**
 * Panel for grouping elements.
 * Does not directly handle elements, instead relies on blitter transparency. However, can handle
 * the state of the elements.
 */
public class Panel : WindowElement, ElementContainer {
	alias WESet = LinkedList!(WindowElement, false, "cmpObjPtr(a, b)");
	protected WESet subElems;			///Contains all elements within the panel
	protected sizediff_t focusedElem;				///Index of the currently focused element
	/**
	 * Default CTOR
	 */
	public this(Text text, string source, Coordinate coordinates) {
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
	}
	///Ditto
	public this(dstring text, string source, Coordinate position) {
		this(new Text(text, getAvailableStyleSheet().getChrFormatting("panel")), source, position);
	}
	public override void draw() {
		foreach (WindowElement key; subElems) {
			key.draw;
		}
		StyleSheet ss = getStyleSheet();
		const int textLength = text.getWidth();
		const Box offsetEdge = position - (text.font.size / 2);
		const Box textPos = Box(offsetEdge.left, position.top, offsetEdge.left + textLength, position.top + text.font.size);
		with (parent) {
			drawLine(Point(offsetEdge.left + textLength, offsetEdge.top), offsetEdge.cornerUR, ss.getColor("windowAscent"));
			drawLine(offsetEdge.cornerUL, offsetEdge.cornerLL, ss.getColor("windowAscent"));
			drawLine(offsetEdge.cornerLL, offsetEdge.cornerLR, ss.getColor("windowAscent"));
			drawLine(offsetEdge.cornerUR, offsetEdge.cornerLR, ss.getColor("windowAscent"));
			drawTextSL(textPos, text, Point(0, 0));
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	
	public Coordinate getAbsolutePosition(WindowElement sender) {
		return parent.getAbsolutePosition(sender); // TODO: implement
	}
	
	/**
	 * Gives focus to the element if applicable
	 */
	public void requestFocus(WindowElement sender) {
		subElems[focusedElem].focusTaken();
		focusedElem = subElems.which(sender);
		subElems[focusedElem].focusGiven();
	}
	///Called when an object receives focus.
	public override void focusGiven() {
		if(subElems.length) subElems[focusedElem].focusGiven();
		flags |= IS_FOCUSED;
		draw;
	}
	///Called when an object loses focus.
	public override void focusTaken() {
		subElems[focusedElem].focusTaken();
		flags &= ~IS_FOCUSED;
		draw;
	}
	///Cycles the focus on a single element.
	///Returns -1 if end is reached, or the number of remaining elements that
	///are cycleable in the direction.
	public override int cycleFocus(int direction) {
		if (focusedElem + direction < 0 || focusedElem + direction >= subElems.length) {
			return -1;
		} else {
			if (subElems.length) {
				const int result = subElems[focusedElem].cycleFocus;
				if (result == -1) {
					subElems[focusedElem].focusTaken();
					focusedElem += direction;
					subElems[focusedElem].focusGiven();
				}
			}
			return direction > 1 ? cast(int)(subElems.length - focusedElem) : focusedElem;
		}
	}
	public void clearArea(WindowElement sender) {
		parent.clearArena(sender);
	}
	
	public void drawLine(Point from, Point to, ubyte color) @trusted pure {
		parent.drawLine(from, to, color);
	}
	
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted pure {
		parent.drawLinePattern(from, to, pattern);
	}
	
	public void drawBox(Coordinate target, ubyte color) @trusted pure {
		parent.drawBox(target, color);
	}
	
	public void drawBoxPattern(Coordinate target, ubyte[] pattern) @trusted pure {
		parent.drawBoxPattern(target, pattern);
	}
	
	public void drawFilledBox(Coordinate target, ubyte color) @trusted pure {
		parent.drawFilledBox(target, color);
	}
	
	public void bitBLT(Point target, ABitmap source) @trusted pure {
		parent.bitBLT(target, source);
	}
	
	public void bitBLT(Point target, ABitmap source, Coordinate slice) @trusted pure {
		parent.bitBLT(target, source, slice);
	}
	
	public void bitBLTPattern(Coordinate target, ABitmap pattern) @trusted pure {
		parent.bitBLTPattern(target, pattern);
	}
	
	public void xorBitBLT(Coordinate target, ABitmap pattern) @trusted pure {
		parent.xorBitBLT(target, pattern);
	}
	
	public void xorBitBLT(Coordinate target, ubyte color) @trusted pure {
		parent.xorBitBLT(target, color);
	}
	
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted pure {
		parent.fill(target, color, background);
	}
	
	public void drawTextSL(Coordinate target, Text text, Point offset) @trusted pure {
		parent.drawTextSL(target, text, offset);
	}
	
	public void drawTextML(Coordinate target, Text text, Point offset) @trusted pure {
		parent.drawTextML(target, text, offset);
	}
	
	public void clearArea(Coordinate target) @trusted pure {
		parent.clearArea(target);
	}
	
}
