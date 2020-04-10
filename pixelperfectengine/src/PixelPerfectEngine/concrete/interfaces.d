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
	public bool state() @safe @property const;
	/**
	 * Sets the group of the radio button.
	 */
	public void setGroup(IRadioButtonGroup group) @safe @property;
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
 * IMPORTANT: This will replace the current drawing methods by version 1.0.0
 * The older method of using multiple BitmapDrawer class will be removed by that point.
 * </br>
 * Implements the frontend of a drawable canvas, primarily for GUI elements.
 * Mostly limited to 256 colors, certain methods (eg. blitting) might enable more.
 */
public interface Canvas {
	///Draws a line.
	public void drawLine(int x0, int y0, int x1, int y1, ubyte color, int lineWidth = 1) @trusted pure;
	///Draws an empty rectangle
	public void drawRectangle(int x0, int y0, int x1, int y1, ubyte color, int lineWidth = 1) @trusted pure;
	///Draws a filled rectangle with a specified color
	public void drawFilledRectangle(Coordinate pos, ubyte color) @trusted pure;
	///Draws a filled rectangle with a specified pattern
	public void drawFilledRectangle(Coordinate pos, Bitmap8Bit pattern) @trusted pure;
	///Fills an area with the specified color
	public void fill(int x0, int y0, ubyte color, ubyte background = 0) @trusted pure;
	///Draws a single line text within the given prelimiter
	public void drawSingleLineText(Coordinate pos, Text text, int offset = 0) @trusted;
	public void bitBLT(int x0, int y0, ABitmap source) @trusted;
	public void bitBLT(int x0, int y0, int x1, int y1, ABitmap source) @trusted;
	public void bitBLT(int x0, int y0, Coordinate slice, ABitmap source) @trusted;
	public void xorBLT(int x0, int y0, int x1, int y1, ubyte color) @trusted;
	public void xorBLT(int x0, int y0, ABitmap source) @trusted;
}
