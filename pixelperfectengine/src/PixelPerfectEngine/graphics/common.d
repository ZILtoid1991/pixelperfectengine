/*
 * Copyright (c) 2015-2017, by Laszlo Szeremi, under Boost license
 *
 * Pixel Perfect Engine, graphics.common module
 */

module PixelPerfectEngine.graphics.common;

//public import CPUblit.colorspaces;

/**
 * Represents a box on a 2D field.
 */
public struct Coordinate{
	public int left, top, right, bottom;
	@nogc this(int left, int top, int right, int bottom){
		this.left=left;
		this.top=top;
		this.right=right;
		this.bottom=bottom;
	}
	/**
	 * Returns the width of the represented box.
	 */
	public @property @nogc @safe nothrow pure int width() const{
		return right-left;
	}
	/**
	 * Returns the height of the represented box.
	 */
	public @property @nogc @safe nothrow pure int height() const{
		return bottom-top;
	}
	/**
	 * Returns the area of the represented box.
	 */
	public @property @nogc @safe nothrow pure size_t area() const{
		return width * height;
	}
	/**
	 * Moves the box to the given position.
	 */
	public @nogc void move(int x, int y){
		right = x + width();
		bottom = y + height();
		left = x;
		top = y;
	}
	/**
	 * Moves the box by the given values.
	 */
	public @nogc void relMove(int x, int y){
		left = left + x;
		right = right + x;
		top = top + y;
		bottom = bottom + y;
	}
	/**
	 * Returns a string with the coordinates that is useful for debugging
	 */
	public string toString() const{
		import PixelPerfectEngine.system.etc;
		import std.conv;
		/*return "Coordinate: Left: 0x" ~ intToHex(left, 8) ~ " Top: 0x" ~ intToHex(top, 8) ~ " Right: 0x" ~ intToHex(right, 8) ~ " Bottom: 0x" ~ intToHex(bottom, 8) ~
				" Width: 0x" ~ intToHex(width(), 8) ~ " Height: 0x" ~ intToHex(height(), 8);*/
		return "Coordinate: Left: " ~ to!string(left) ~ " Top: " ~ to!string(top) ~ " Right: " ~ to!string(right) ~
				" Bottom: " ~ to!string(bottom) ~ " Width: " ~ to!string(width()) ~ " Height: " ~ to!string(height());
	}
}
/**
 * Defines polygons for sprite transformation (eg. scaling, rotation).
 */
public struct Quad{
	public int midX, midY;		///Defines the midpoint to reduce the need for precision. Corners are referenced to this point
	public float cornerAX, cornerAY, cornerAZ;	///Upper-left corner mapping
	public float cornerBX, cornerBY, cornerBZ;	///Upper-right corner mapping
	public float cornerCX, cornerCY, cornerCZ;	///Lower-left corner mapping
	public float cornerDX, cornerDY, cornerDZ;	///Lower-right corner mapping
}
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
}
//alias Pixel32Bit Color;
