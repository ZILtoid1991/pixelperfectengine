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

import document;
import std.stdio;
import std.conv : to;

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
			int element = mapping[(y * mX) + x].tileID == 0xFFFF ? -1 : mapping[(y * mX) + x].tileID;
			if (mapping[(y * mX) + x].attributes.horizMirror && mapping[(y * mX) + x].attributes.vertMirror)
				element |= CSVFlags.Diagonal;
			else if (mapping[(y * mX) + x].attributes.horizMirror)
				element |= CSVFlags.Horizontal;
			else if (mapping[(y * mX) + x].attributes.vertMirror)
				element |= CSVFlags.Vertical;
			writeBuf ~= to!string(element).dup;
			tf.rawWrite(writeBuf);
			writeBuf.length = 0;
			writeBuf = ",".dup;
		}
		writeBuf = "\n".dup;
		tf.rawWrite(writeBuf);
		writeBuf.length = 0;
	}
}
/// Borrowed from Adam D. Ruppe, because the one in phobos is an abomination!
/// Returns the array of csv rows from the given in-memory data (the argument is NOT a filename).
package string[][] readCsv(string data) {
	import std.array;
	data = data.replace("\r\n", "\n");
	data = data.replace("\r", "");

	//auto idx = data.indexOf("\n");
	//data = data[idx + 1 .. $]; // skip headers

	string[] fields;
	string[][] records;

	string[] current;

	int state = 0;
	string field;
	foreach(c; data) {
		tryit: switch(state) {
			default: assert(0);
			case 0: // normal
				if(c == '"')
					state = 1;
				else if(c == ',') {
					// commit field
					current ~= field;
					field = null;
				} else if(c == '\n') {
					// commit record
					current ~= field;

					records ~= current;
					current = null;
					field = null;
				} else
					field ~= c;
			break;
			case 1: // in quote
				if(c == '"') {
					state = 2;
				} else
					field ~= c;
			break;
			case 2: // is it a closing quote or an escaped one?
				if(c == '"') {
					field ~= c;
					state = 1;
				} else {
					state = 0;
					goto tryit;
				}
		}
	}

	if(field !is null)
		current ~= field;
	if(current !is null)
		records ~= current;


	return records;
}
/**
 * Imports a CSV document to a layer.
 * NOTE: Named tiles are not supported.
 */
public void fromCSV(string source, MapDocument dest) @trusted {
	File sf = File(source, "rb+");
	MappingElement[] nativeMap;
	int width, height;
	char[] readbuffer;
	readbuffer.length = cast(size_t)sf.size();
	sf.rawRead(readbuffer);
	string[][] parsedData = readCsv(readbuffer.idup);
	width = cast(int)parsedData[0].length;
	height = cast(int)parsedData.length;
	nativeMap.reserve(width * height);
	foreach (string[] line; parsedData) {
		foreach (string entry; line) {
			int tile = to!int(entry);
			MappingElement elem;
			switch (tile & CSVFlags.Test) {
				case CSVFlags.Horizontal:
					elem.attributes.horizMirror = true;
					break;
				case CSVFlags.Vertical:
					elem.attributes.vertMirror = true;
					break;
				case CSVFlags.Diagonal:
					elem.attributes.horizMirror = true;
					elem.attributes.vertMirror = true;
					break;
				default:
					break;
			}
			elem.tileID = cast(wchar)(tile & ushort.max);
			nativeMap ~= elem;
		}
	}
	dest.assignImportedTilemap(nativeMap, width, height);
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
