/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.window module
 */

module PixelPerfectEngine.concrete.window;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
import PixelPerfectEngine.graphics.layers;

public import PixelPerfectEngine.concrete.elements;
public import PixelPerfectEngine.concrete.types;
public import PixelPerfectEngine.concrete.interfaces;
public import PixelPerfectEngine.concrete.windowhandler;

import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.input.interfaces;

import std.algorithm.mutation;
import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.datetime;

import collections.linkedlist;

/**
 * Basic window. All other windows are inherited from this class.
 */
public class Window : ElementContainer, Focusable, MouseEventReceptor {
	alias FocusableSet = LinkedList!(Focusable, false, "cmpObjPtr(a, b)");
	alias WESet = LinkedList!(WindowElement, false, "cmpObjPtr(a, b)");
	alias SBSet = LinkedList!(ISmallButton, false, "cmpObjPtr(a, b)");
	alias CWSet = LinkedList!(Window, false, "cmpObjPtr(a, b)");
	protected FocusableSet			focusables;		///All focusable objects belonging to the window
	protected WESet			 		elements;		///Stores all window elements here
	protected Text					title;			///Title of the window
	protected WindowElement 		lastMouseEventTarget;	///Used for mouse move and wheel events
	protected sizediff_t			focusedElement; ///The index of the currently focused element, or -1 if none
	public WindowHandler 			handler;		///The handler of the window
	//public Bitmap16Bit[int] altStyleBrush;
	protected BitmapDrawer 			output;			///Graphics output of the window
	//public int header;//, sizeX, sizeY;
	protected int 					moveX, moveY;	///Relative x and y coordinates for drag events
	protected uint					flags;			///Stores various flags
	protected static enum IS_ACTIVE = 1 << 0;
	protected static enum NEEDS_FULL_UPDATE = 1 << 1;
	protected static enum HEADER_UPDATE = 1 << 2;
	protected static enum IS_MOVED = 1 << 3;
	protected static enum IS_RESIZED = 1 << 4;
	protected static enum IS_RESIZED_L = 1 << 5;
	protected static enum IS_RESIZED_T = 1 << 6;
	protected static enum IS_RESIZED_B = 1 << 7;
	protected static enum IS_RESIZED_R = 1 << 8;
	protected static enum IS_RESIZABLE_BY_MOUSE = 1 << 9;
	//protected bool 					fullUpdate;		///True if window needs full redraw
	//protected bool 					isActive;		///True if window is currently active
	//protected bool 					headerUpdate;	///True if needs header update
	protected Point					lastMousePos;	///Stores the last mouse position.
	protected SBSet					smallButtons;	///Contains the icons of the extra buttons. Might be replaced with a WindowElement in the future
	protected Box	 				position;		///Position of the window
	public StyleSheet 				customStyle;	///Custom stylesheet for this window
	protected CWSet					children;		///Stores child windows
	protected Window				parent;			///Stores reference to the parent
	public static void delegate() 	onDrawUpdate;	///Called if not null after every draw update
	/**
	 * Standard constructor. "size" sets both the initial position and the size of the window.
	 */
	public this(Box size, Text title, ISmallButton[] smallButtons = [], StyleSheet customStyle = null) {
		position = size;
		output = new BitmapDrawer(position.width(), position.height());
		this.title = title;
		this.customStyle = customStyle;
		this.smallButtons = SBSet(smallButtons);
	}
	///Ditto
	public this(Box size, dstring title, ISmallButton[] smallButtons = [], StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		this(size, new Text(title, getStyleSheet().getChrFormatting("windowHeader")), extraButtons, customStyle);
	}
	/**
	 * If the current window doesn't contain a custom StyleSheet, it gets from it's parent.
	 */
	public StyleSheet getStyleSheet() {
		if (customStyle is null) {
			if (parent is null) return globalDefaultStyle;
			else return parent.getStyleSheet();
		} else {
			return customStyle;
		}
	}
	/**
	 * Adds an element to the window.
	 */
	public void addElement(WindowElement we) {
		we.elementContainer = this;
		elements.put(we);
		focusables.put(we);
		we.draw();
	}
	/**
	 * Removes the WindowElement if 'we' is found within its ranges, does nothing otherwise.
	 */
	public void removeElement(WindowElement we) {
		for(int i ; i < elements.length ; i++) {
			if(elements[i] == we) {
				elements = remove(elements, i);
				break;
			}
		}
		draw();
	}
	/**
	 * Draws the window. Intended to be used by the WindowHandler.
	 */
	public void draw(bool drawHeaderOnly = false) {
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		
		//drawing the header
		drawHeader();
		if(drawHeaderOnly)
			return;
		output.drawFilledRectangle(0, position.width() - 1, getStyleSheet().getImage("closeButtonA").height,
				position.height() - 1, getStyleSheet().getColor("window"));
		int y1 = getStyleSheet().getImage("closeButtonA").height;
		/*output.drawRectangle(x1, sizeX - 1, 0, y1, getStyleBrush(header));
		output.drawFilledRectangle(x1 + (x1/2), sizeX - 1 - (x1/2), y1/2, y1 - (y1/2), getStyleBrush(header).readPixel(x1/2, y1/2));*/

		//int headerLength = cast(int)(extraButtons.length == 0 ? position.width - 1 : position.width() - 1 - ((extraButtons.length>>2) * x1) );

		//drawing the border of the window
		output.drawLine(0, position.width() - 1, y1, y1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, 0, y1, position.height() - 1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, position.width() - 1, position.height() - 1, position.height() - 1,
				getStyleSheet().getColor("windowdescent"));
		output.drawLine(position.width() - 1, position.width() - 1, y1, position.height() - 1,
				getStyleSheet().getColor("windowdescent"));

		//output.drawText(x1+1, 1, title, getFontSet(0), 1);

		fullUpdate = true;
		foreach(WindowElement we; elements){
			we.draw();
			//output.insertBitmap(we.getPosition().xa,we.getPosition().ya,we.output.output);
		}
		fullUpdate = false;
		parent.drawUpdate(this);
		if(onDrawUpdate !is null){
			onDrawUpdate();
		}
	}
	/**
	 * Draws the header.
	 */
	protected void drawHeader() {
		const ushort colorC = isActive ? getStyleSheet().getColor("WHAtop") : getStyleSheet().getColor("window");
		output.drawFilledRectangle(0, position.width() - 1, 0, getStyleSheet().getImage("closeButtonA").height - 1, colorC);
		output.insertBitmap(0,0,getStyleSheet().getImage("closeButtonA"));
		const int x1 = getStyleSheet().getImage("closeButtonA").width, y1 = getStyleSheet().drawParameters
				["WindowHeaderHeight"];
		int x2 = position.width;
		int headerLength = cast(int)(extraButtons.length == 0 ? position.width() - 1 : position.width() - 1 -
				(extraButtons.length * x1));
		foreach(s ; extraButtons){
			x2 -= x1;
			output.insertBitmap(x2,0,getStyleSheet().getImage(s));
		}
		const ushort colorA = isActive ? getStyleSheet().getColor("WHAascent") : getStyleSheet().getColor("windowascent"),
				colorB = isActive ? getStyleSheet().getColor("WHAdescent") : getStyleSheet().getColor("windowdescent");
		output.drawLine(x1, headerLength, 0, 0, colorA);
		output.drawLine(x1, x1, 0, y1 - 1, colorA);
		output.drawLine(x1, headerLength, y1 - 1, y1 - 1, colorB);
		output.drawLine(headerLength, headerLength, 0, y1 - 1, colorB);
		if(title) {
			title.formatting = getStyleSheet().getChrFormatting(isActive ? "windowHeader" : "windowHeaderInactive");
			const Coordinate textPos = Coordinate(x1, getStyleSheet().drawParameters["WHPaddingTop"],headerLength,y1);
			output.drawSingleLineText(textPos, title);
		}
	}
	///Returns true if the window is focused
	public @property bool active() @safe @nogc pure nothrow {
		return flags & IS_ACTIVE;
	}
	///Sets the IS_ACTIVE flag to the given value
	protected @property bool active(bool val) @safe @nogc pure nothrow {
		if (val) flags |= IS_ACTIVE;
		else flags &= ~IS_ACTIVE;
		return active();
	}
	///Returns whether the window is moved or not
	public @property bool isMoved() @safe @nogc pure nothrow {
		return flags & IS_MOVED;
	}
	///Sets whether the window is moved or not
	public @property bool isMoved(bool val) @safe @nogc pure nothrow {
		if (val) flags |= IS_MOVED;
		else flags &= ~IS_MOVED;
		return isMoved();
	}
	///Sets the title of the window
	public void setTitle(Text s) @trusted {
		title = s;
		headerUpdate = true;
		drawHeader();
	}
	///Ditto
	public void setTitle(dstring s) @trusted {
		title.text = s;
		headerUpdate = true;
		drawHeader();
	}
	///Returns the title of the window
	public Text getTitle() @safe @nogc pure nothrow {
		return title;
	}
	/**
	 * Detects where the mouse is clicked, then it either passes to an element, or tests whether the close button,
	 * an extra button was clicked, also tests for the header, which creates a drag event for moving the window.
	 */
	public void passMouseEvent(int x, int y, int state, ubyte button) {
		if (state == ButtonState.PRESSED) {
			if (getStyleSheet.getImage("closeButtonA").width > x && getStyleSheet.getImage("closeButtonA").height > y && 
					button == MouseButton.LEFT) {
				close();
				return;
			} else if (getStyleSheet.getImage("closeButtonA").height > y) {
				if(x > position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length)){
					x -= position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length);
					extraButtonEvent(x / getStyleSheet.getImage("closeButtonA").width, button, state);
					return;
				}
				parent.moveUpdate(this);
				return;
			}
			//x -= position.xa;
			//y -= position.ya;

