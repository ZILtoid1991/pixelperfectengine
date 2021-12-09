/*
 * Copyright (c) 2015-2017, by Laszlo Szeremi, under Boost license
 *
 * Pixel Perfect Engine, graphics.common module
 */

module pixelperfectengine.graphics.common;

//public import CPUblit.colorspaces;

import dimage.types : ARGB8888BE;

/**
 * Graphics primitive. Represents a single point on a 2D field.
 */
public struct Point {
	public int x, y;
	/**
	 * Moves the point by the given amount
	 */
	public void relMove (int rX, int rY) @safe @nogc pure nothrow {
		x += rX;
		y += rY;
	}
	public string toString() const {
		import std.conv : to;
		return "x: " ~ to!string(x) ~ " ; y: " ~ to!string(y);
	}
}
/**
 * Graphics primitive. Represents a box on a 2D field.
 * Note on area calculation: The smallest box that can be represented is 1 * 1, as it counts the endpoints as part of the box.
 * This behavior got added with 0.10.0, to standardize various behaviors of the engine, and fix some odd behavior the GUI
 * drawing functions had.
 */
public struct Box {
	public int left, top, right, bottom;
	this(int left, int top, int right, int bottom) @safe pure nothrow @nogc {
		this.left=left;
		this.top=top;
		this.right=right;
		this.bottom=bottom;
	}
	/**
	 * Returns the width of the represented box.
	 */
	public @property @nogc @safe nothrow pure int width() const {
		return right - left + 1;
	}
	/**
	 * Sets the width of the represented box while keeping the lefthand coordinate.
	 */
	public @property int width(int val) @nogc @safe pure nothrow {
		right = left + val - 1;
		return right - left + 1;
	}
	/**
	 * Returns the height of the represented box.
	 */
	public @property @nogc @safe nothrow pure int height() const {
		return bottom - top + 1;
	}
	/**
	 * Sets the height of the represented box while keeping the top coordinate.
	 */
	public @property int height(int val) @nogc @safe pure nothrow { 
		bottom = top + val - 1;
		return bottom - top + 1;
	}
	/**
	 * Returns the area of the represented box.
	 */
	public @property @nogc @safe nothrow pure size_t area() const {
		return width * height;
	}
	/**
	 * Moves the box to the given position.
	 */
	public void move(int x, int y) @nogc @safe nothrow pure {
		right = x + width();
		bottom = y + height();
		left = x;
		top = y;
	}
	/**
	 * Moves the box by the given values.
	 */
	public void relMove(int x, int y) @nogc @safe nothrow pure {
		left = left + x;
		right = right + x;
		top = top + y;
		bottom = bottom + y;
	}
	/**
	 * Returns true if the given point is between the coordinates.
	 */
	public bool isBetween(int x, int y) @nogc @safe pure nothrow const {
		return (x >= left && x <= right && y >= top && y <= bottom);
	}
	///Ditto
	public bool isBetween(Point p) @nogc @safe pure nothrow const {
		return (p.x >= left && p.x <= right && p.y >= top && p.y <= bottom);
	}
	/**
	 * Operator overloading for scalar values.
	 * `-`: Adds to left and top, substracts from right and bottom. (Shrinks by amount)
	 * `+`: Subtracts from left and top, adds to right and bottom. (Grows by amount)
	 */
	public Box opBinary(string op)(const int rhs) @nogc @safe pure nothrow const {
		static if (op == "-") {
			return Box(left + rhs, top + rhs, right - rhs, bottom - rhs);
		} else static if (op == "+") {
			return Box(left - rhs, top - rhs, right + rhs, bottom + rhs);
		} else static assert(0, "Unsupported operator!");
	}
	///Returns the upper-left corner.
	public @property Point cornerUL() @nogc @safe pure nothrow const {
		return Point(left, top);
	}
	///Returns the upper-right corner.
	public @property Point cornerUR() @nogc @safe pure nothrow const {
		return Point(right, top);
	}
	///Returns the lowew-left corner.
	public @property Point cornerLL() @nogc @safe pure nothrow const {
		return Point(left, bottom);
	}
	///Returns the lower-right corner.
	public @property Point cornerLR() @nogc @safe pure nothrow const {
		return Point(right, bottom);
	}
	///Pads the edges of the given box by the given amounts and returns a new Box.
	public Box pad(const int horiz, const int vert) @nogc @safe pure nothrow const {
		return Coordinate(left + horiz, top + vert, right - horiz, bottom - vert);
	}
	/**
	 * Returns a string with the coordinates that is useful for debugging
	 */
	public string toString() const {
		import pixelperfectengine.system.etc;
		import std.conv;
		/*return "Coordinate: Left: 0x" ~ intToHex(left, 8) ~ " Top: 0x" ~ intToHex(top, 8) ~ " Right: 0x" ~ intToHex(right, 8) ~ " Bottom: 0x" ~ intToHex(bottom, 8) ~
				" Width: 0x" ~ intToHex(width(), 8) ~ " Height: 0x" ~ intToHex(height(), 8);*/
		return "Coordinate: Left: " ~ to!string(left) ~ " Top: " ~ to!string(top) ~ " Right: " ~ to!string(right) ~
				" Bottom: " ~ to!string(bottom) ~ " Width: " ~ to!string(width()) ~ " Height: " ~ to!string(height());
	}
	public static Box bySize(int x, int y, int w, int h) @nogc @safe pure nothrow {
		return Box(x, y, x + w - 1, y + h - 1);
	}
}
alias Coordinate = Box;
/**
 * Defines polygons for sprite transformation (eg. scaling, rotation).
 * Most likely will be removed due to lack of use.
 */
