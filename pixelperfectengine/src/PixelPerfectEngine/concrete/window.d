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
	alias FocusableSet = LinkedList!(Focusable, false, "a is b");//alias FocusableSet = LinkedList!(Focusable, false, "cmpObjPtr(a, b)");
	alias WESet = LinkedList!(WindowElement, false, "a is b");//alias WESet = LinkedList!(WindowElement, false, "cmpObjPtr(a, b)");
	alias SBSet = LinkedList!(ISmallButton, false, "a is b");//alias SBSet = LinkedList!(ISmallButton, false, "cmpObjPtr(a, b)");
	alias CWSet = LinkedList!(Window, false, "a is b");//alias CWSet = LinkedList!(Window, false, "cmpObjPtr(a, b)");
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
	public void delegate()			onClose;		///Called when the window is closed
	public static void delegate() 	onDrawUpdate;	///Called if not null after every draw update
	/**
	 * Custom constructor. "size" sets both the initial position and the size of the window.
	 * Buttons in the header can be set through the `smallButtons` parameter
	 */
	public this(Box size, Text title, ISmallButton[] smallButtons, StyleSheet customStyle = null) {
		position = size;
		output = new BitmapDrawer(position.width, position.height);
		this.title = title;
		this.customStyle = customStyle;
		foreach (key; smallButtons) {
			addHeaderButton(key);
		}
		focusedElement = -1;
	}
	///Ditto
	public this(Box size, dstring title, ISmallButton[] smallButtons, StyleSheet customStyle = null) {
		this(size, new Text(title, getStyleSheet().getChrFormatting("windowHeader")), smallButtons, customStyle);
	}
	/**
	 * Default constructor. "size" sets both the initial position and the size of the window.
	 * Adds a close button to the header.
	 */
	public this(Box size, Text title, StyleSheet customStyle = null) {
		position = size;
		output = new BitmapDrawer(position.width(), position.height());
		this.title = title;
		this.customStyle = customStyle;
		SmallButton closeButton = closeButton(customStyle is null ? globalDefaultStyle : customStyle);
		closeButton.onMouseLClick = &close;
		addHeaderButton(closeButton);
		focusedElement = -1;
	}
	///Ditto
	public this(Box size, dstring title, StyleSheet customStyle = null) {
		this(size, new Text(title, getStyleSheet().getChrFormatting("windowHeader")), customStyle);
	}
	/**
	 * Returns the window's position.
	 */
	public Box getPosition() @nogc @safe pure nothrow const {
		return position;
	}
	/**
	 * Sets the new position for the window.
	 */
	public Box setPosition(Box newPos) {
		position = newPos;
		if (output.output.width != position.width || output.output.height != position.height) {
			output = new BitmapDrawer(position.width, position.height);
			draw();
		}
		return position;
	}
	/**
	 * If the current window doesn't contain a custom StyleSheet, it gets from it's parent.
	 */
	public StyleSheet getStyleSheet() @safe {
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
		we.setParent(this);
		elements.put(we);
		focusables.put(we);
		we.draw();
	}
	/**
	 * Removes the WindowElement if 'we' is found within its ranges, does nothing otherwise.
	 */
	public void removeElement(WindowElement we) {
		synchronized {
			//we.setParent(null);
			elements.removeByElem(we);
			focusables.removeByElem(we);
		}
		draw();
	}
	/**
	 * Adds a smallbutton to the header.
	 */
	public void addHeaderButton(ISmallButton sb) {
		const int headerHeight = getStyleSheet().drawParameters["WindowHeaderHeight"];
		if (!sb.isSmallButtonHeight(headerHeight)) throw new Exception("Wrong SmallButton height.");
		
		int left, right = position.width;
		foreach (ISmallButton key; smallButtons) {
			if (key.isLeftSide) left += headerHeight;
			else right -= headerHeight;
		}
		Box b;
		if (sb.isLeftSide) 
			b = Box(left, 0, left + headerHeight, headerHeight);
		else
			b = Box(right - headerHeight, 0, right, headerHeight);
		WindowElement we = cast(WindowElement)sb;
		we.setParent(this);
		we.setPosition(b);

		smallButtons.put(sb);
	}
	/**
	 * Removes a smallbutton from the header.
	 */
	public void removeHeaderButton(ISmallButton sb) {
		smallButtons.removeByElem(sb);
		elements.removeByElem(cast(WindowElement)sb);
		drawHeader();
	}
	/**
	 * Draws the window. Intended to be used by the WindowHandler.
	 */
	public void draw(bool drawHeaderOnly = false) {
		if(output.output.width != position.width || output.output.height != position.height) {
			output = new BitmapDrawer(position.width(), position.height());
			handler.refreshWindow(this);
		}
		
		//drawing the header
		drawHeader();
		if(drawHeaderOnly)
			return;
		StyleSheet ss = getStyleSheet();
		const Box bodyarea = Box(0, ss.drawParameters["WindowHeaderHeight"], position.width - 1, position.height - 1);
		drawFilledBox(bodyarea, ss.getColor("window"));
		drawLine(bodyarea.cornerUL, bodyarea.cornerLL, ss.getColor("windowascent"));
		drawLine(bodyarea.cornerUL, bodyarea.cornerUR, ss.getColor("windowascent"));
		drawLine(bodyarea.cornerLL, bodyarea.cornerLR, ss.getColor("windowdescent"));
		drawLine(bodyarea.cornerUR, bodyarea.cornerLR, ss.getColor("windowdescent"));

		foreach (WindowElement we; elements) {
			we.draw();
		}
		
	}
	/**
	 * Draws the header.
	 */
	protected void drawHeader() {
		StyleSheet ss = getStyleSheet();
		const int headerHeight = ss.drawParameters["WindowHeaderHeight"];
		Box headerArea = Box(0, 0, position.width - 1, headerHeight - 1);

		foreach (ISmallButton sb; smallButtons) {
			if (sb.isLeftSide) headerArea.left += headerHeight;
			else headerArea.right -= headerHeight;
			WindowElement we = cast(WindowElement)sb;
			we.draw;
		}
		
		if (active) {
			drawFilledBox(headerArea, ss.getColor("WHAtop"));
			drawLine(headerArea.cornerUL, headerArea.cornerLL, ss.getColor("WHAascent"));
			drawLine(headerArea.cornerUL, headerArea.cornerUR, ss.getColor("WHAascent"));
			drawLine(headerArea.cornerLL, headerArea.cornerLR, ss.getColor("WHAdescent"));
			drawLine(headerArea.cornerUR, headerArea.cornerLR, ss.getColor("WHAdescent"));
		} else {
			drawFilledBox(headerArea, ss.getColor("window"));
			drawLine(headerArea.cornerUL, headerArea.cornerLL, ss.getColor("windowascent"));
			drawLine(headerArea.cornerUL, headerArea.cornerUR, ss.getColor("windowascent"));
			drawLine(headerArea.cornerLL, headerArea.cornerLR, ss.getColor("windowdescent"));
			drawLine(headerArea.cornerUR, headerArea.cornerLR, ss.getColor("windowdescent"));
		}
		drawTextSL(headerArea, title, Point(0,0));
	}
	///Returns true if the window is focused
	public @property bool active() @safe @nogc pure nothrow {
		return flags & IS_ACTIVE;
	}
	///Sets the IS_ACTIVE flag to the given value
	protected @property bool active(bool val) @safe {
		if (val) {
			flags |= IS_ACTIVE;
			title.formatting = getStyleSheet().getChrFormatting("windowHeader");
		} else {
			flags &= ~IS_ACTIVE;
			title.formatting = getStyleSheet().getChrFormatting("windowHeaderInactive");
		}
		return active();
	}
	///Returns whether the window is moved or not
	public @property bool isMoved() @safe @nogc pure nothrow {
		return flags & IS_MOVED ? true : false;
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
		drawHeader();
	}
	///Ditto
	public void setTitle(dstring s) @trusted {
		title.text = s;
		drawHeader();
	}
	///Returns the title of the window
	public Text getTitle() @safe @nogc pure nothrow {
		return title;
	}
	/**
	 * Closes the window by calling the WindowHandler's closeWindow function.
	 */
	public void close(Event ev) {
		close();
	}
	///Ditto
	public void close() {
		if (onClose !is null) onClose();
		if (parent !is null) parent.removeChildWindow(this);
		handler.closeWindow(this);
	}
	/**
	 * Adds a WindowHandler to the window.
	 */
	public void addHandler(WindowHandler wh) @nogc @safe pure nothrow {
		handler = wh;
	}
	
	public Coordinate getAbsolutePosition(WindowElement sender) {
		Box p = sender.getPosition();
		p.relMove(position.left, position.top);
		return p;
	}
	/**
	 * Moves the window to the exact location.
	 */
	public void move(const int x, const int y) {
		position.move(x,y);
		handler.updateWindowCoord(this);
	}
	/**
	 * Moves the window by the given values.
	 */
	public void relMove(const int x, const int y) {
		position.relMove(x,y);
		handler.updateWindowCoord(this);
	}
	/**
	 * Sets the size of the window, also issues a redraw.
	 */
	public void resize(const int width, const int height) {
		position.right = position.left + width;
		position.bottom = position.top + height;
		draw();
		handler.refreshWindow(this);
	}
	/**
	 * Returns the outputted bitmap.
	 * Can be overridden for 32 bit outputs.
	 */
	public @property ABitmap getOutput() @nogc @safe pure nothrow {
		return output.output;
	}
	/**
	 * Gives focus to the windowelement requesting it.
	 */
	public void requestFocus(WindowElement sender) {
		if (focusables.has(sender)) {
			try {
				if (focusedElement != -1)
					focusables[focusedElement].focusTaken();
				Focusable f = cast(Focusable)(sender);
				focusedElement = focusables.which(f);
				focusables[focusedElement].focusGiven();
			} catch (Exception e) {
				debug writeln(e);
			}
		}
	}
	/**
	 * Sets the cursor to the given type on request.
	 */
	public void requestCursor(CursorType type) {
		handler.setCursor(type);
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
			handler.closeWindow(w);
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
	public void drawLine(Point from, Point to, ubyte color) @trusted {
		output.drawLine(from, to, color);
	}
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted {
		output.drawLinePattern(from, to, pattern);
	}
	///Draws an empty rectangle.
	public void drawBox(Coordinate target, ubyte color) @trusted {
		output.drawBox(target, color);
	}
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Coordinate target, ubyte[] pattern) @trusted {
		output.drawBox(target, pattern);
	}
	///Draws a filled rectangle with a specified color,
	public void drawFilledBox(Coordinate target, ubyte color) @trusted {
		output.drawFilledBox(target, color);
	}
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted {
		output.bitBLT(target, cast(Bitmap8Bit)source);
	}
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Coordinate slice) @trusted {
		output.bitBLT(target, cast(Bitmap8Bit)source, slice);
	}
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Coordinate target, ABitmap pattern) @trusted {
		output.bitBLTPattern(target, cast(Bitmap8Bit)pattern);
	}
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Coordinate target, ABitmap pattern) @trusted {
		output.xorBitBLT(target, cast(Bitmap8Bit)pattern);
	}
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Coordinate target, ubyte color) @trusted {
		output.xorBitBLT(target, color);
	}
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted {

	}
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Coordinate target, Text text, Point offset) @trusted {
		output.drawSingleLineText(target, text, offset.x, offset.y);
	}
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Coordinate target, Text text, Point offset) @trusted {
		output.drawMultiLineText(target, text, offset.x, offset.y);
	}
	///Clears the area within the target
	public void clearArea(Coordinate target) @trusted {
		output.drawFilledBox(target, getStyleSheet.getColor("window"));
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
			focusables[focusedElement].focusTaken;
			focusedElement = -1;
		}
		if (lastMouseEventTarget) {
			lastMouseEventTarget.focusTaken();
			lastMouseEventTarget = null;
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
				focusables[focusedElement].focusTaken;
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
		if (!isMoved) {
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
			foreach (ISmallButton sb; smallButtons) {
				WindowElement we = cast(WindowElement)sb;
				if (we.getPosition.isBetween(lastMousePos)) {
					lastMouseEventTarget = we;
					mce.x = lastMousePos.x;
					mce.y = lastMousePos.y;
					we.passMCE(mec, mce);
					return;
				}
			}
			const int headerHeight = getStyleSheet().drawParameters["WindowHeaderHeight"];
			if (lastMousePos.y < headerHeight) {
				isMoved = true;
				handler.initDragEvent(this);
			}
			lastMouseEventTarget = null;
		} else if (!mce.state) {
			isMoved = false;
		}
	}
	///Passes mouse move event
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		lastMousePos = Point(mme.x - position.left, mme.y - position.top);
		if (isMoved) {
			if (mme.buttonState)
				relMove(mme.relX, mme.relY);
			else
				isMoved = false;
		} else if (lastMouseEventTarget) {
			mme.x = lastMousePos.x;
			mme.y = lastMousePos.y;
			lastMouseEventTarget.passMME(mec, mme);
			if (!lastMouseEventTarget.getPosition.isBetween(mme.x, mme.y)) {
				lastMouseEventTarget = null;
			}
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
	/**
	 * Puts a PopUpElement on the GUI.
	 */
	public void addPopUpElement(PopUpElement p) {
		handler.addPopUpElement(p);
	}
	/**
	 * Puts a PopUpElement on the GUI at the given position.
	 */
	public void addPopUpElement(PopUpElement p, int x, int y) {
		handler.addPopUpElement(p, x, y);
	}
	/** 
	 * Ends the popup session and closes all popups.
	 */
	public void endPopUpSession(PopUpElement p) {
		handler.endPopUpSession(p);
	}
	/**
	 * Closes a single popup element.
	 */
	public void closePopUp(PopUpElement p) {
		handler.closePopUp(p);
	}
	///Generates a generic close button
	public static SmallButton closeButton(StyleSheet ss = globalDefaultStyle) {
		const int windowHeaderHeight = ss.drawParameters["WindowHeaderHeight"];
		SmallButton sb = new SmallButton("closeButtonB", "closeButtonA", "close", 
				Box(0,0, windowHeaderHeight - 1, windowHeaderHeight - 1));
		sb.isLeftSide = true;
		if (ss !is globalDefaultStyle)
			sb.customStyle = ss;
		return sb;
	}
}

