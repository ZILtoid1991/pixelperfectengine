/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.text module
 */

module pixelperfectengine.graphics.text;

public import pixelperfectengine.graphics.fontsets;
public import pixelperfectengine.graphics.bitmap;

import xml = undead.xml;
import std.utf : toUTF32, toUTF8;
import std.conv : to;
import std.algorithm : countUntil;
import std.typecons : BitFlags;

/**
 * Implements a formatted text chunk, that can be serialized in XML form.
 * Has a linked list structure to easily link multiple chunks after each other.
 */
public class TextTempl(BitmapType = Bitmap8Bit) {
	enum Flags : ubyte {
		newLine			=	1 << 0,
		newParagraph	=	1 << 1,
	}
	protected dchar[]		_text;			///The text to be displayed
	public CharacterFormattingInfo!BitmapType 	formatting;	///The formatting of this text block
	public TextTempl!BitmapType	next;			///The next piece of formatted text block
	public int				frontTab;		///Space before the text chunk in pixels. Can be negative.
	public BitmapType		icon;			///Icon inserted in front of the text chunk.
	public byte				iconOffsetX;	///X offset of the icon if any
	public byte				iconOffsetY;	///Y offset of the icon if any
	public byte				iconSpacing;	///Spacing after the icon if any
	public BitFlags!Flags	flags;			///Text flags
	/**
	 * Creates a unit of formatted text from the supplied data.
	 */
	public this(dstring text, CharacterFormattingInfo!BitmapType formatting, TextTempl!BitmapType next = null, 
			int frontTab = 0, BitmapType icon = null) @safe pure nothrow {
		this.text = text;
		this.formatting = formatting;
		this.next = next;
		this.frontTab = frontTab;
		this.icon = icon;
	}
	///Copy CTOR
	public this(TextTempl!BitmapType orig) @safe pure nothrow {
		this.text = orig.text.dup;
		this.formatting = orig.formatting;
		if(orig.next)
			this.next = new TextTempl!BitmapType(orig.next);
		this.frontTab = orig.frontTab;
		this.icon = orig.icon;
		this.iconOffsetX = orig.iconOffsetX;
		this.iconOffsetY = orig.iconOffsetY;
		this.iconSpacing = orig.iconSpacing;
	}
	/**
	 * Returns the text as a 32bit string without the formatting.
	 */
	public dstring toDString() @safe pure nothrow {
		if (next)
			return text ~ next.toDString();
		else
			return text;
	}
	/**
	 * Indexing to refer to child items.
	 * Returns null if the given element isn't available.
	 */
	public Text!BitmapType opIndex(size_t index) @safe pure nothrow {
		if (index) {
			if (next) {
				return next[index - 1];
			} else {
				return null;
			}
		} else {
			return this;
		}
	}
	/**
	 * Returns the character lenght.
	 */
	public @property size_t charLength() @safe pure nothrow @nogc const {
		if (next) return _text.length + next.charLength;
		else return _text.length;
	}
	/**
	 * Removes the character at the given position.
	 * Returns the removed character if within bound, or dchar.init if not.
	 */
	public dchar removeChar(size_t pos) @safe pure {
		import std.algorithm.mutation : remove;
		void _removeChar() @safe pure {
			if(pos == 0) {
				_text = _text[1..$];
			} else if(pos == _text.length - 1) {
				if(_text.length) _text.length = _text.length - 1;
			} else {
				_text = _text[0..pos] ~ _text[(pos + 1)..$];
			}
		}
		if(pos < _text.length) {
			const dchar result = _text[pos];
			_removeChar();/+text = text.remove(pos);+/
			return result;
		} else if(next) {
			return next.removeChar(pos - _text.length);
		} else return dchar.init;
	}
	/**
	 * Removes a range of characters described by the begin and end position.
	 */
	public void removeChar(size_t begin, size_t end) @safe pure {
		for (size_t i = begin ; i < end ; i++) {
			removeChar(begin);
		}
	}
	/**
	 * Inserts a given character at the given position.
	 * Return the inserted character if within bound, or dchar.init if position points to a place where it
	 * cannot be inserted easily.
	 */
	public dchar insertChar(size_t pos, dchar c) @trusted pure {
		import std.array : insertInPlace;
		if(pos <= _text.length) {
			_text.insertInPlace(pos, c);
			return c;
		} else if(next) {
			return next.insertChar(pos - _text.length, c);
		} else return dchar.init;
	}
	/**
	 * Overwrites a character at the given position.
	 * Returns the original character if within bound, or or dchar.init if position points to a place where it
	 * cannot be inserted easily.
	 */
	public dchar overwriteChar(size_t pos, dchar c) @safe pure {
		if(pos < _text.length) {
			const dchar orig = _text[pos];
			_text[pos] = c;
			return orig;
		} else if(next) {
			return next.overwriteChar(pos - _text.length, c);
		} else if (pos == _text.length) {
			_text ~= c;
			return c;
		} else return dchar.init;
	}
	/**
	 * Returns a character from the given position.
	 */
	public dchar getChar(size_t pos) @safe pure {
		if(pos < _text.length) {
			return _text[pos];
		} else if(next) {
			return next.getChar(pos - _text.length);
		} else return dchar.init;
	}
	/**
	 * Returns the width of the current text block in pixels.
	 */
	public int getBlockWidth() @safe pure nothrow {
		auto f = font;
		dchar prev;
		int localWidth = frontTab;
		foreach (c; _text) {
			localWidth += f.chars(c).xadvance + formatting.getKerning(prev, c);
			prev = c;
		}
		if(icon) localWidth += iconOffsetX + iconSpacing;
		return localWidth;
	}
	/**
	 * Returns the width of the text chain in pixels.
	 */
	public int getWidth() @safe pure nothrow {
		auto f = font;
		dchar prev;
		int localWidth = frontTab;
		foreach (c; _text) {
			localWidth += f.chars(c).xadvance + formatting.getKerning(prev, c);
			prev = c;
		}
		if(icon) localWidth += iconOffsetX + iconSpacing;
		if(next) return localWidth + next.getWidth();
		else return localWidth;
	}
	/**
	 * Returns the width of a slice of the text chain in pixels.
	 */
	public int getWidth(sizediff_t begin, sizediff_t end) @safe pure {
		if(end > _text.length && next is null) 
			throw new Exception("Text boundary have been broken!");
		int localWidth;
		if (!begin) {
			localWidth += frontTab;
			if (icon)
				localWidth += iconOffsetX + iconSpacing;
		}
		if (begin < _text.length) {
			auto f = font;
			dchar prev;
			foreach (c; _text[begin..end]) {
				localWidth += f.chars(c).xadvance + formatting.getKerning(prev, c);
				prev = c;
			}
		}
		begin -= _text.length;
		end -= _text.length;
		if (begin < 0) begin = 0;
		if (next && end > 0) return localWidth + next.getWidth(begin, end);
		else return localWidth;
	}
	/**
	 * Returns the number of characters fully offset by the amount of pixel.
	 */
	public int offsetAmount(int pixel) @safe pure nothrow {
		int chars;
		dchar prev;
		while (chars < _text.length && pixel - font.chars(_text[chars]).xadvance + formatting.getKerning(prev, _text[chars]) > 0) {
			pixel -= font.chars(_text[chars]).xadvance + formatting.getKerning(prev, _text[chars]);
			prev = _text[chars];
			chars++;
		}
		if (chars == _text.length && pixel > 0 && next) 
			chars += next.offsetAmount(pixel);
		return chars;
	}
	/**
	 * Returns the used font type.
	 */
	public Fontset!BitmapType font() @safe @nogc pure nothrow {
		return formatting.font;
	}
	///Text accessor
	public @property dstring text() @safe pure nothrow {
		return _text.idup;
	}
	///Text accessor
	public @property dstring text(dstring val) @safe pure nothrow {
		_text = val.dup;
		return val;
	}
}
alias Text = TextTempl!Bitmap8Bit;
