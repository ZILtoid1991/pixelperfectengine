/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.interfaces module
 */

module pixelperfectengine.concrete.interfaces;

public import pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.bitmap;
public import pixelperfectengine.graphics.common;
public import pixelperfectengine.graphics.text;

public import pixelperfectengine.concrete.elements.base;
public import pixelperfectengine.concrete.popup.base;

public import pixelperfectengine.system.input.types;
public import iota.window.types : StandardCursors;

/+/**
 * Checkbox interface.
 */
public interface ICheckBox {
	///Returns whether the object is checked.
	public @property bool isChecked() @safe pure @nogc nothrow const;
	///Sets the object to checked position and returns the new state.
	public bool check() @trusted;
	///Sets the object to unchecked position and returns the new state.
	public bool unCheck() @trusted;
}+/
/**
 * Radio button interface. Can be used to implement radio button style behavior on almost any component that implements this interface.
 */
public interface IRadioButton {
	/**
	 * If the radio button is pressed, then it sets to unpressed. Does nothing otherwise.
	 */
	public void latchOff() @trusted;
	/**
	 * Sets the radio button into its pressed state.
	 */
	public void latchOn() @trusted;
	/**
	 * Sets the group of the radio button.
	 */
	public void setGroup(IRadioButtonGroup group) @safe @property;
	/**
	 * Workaround the stupid issue of object.opEquals having to be `@system inpure throw`.
	 * The @gc would be fine still.
	 *
	 * Hey DLang foundation! Don't be cowards and commit to some meaningful changes!
	 */
	public bool equals(IRadioButton rhs) @safe pure @nogc nothrow const;
	/**
	 * Returns the assigned value of the radio button.
	 */
	public string value() @property @safe @nogc pure nothrow const;
}
/**
 * Implements the basis of a radio button group.
 */
public interface IRadioButtonGroup {
	/**
	 * Adds a radio button to the group.
	 */
	public void add(IRadioButton rg) @safe;
	/**
	 * Removes a radio button from the group.
	 */
	public void remove(IRadioButton rg) @safe;
	/**
	 * Groups receive latch signals here.
	 */
	public void latch(IRadioButton sender) @safe;
}
/**
 * Implements the frontend of a drawable canvas, primarily for GUI elements.
 * Used to avoid using individual bitmaps for each elements.
 * Colors are mostly limited to 256 by the `ubyte` type. However certain window types will enable more.
 */
public interface Canvas {
	///Draws a line.
	public void drawLine(Point from, Point to, ubyte color) @trusted;
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted;
	///Draws an empty rectangle.
	public void drawBox(Box target, ubyte color) @trusted;
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Box target, ubyte[] pattern) @trusted;
	///Draws a filled rectangle with a specified color.
	public void drawFilledBox(Box target, ubyte color) @trusted;
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted;
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Box slice) @trusted;
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Box target, ABitmap pattern) @trusted;
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Box target, ABitmap pattern) @trusted;
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Box target, ubyte color) @trusted;
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted;
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Box target, Text text, Point offset) @trusted;
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Box target, Text text, Point offset) @trusted;
	///Clears the area within the target
	public void clearArea(Box target) @trusted;
}
/**
 * TODO: Use this for implement tabbing and etc.
 */
public interface Focusable {
	///Called when an object receives focus.
	public void focusGiven();
	///Called when an object loses focus.
	public void focusTaken();
	///Cycles the focus on a single element.
	///Returns -1 if end is reached, or the number of remaining elements that
	///are cycleable in the direction.
	public int cycleFocus(int direction);
	///Passes key events to the focused element when not in text editing mode.
	public void passKey(uint keyCode, ubyte mod);
}
/**
 * Implements the 
 */
public interface ElementContainer : PopUpHandler, Canvas {
	/**
	 * Returns the absolute position of the element.
	 */
	public Box getAbsolutePosition(WindowElement sender);
	/**
	 * Gives focus to the element if applicable
	 */
	public void requestFocus(WindowElement sender);
	/**
	 * Sets the cursor to the given type on request.
	 */
	public void requestCursor(StandardCursors type);
	public void updateOutput(WindowElement sender);
}
/**
 * Implemented by any object that can store stylesheets.
 */
public interface StyleSheetContainer {
	/**
	 * Returns the stylesheet stored by the object.
	 */
	public StyleSheet getStyleSheet();
	public int[2] getRasterSizes();
}
/**
 * Implements mouse event passing.
 */
public interface MouseEventReceptor {
	///Passes mouse click event
	public void passMCE(MouseEventCommons mec, MouseClickEvent mce);
	///Passes mouse move event
	public void passMME(MouseEventCommons mec, MouseMotionEvent mme);
	///Passes mouse scroll event
	public void passMWE(MouseEventCommons mec, MouseWheelEvent mwe);
}
/**
 * Implements identification of small buttons.
 */
public interface ISmallButton {
	///Returns true if element is in small button capable and is the supplied height.
	public bool isSmallButtonHeight(int height);
	///Returns true if left side justified, false otherwise.
	public bool isLeftSide() @nogc @safe pure nothrow const;
	///Sets the small button to the left side if true.
	public bool isLeftSide(bool val) @nogc @safe pure nothrow;
}
/**
 * Defines functions for pop up handling.
 */
public interface PopUpHandler : StyleSheetContainer {
	/**
	 * Puts a PopUpElement on the GUI.
	 */
	public void addPopUpElement(PopUpElement p);
	/**
	 * Puts a PopUpElement on the GUI at the given position.
	 */
	public void addPopUpElement(PopUpElement p, int x, int y);
	/** 
	 * Ends the popup session and closes all popups.
	 */
	public void endPopUpSession(PopUpElement p);
	/**
	 * Closes a single popup element.
	 */
	public void closePopUp(PopUpElement p);
	public void updateOutput(PopUpElement p);
}