			foreach(WindowElement e; elements){
				if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
					e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
					draggedElement = e;

					return;
				}
			}
		}else{
			if (draggedElement) {
				draggedElement.onClick(x - draggedElement.getPosition().left, y - draggedElement.getPosition().top, state, button);
				draggedElement = null;
			} else if (x > position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length)) {
				x -= position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length);
				extraButtonEvent(x / getStyleSheet.getImage("closeButtonA").width, button, state);
				return;
			}
		}
	}
	/**
	 * Closes the window by calling the WindowHandler's closeWindow function.
	 */
	public void close() {
		parent.closeWindow(this);
	}
	///Initializes close. Parameter `Event ev` is only as a placeholder for delegate compatibility.
	public void onClose(Event ev) {
		close;
	}
	/**
	 * Adds a WindowHandler to the window.
	 */
	public void addHandler(IWindowHandler wh) {
		handler = wh;
	}
	
	public Coordinate getAbsolutePosition(WindowElement sender){
		return Coordinate(sender.position.left + position.left, sender.position.top + position.top, sender.position.right + 
				position.right, sender.position.bottom + position.bottom);
	}
	/**
	 * Moves the window to the exact location.
	 */
	public void move(const int x, const int y) {
		position.move(x,y);
		handler.moveWindow(x, y, this);
	}
	/**
	 * Moves the window by the given values.
	 */
	public void relMove(const int x, const int y) {
		position.relMove(x,y);
		handler.relMoveWindow(x, y, this);
	}
	/**
	 * Sets the size of the window, also issues a redraw.
	 */
	public void resize(const int width, const int height) {
		position.right = position.left + width;
		position.bottom = position.top + height;
		draw();
		parent.refreshWindow(this);
	}
	/**
	 * Returns the outputted bitmap.
	 * Can be overridden for 32 bit outputs.
	 */
	public @property ABitmap getOutput(){
		return output.output;
	}
	/**
	 * Gives focus to the windowelement requesting it.
	 */
	public void requestFocus(WindowElement sender) {
		try {
			focusables[focusedElement].focusTaken();
			Focusable f = cast(Focusable)(sender);
			focusedElement = focusables.which(f);
			focusables[focusedElement].focusGiven();
		} catch (Exception e) {
			debug writeln(e);
		}
	}
	/**
	 * Adds a child window to the current window.
	 */
	public void addChildWindow(Window w) {
		children.put(w);
		w.parent = this;
		children.setAsFirst(children.length);
		handler.addWindow(w);
	}
	/**
	 * Removes a child window from the current window.
	 */
	public void removeChildWindow(Window w) {
		if (children.removeByElem(w)) {
			w.parent = null;
			handler.removeWindow(w);
		}
		
	}
	/**
	 * Returns the child windows.
	 */
	public CWSet getChildWindows() {
		return children;
	}
	//Implementation of the `Canvas` interface starts here.
	///Draws a line.
	public void drawLine(Point from, Point to, ubyte color) @trusted pure {
		output.drawLine(from, to, color);
	}
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted pure {
		output.drawLinePattern(from, to, pattern);
	}
	///Draws an empty rectangle.
	public void drawBox(Coordinate target, ubyte color) @trusted pure {
		output.drawBox(target, color);
	}
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Coordinate target, ubyte[] pattern) @trusted pure {
		output.drawBox(target, pattern);
	}
	///Draws a filled rectangle with a specified color,
	public void drawFilledBox(Coordinate target, ubyte color) @trusted pure {
		output.drawFilledBox(target, color);
	}
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted pure {
		output.bitBLT(target, cast(Bitmap8Bit)source);
	}
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Coordinate slice) @trusted pure {
		output.bitBLT(target, cast(Bitmap8Bit)source, slice);
	}
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Coordinate target, ABitmap pattern) @trusted pure {
		output.bitBLTPattern(target, cast(Bitmap8Bit)pattern);
	}
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Coordinate target, ABitmap pattern) @trusted pure {
		output.xorBitBLT(target, cast(Bitmap8Bit)pattern);
	}
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Coordinate target, ubyte color) @trusted pure {
		output.xorBitBLT(target, color);
	}
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted pure {

	}
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Coordinate target, Text text, Point offset) @trusted pure {
		output.drawSingleLineText(target, text, offset.x, offset.y);
	}
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Coordinate target, Text text, Point offset) @trusted pure {
		output.drawMultiLineText(target, text, offset.x, offset.y);
	}
	///Clears the area within the target
	public void clearArea(Coordinate target) @trusted pure {
		output.drawBox(target, getStyleSheet.getColor("window"));
	}
	//Implementation of the `Focusable` interface:
	///Called when an object receives focus.
	public void focusGiven() {
		active = true;
		draw;
	}
	///Called when an object loses focus.
	public void focusTaken() {
		if (focusedElement != -1) {
			focusables[focusedElement].focusLost;
			focusedElement = -1;
		}
		active = false;
		draw;
	}
	///Cycles the focus on a single element.
	///Returns -1 if end is reached, or the number of remaining elements that
	///are cycleable in the direction.
	public int cycleFocus(int direction) {
		if (focusedElement < focusables.length && focusedElement >= 0) {
			if (focusables[focusedElement].cycleFocus(direction) == -1) {
				focusables[focusedElement].focusLost;
				focusedElement += direction;
				focusables[focusedElement].focusGiven;
			}
		} else if (focusedElement == -1) {
			focusedElement = 0;
			focusables[focusedElement].focusGiven;
		} else return -1;
		if (direction > 1) return cast(int)(focusables.length - focusedElement);
		else return cast(int)focusedElement;
	}
	///Passes key events to the focused element when not in text editing mode.
	public void passKey(uint keyCode, ubyte mod) {
		if (focusedElement != -1) {
			focusables[focusedElement].passKey(keyCode, mod);
		}
	}
	//Implementation of `MouseEventReceptor` interface starts here
	///Passes mouse click event
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		lastMousePos = Point(mce.x - position.left, mce.y - position.top);
		foreach (WindowElement we; elements) {
			if (we.getPosition.isBetween(lastMousePos)) {
				lastMouseEventTarget = we;
				mce.x = lastMousePos.x;
				mce.y = lastMousePos.y;
				we.passMCE(mec, mce);
				return;
			}
		}
		StyleSheet ss = getStyleSheet();
		
		if (mce.y < ss.drawParameters["windowHeaderHeight"]) {
			isMoved = true;
		}
		lastMouseEventTarget = null;
	}
	///Passes mouse move event
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		lastMousePos = Point(mme.x - position.left, mme.y - position.top);
		if (isMoved) { 
			relMove(mme.relX, mme.relY);
		} else if (lastMouseEventTarget) {
			mme.x = lastMousePos.x;
			mme.y = lastMousePos.y;
			lastMouseEventTarget.passMME(mec, mme);
		} else {
			foreach (WindowElement we; elements) {
				if (we.getPosition.isBetween(lastMousePos)) {
					lastMouseEventTarget = we;
					mme.x = lastMousePos.x;
					mme.y = lastMousePos.y;
					we.passMME(mec, mme);
					return;
				}
			}
		}
	}
	///Passes mouse scroll event
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (lastMouseEventTarget) {
			lastMouseEventTarget.passMWE(mec, mwe);
		}
	}
}

