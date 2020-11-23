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

/**
 * Basic window. All other windows are inherited from this class.
 */
public class Window : ElementContainer {
	protected WindowElement[] 		elements;		///Stores all window elements here
	protected Text					title;			///Title of the window
	protected WindowElement 		draggedElement;	///Used for drag events
	public IWindowHandler 			parent;			///The handler of the window
	//public Bitmap16Bit[int] altStyleBrush;
	protected BitmapDrawer 			output;			///Graphics output of the window
	//public int header;//, sizeX, sizeY;
	protected int 					moveX, moveY;	///Relative x and y coordinates for drag events
	protected bool 					fullUpdate;		///True if window needs full redraw
	protected bool 					isActive;		///True if window is currently active
	protected bool 					headerUpdate;	///True if needs header update
	protected string[] 				extraButtons;	///Contains the icons of the extra buttons. Might be replaced with a WindowElement in the future
	public Coordinate 				position;		///Position of the window
	public StyleSheet 				customStyle;	///Custom stylesheet for this window
	public static StyleSheet 		defaultStyle;	///The default stylesheet for all windows
	public static void delegate() 	onDrawUpdate;	///Called if not null after every draw update
	/**
	 * Standard constructor. "size" sets both the initial position and the size of the window.
	 * Extra buttons are handled from the StyleSheet, currently unimplemented.
	 */
	public this(Coordinate size, Text title, string[] extraButtons = [], StyleSheet customStyle = null) {
		position = size;
		output = new BitmapDrawer(position.width(), position.height());
		this.title = title;
		this.customStyle = customStyle;
		//sizeX = position.width();
		//sizeY = position.height();
		//style = 0;
		//closeButton = 2;
		this.extraButtons = extraButtons;
	}
	///Ditto
	public this(Coordinate size, dstring title, string[] extraButtons = [], StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		this(size, new Text(title, getStyleSheet().getChrFormatting("windowHeader")), extraButtons, customStyle);
	}
	/**
	 * If the current window doesn't contain a custom StyleSheet, it gets from it's parent.
	 */
	public StyleSheet getStyleSheet() {
		if(customStyle is null) {
			if(parent is null) {
				return defaultStyle;
			} else {
				return parent.getStyleSheet();
			}
		} else {
			return customStyle;
		}
	}
	/**
	 * Updates the output of the elements.
	 */
	public void drawUpdate(WindowElement sender) {
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}
	/**
	 * Adds an element to the window.
	 */
	public void addElement(WindowElement we) {
		elements ~= we;
		we.elementContainer = this;
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
	///
	public @property bool active() @safe @nogc pure nothrow {
		return isActive;
	}
	///
	public @property bool active(bool val) @safe @nogc pure nothrow {
		if(val != isActive)
			headerUpdate = true;
		return isActive = val;
	}
	public void setTitle(Text s) @trusted {
		title = s;
		headerUpdate = true;
		drawHeader();
	}
	public void setTitle(dstring s) @trusted {
		title.text = s;
		headerUpdate = true;
		drawHeader();
	}
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
	 * Passes a mouseDragEvent if the user clicked on an element, held down the button, and moved the mouse.
	 */
	public void passMouseDragEvent(int x, int y, int relX, int relY, ubyte button){
		if(draggedElement){
			draggedElement.onDrag(x, y, relX, relY, button);
		}
	}
	/**
	 * Passes a mouseMotionEvent if the user moved the mouse.
	 */
	public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button){

	}
	/**
	 * Closes the window by calling the WindowHandler's closeWindow function.
	 */
	public void close(){
		parent.closeWindow(this);
	}
	/**
	 * Passes the scroll event to the element where the mouse pointer currently stands.
	 */
	public void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; elements){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){

				e.onScroll(x, y, wX, wY);
				return;
			}
		}
	}
	/**
	 * Called if an extra button was pressed.
	 */
	public void extraButtonEvent(int num, ubyte button, int state){

	}
	/**
	 * Passes a keyboard event.
	 */
	public void passKeyboardEvent(wchar c, int type, int x, int y){

	}
	/**
	 * Adds a WindowHandler to the window.
	 */
	public void addParent(IWindowHandler wh){
		parent = wh;
	}
	public void getFocus(){

	}
	public void dropFocus(){

	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return Coordinate(sender.position.left + position.left, sender.position.top + position.top, sender.position.right + 
				position.right, sender.position.bottom + position.bottom);
	}
	/**
	* Moves the window to the exact location.
	*/
	public void move(int x, int y){
		parent.moveWindow(x, y, this);
		position.move(x,y);
	}
	/**
	* Moves the window by the given values.
	*/
	public void relMove(int x, int y){
		parent.relMoveWindow(x, y, this);
		position.relMove(x,y);
	}
	/**
	 * Sets the height of the window, also issues a redraw.
	 */
	public void setHeight(int y){
		position.bottom = position.top + y;
		draw();
		parent.refreshWindow(this);
	}
	/**
	 * Sets the width of the window, also issues a redraw.
	 */
	public void setWidth(int x){
		position.right = position.left + x;
		draw();
		parent.refreshWindow(this);
	}
	/**
	 * Sets the size of the window, also issues a redraw.
	 */
	public void setSize(int x, int y){
		position.right = position.left + x;
		position.bottom = position.top + y;
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
	 * Clears the background where the element is being drawn.
	 */
	public void clearArea(WindowElement sender){
		Coordinate c = sender.position;
		output.drawFilledRectangle(c.left, c.right, c.top, c.bottom, getStyleSheet.getColor("window"));
	}
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
}

