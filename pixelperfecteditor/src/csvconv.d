module csvconv;

/*
 * Converts from and to the TMX CSV map format.
 * Can "force-export" the tiles' palette shifting attributes into a second CSV file (proprietary).
 * NOTE: Importing might fail if names are used for tile elements, if a tile with the same name doesn't exist in the
 * tile list.
 */

import pixelperfectengine.map.mapdata;
import pixelperfectengine.map.mapformat;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.system.exc;
import pixelperfectengine.system.etc : csvParser, stringArrayParser;

import std.stdio;
import std.conv : to;
import std.csv;

/**
 * Defines CSV flags.
 */
enum CSVFlags {
	Horizontal		= 0x80_00_00_00,
	Vertical		= 0x40_00_00_00,
	Diagonal		= 0x20_00_00_00,
	Test			= 0xE0_00_00_00
}
/**
 * Converts a layer's content into CSV data.
 * Throws an exception if an error have been encountered.
 */
public void toCSV(string target, ITileLayer source) @trusted {
	File tf = File(target, "wb");
	MappingElement[] mapping = source.getMapping;
	char[] writeBuf;
	const int mX = source.getMX, mY = source.getMY;
	for (int y ; y < mY ; y++) {
		for (int x ; x < mX ; x++) {
			uint element = mapping[(y * mX) + x].tileID == 0xFFFF ? uint.max : mapping[(y * mX) + x].tileID;
			if (mapping[(y * mX) + x].attributes.horizMirror && mapping[(y * mX) + x].attributes.vertMirror)
				element |= CSVFlags.Diagonal;
			else if (mapping[(y * mX) + x].attributes.horizMirror)
				element |= CSVFlags.Horizontal;
			else if (mapping[(y * mX) + x].attributes.vertMirror)
				element |= CSVFlags.Vertical;
			writeBuf = to!string(element).dup;
			tf.rawWrite(writeBuf);
			writeBuf.length = 0;
		}
		writeBuf = "\n".dup;
		tf.rawWrite(writeBuf);
	}
}
/**
 * Imports a CSV document to a layer.
 * NOTE: Named tiles are not supported.
 */
public void fromCSV(string source, ITileLayer dest, const int width, const int height) @trusted {
	File sf = File(source, "rb");
	char[] input;
	input.length = cast(size_t)sf.size;
	sf.rawRead(input);
	int[] map = stringArrayParser!int(csvParser(input));
	if (width * height != map.length) throw new CSVImportException("Size mismatch error!");
	MappingElement[] nativeMap;
	nativeMap.reserve(map.length);
	foreach (uint e ; map) {
		MappingElement me;
		me.tileID = cast(ushort)(e & ~CSVFlags.Test);
		switch (e & CSVFlags.Test) {
			case CSVFlags.Diagonal:
				me.attributes.horizMirror = true;
				me.attributes.vertMirror = true;
				break;
			case CSVFlags.Horizontal:
				me.attributes.horizMirror = true;
				break;
			case CSVFlags.Vertical:
				me.attributes.vertMirror = true;
				break;
			default: break;
		}
		nativeMap ~= me;
	}
	dest.loadMapping(width, height, nativeMap);
}
/**
 * Thrown on import errors.
 */
public class CSVImportException : PPEException {
	///
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
	///
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}