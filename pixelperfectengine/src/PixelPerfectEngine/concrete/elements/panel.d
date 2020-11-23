module PixelPerfectEngine.concrete.elements.panel;

import PixelPerfectEngine.concrete.elements.base;

/**
 * Panel for grouping elements.
 * Does not directly handle elements, instead relies on blitter transparency. However, can handle
 * the state of the elements.
 */
public class Panel : WindowElement, ElementContainer {
	public WindowElement[] subElems;
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