public struct Quad{
	public int midX, midY;		///Defines the midpoint to reduce the need for precision. Corners are referenced to this point
	public float cornerAX, cornerAY, cornerAZ;	///Upper-left corner mapping
	public float cornerBX, cornerBY, cornerBZ;	///Upper-right corner mapping
	public float cornerCX, cornerCY, cornerCZ;	///Lower-left corner mapping
	public float cornerDX, cornerDY, cornerDZ;	///Lower-right corner mapping
}
alias Color = ARGB8888BE;
/+
/**
 * Various representations of color with various accessibility modes.
 * Probably will be replaced with a struct from either CPUBLiT or dimage.
 */
public struct Color{
	union{
		uint raw;	///Raw representation in integer form, also forces the system to align in INT32.
		ubyte[4] colors;	///Normal representation, aliases are used for color naming.
	}
	version(LittleEndian){
		///Returns the alpha channel of the color
		public @nogc @safe @property pure nothrow ubyte alpha() const{ return colors[0]; }
		///Returns the red channel of the color
		public @nogc @safe @property pure nothrow ubyte red() const{ return colors[1]; }
		///Returns the green channel of the color
		public @nogc @safe @property pure nothrow ubyte green() const{ return colors[2]; }
		///Returns the blue channel of the color
		public @nogc @safe @property pure nothrow ubyte blue() const{ return colors[3]; }
		///Sets the alpha channel of the color
		public @nogc @safe @property pure nothrow ubyte alpha(ubyte value) { return colors[0] = value; }
		///Sets the red channel of the color
		public @nogc @safe @property pure nothrow ubyte red(ubyte value) { return colors[1] = value; }
		///Sets the green channel of the color
		public @nogc @safe @property pure nothrow ubyte green(ubyte value) { return colors[2] = value; }
		///Sets the blue channel of the color
		public @nogc @safe @property pure nothrow ubyte blue(ubyte value) { return colors[3] = value; }
	}else{
		///Returns the alpha channel of the color
		public @nogc @safe @property pure nothrow ubyte alpha() const{ return colors[3]; }
		///Returns the red channel of the color
		public @nogc @safe @property pure nothrow ubyte red() const{ return colors[2]; }
		///Returns the green channel of the color
		public @nogc @safe @property pure nothrow ubyte green() const{ return colors[1]; }
		///Returns the blue channel of the color
		public @nogc @safe @property pure nothrow ubyte blue() const{ return colors[0]; }
		///Sets the alpha channel of the color
		public @nogc @safe @property pure nothrow ubyte alpha(ubyte value) { return colors[3] = value; }
		///Sets the red channel of the color
		public @nogc @safe @property pure nothrow ubyte red(ubyte value) { return colors[2] = value; }
		///Sets the green channel of the color
		public @nogc @safe @property pure nothrow ubyte green(ubyte value) { return colors[1] = value; }
		///Sets the blue channel of the color
		public @nogc @safe @property pure nothrow ubyte blue(ubyte value) { return colors[0] = value; }
	}
	/**
	 * Contructs a color from four individual values.
	 */
	public @nogc this(ubyte alpha, ubyte red, ubyte green, ubyte blue) nothrow pure @safe {
		this.alpha = alpha;
		this.red = red;
		this.green = green;
		this.blue = blue;
	}
	/**
	 * Constructs a color from a single 32 bit unsigned integer.
	 */
	public @nogc this(uint val) nothrow pure @safe {
		raw = val;
	}
	/**
	 * Operator overloading for quick math. '*' is alpha-blending, '^' is XOR blitter, '&' is normal "blitter".
	 * Alpha is used from right hand side and kept on left hand side when needed
	 */
	public Color opBinary(string op)(Color rhs){
		static if(op == "+"){
			int r = red + rhs.red, g = green + rhs.green, b = blue + rhs.blue, a = alpha + rhs.alpha;
			return Color(a > 255 ? 255 : cast(ubyte)a, r > 255 ? 255 : cast(ubyte)r, g > 255 ? 255 : cast(ubyte)g, b > 255 ? 255 : cast(ubyte)b);
		}else static if(op == "-"){
			int r = red - rhs.red, g = green - rhs.green, b = blue - rhs.blue, a = alpha - rhs.alpha;
			return Color(a < 0 ? 0 : cast(ubyte)a, r < 0 ? 0 : cast(ubyte)r, g < 0 ? 0 : cast(ubyte)g, b < 0 ? 0 : cast(ubyte)b);
		}else static if(op == "^"){
			return Color(alpha ^ rhs.alpha, red ^ rhs.red, green ^ rhs.green, blue ^ rhs.blue);
		}else static if(op == "&"){
			return rhs.alpha ? rhs : this;
		}else static if(op == "*"){
			return Color(alpha, cast(ubyte)( ( (rhs.red * (1 + rhs.alpha)) + (red * (256 - rhs.alpha)) )>>8 ),
								cast(ubyte)( ( (rhs.green * (1 + rhs.alpha)) + (green * (256 - rhs.alpha)) )>>8 ),
								cast(ubyte)( ( (rhs.blue * (1 + rhs.alpha)) + (blue * (256 - rhs.alpha)) )>>8 ));
		}else static assert(0, "Operator '" ~ op ~ "' not supported!");
	}
	/**
	 * Returns a string for debugging.
	 */
	public string toString() const{
		import PixelPerfectEngine.system.etc;
		return "0x" ~ intToHex(raw, 8);
	}
}+/
//alias Pixel32Bit Color;
