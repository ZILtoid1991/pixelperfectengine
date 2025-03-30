/*
 * Copyright (c) 2015-2017, by Laszlo Szeremi, under Boost license
 *
 * Pixel Perfect Engine, graphics.common module
 */

module pixelperfectengine.graphics.common;

//public import CPUblit.colorspaces;
public import pixelperfectengine.system.exc;
import pixelperfectengine.system.memory;

import dimage.types : RGBA8888;
import bindbc.opengl;

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
	bool opEquals(const Point other) @safe @nogc pure nothrow const {
		return this.x == other.x && this.y == other.y;
	}
	public Point opBinary(string op, R)(const R rhs) @safe @nogc pure nothrow const {
		mixin("return Point(x " ~  op ~ " rhs.x , y " ~ op ~ "rhs.y);");
	}
	public Point opOpAssign(string op, R)(const R rhs) @safe @nogc pure nothrow {
		mixin("x " ~  op ~ "= rhs.x; y " ~ op ~ "= rhs.y;");
		return this;
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
		right = x + width() - 1;
		bottom = y + height() - 1;
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
/**
 * Defines a free-shape quad by its points.
 */
public struct Quad {
	Point topLeft;
	Point topRight;
	Point bottomLeft;
	Point bottomRight;
	public void move(int x, int y) @nogc @safe pure nothrow {
		move(Point(x, y));
	}
	public void move(Point vec) @nogc @safe pure nothrow {
		relMove(vec - topLeft);
	}
	public void relMove(int x, int y) @nogc @safe pure nothrow {
		relMove(Point(x, y));
	}
	public void relMove(Point vec) @nogc @safe pure nothrow {
		topLeft += vec;
		topRight += vec;
		bottomLeft += vec;
		bottomRight += vec;
	}
	public Box boxOf() @nogc @safe pure nothrow {
		Box result;
		result.left = topLeft.x < bottomLeft.x ? topLeft.x : bottomLeft.x;
		result.top = topLeft.y < topRight.y ? topLeft.y : topRight.y;
		result.right = topRight.x < bottomRight.x ? topRight.x : bottomRight.x;
		result.bottom = bottomLeft.y < bottomRight.y ? bottomLeft.y : bottomRight.y;
		return result;
	}
}
/**
 * Defines sprite vertex data.
 * Color channels can be repurposed to pass arbitrary data to the shaders if lighting etc. is not needed.
 * Normal mapping modifiers can be repurposed to pass arbitrary data to the shaders if normal mapping is
 * not needed
 */
public struct SpriteVertex {
	short x;		/// X coordinate of the vertex in pixels on the visible screen.
	short y;		/// Y coordinate of the vertex in pixels on the visible screen.
	ushort s;		/// X coordinate for texture mapping in pixels.
	ushort t;		/// y coordinate for texture mapping in pixels.
	GraphicsAttrExt attributes;	/// Color and mipmap modifiers.
}
/**
 * Defines Vertex data for tiles.
 * Color channels can be repurposed to pass arbitrary data to the shaders if lighting etc. is not needed.
 * Normal mapping modifiers can be repurposed to pass arbitrary data to the shaders if normal mapping is
 * not needed
 * To Do: Try to somehow optimize some of the per-tile stuff, so they won't be repeated multiple times
 */
public struct TileVertex {
	ubyte row;			/// Row of the visible tilemap.
	ubyte col;			/// Column of the visible tilemap.
	ushort palSel;		/// Palette selector
	PackedTextureMapping ptm;	/// Texture array mapping packed into a single 32 bit value.
	GraphicsAttrExt attributes;	/// Color and mipmap modifiers.
}
/**
 * Defines 2D texture array mapping data packed into a 32 bit value.
 */
public struct PackedTextureMapping {
	uint base;
	this (uint s, uint t, uint u) @nogc @safe pure nothrow {
		this.s = s;
		this.t = t;
		this.u = u;
	}
	ushort s() @nogc @safe pure nothrow const {
		return cast(ushort)(base & 0x0F_FF);
	}
	ushort t() @nogc @safe pure nothrow const {
		return cast(ushort)((base>>12) & 0x0F_FF);
	}
	ubyte u() @nogc @safe pure nothrow const {
		return cast(ubyte)(base>>24);
	}
	ushort s(uint val) @nogc @safe pure nothrow {
		base &= 0xFF_FF_F0_00;
		base |= val & 0x0F_FF;
		return cast(ushort)(base & 0x3F_FF);
	}
	ushort t(uint val) @nogc @safe pure nothrow {
		base &= 0xFF_00_0F_FF;
		base |= (val & 0x0F_FF)<<12;
		return cast(ushort)((base>>12) & 0x0F_FF);
	}
	ubyte u(uint val) @nogc @safe pure nothrow {
		base &= 0x00_FF_FF_FF;
		base |= val<<24;
		return cast(ubyte)(base>>24);
	}
}
/**
 * Graphics attribute extensions for sprites, tiles, etc.
 * At 128, r, g and b will normally do nothing, below it apply multiply (shadow), above it apply screen (highlight) effects.
 * (May depend on shader implementation)
 * `a` just controls the alpha channel for the given point.
 * `lX` and `lY` control the normal mapping effect.
 */
public struct GraphicsAttrExt {
	ubyte r = 128;				///Red channel modifier
	ubyte g = 128;				///Green channel modifier
	ubyte b = 128;				///Blue channel modifier
	ubyte a = 255;				///Alpha channel modifier
	short lX;					///X normal modifier
	short lY;					///Y normal modifier
}
/**
 * Defines indices for a single polygon (triangle).
 */
public struct PolygonIndices {
	int a;
	int b;
	int c;
}
///Thrown on issues with OpenGL shaders.
public class GLShaderException : PPEException {
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow
			@nogc @safe {
		super(msg, file, line, nextInChain);
	}
}
/**
 * Checks OpenGL shader identified by `shaderID`, throws `GLShaderException` on error.
 */
public void gl_CheckShader(GLuint shaderID) @trusted {
	int infoLogLength;
	glGetShaderiv(shaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
	if (infoLogLength > 0) {
		char[] msg;
		msg.length = infoLogLength + 1;
		glGetShaderInfoLog(shaderID, infoLogLength, null, msg.ptr);
		throw new GLShaderException(cast(string)msg);
	}
}
public char[] gl_CheckShaderNOGC(GLuint shaderID) @trusted @nogc nothrow {
	int infoLogLength;
	glGetShaderiv(shaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
	if (infoLogLength > 0) {
		char[] msg = nogc_newArray!char(infoLogLength + 1);
		glGetShaderInfoLog(shaderID, infoLogLength, null, msg.ptr);
		return msg;
	}
	return null;
}
/**
 * Checks OpenGL program identified by `programID`, throws `GLShaderException` on error.
 */
public void gl_CheckProgram(GLuint programID) @trusted {
	int infoLogLength;
	glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &infoLogLength);
	if (infoLogLength > 0) {
		char[] msg;
		msg.length = infoLogLength + 1;
		glGetProgramInfoLog(programID, infoLogLength, null, msg.ptr);
		throw new GLShaderException(cast(string)msg);
	}
}
public char[] gl_CheckProgramNOGC(GLuint programID) @trusted @nogc nothrow {
	int infoLogLength;
	glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &infoLogLength);
	if (infoLogLength > 0) {
		char[] msg = nogc_newArray!char(infoLogLength + 1);
		glGetProgramInfoLog(programID, infoLogLength, null, msg.ptr);
		return msg;
	}
	return null;
}
///Deprecated: Just use Box instead!
alias Coordinate = Box;
alias Color = RGBA8888;
