/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.interfaces module
 */

module PixelPerfectEngine.concrete.interfaces;

public import PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.common;
public import PixelPerfectEngine.graphics.text;

/**
 * Checkbox interface.
 */
public interface ICheckBox {
	///Returns whether the object is checked.
	public @property bool isChecked() @safe pure @nogc nothrow const;
	///Sets the object to checked position and returns the new state.
	public bool check() @trusted;
	///Sets the object to unchecked position and returns the new state.
	public bool unCheck() @trusted;
}
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
	 * Returns the current state of the radio button.
	 * True: Pressed.
	 * False: Unpressed.
	 */
	public bool isLatched() @safe @property const;
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
	public void drawLine(Point from, Point to, ubyte color) @trusted pure;
	///Draws a line pattern.
	public void drawLinePattern(Point from, Point to, ubyte[] pattern) @trusted pure;
	///Draws an empty rectangle.
	public void drawBox(Coordinate target, ubyte color) @trusted pure;
	///Draws an empty rectangle with line patterns.
	public void drawBoxPattern(Coordinate target, ubyte[] pattern) @trusted pure;
	///Draws a filled rectangle with a specified color,
	public void drawFilledBox(Coordinate target, ubyte color) @trusted pure;
	///Pastes a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source) @trusted pure;
	///Pastes a slice of a bitmap to the given point using blitter, which threats color #0 as transparency.
	public void bitBLT(Point target, ABitmap source, Coordinate slice) @trusted pure;
	///Pastes a repeated bitmap pattern over the specified area.
	public void bitBLTPattern(Coordinate target, ABitmap pattern) @trusted pure;
	///XOR blits a repeated bitmap pattern over the specified area.
	public void xorBitBLT(Coordinate target, ABitmap pattern) @trusted pure;
	///XOR blits a color index over a specified area.
	public void xorBitBLT(Coordinate target, ubyte color) @trusted pure;
	///Fills an area with the specified color.
	public void fill(Point target, ubyte color, ubyte background = 0) @trusted pure;
	///Draws a single line text within the given prelimiter.
	public void drawTextSL(Coordinate pos, Text text, Point offset) @trusted pure;
	///Draws a multi line text within the given prelimiter.
	public void drawTextML(Coordinate pos, Text text, Point offset) @trusted pure;
}
/**
 * TODO: Use this for implement tabbing and etc.
 */
public interface Focusable {
	///Called when an object receives focus.
	public void focusGiven();
	///Called when an object loses focus.
	public void focusLost();
}