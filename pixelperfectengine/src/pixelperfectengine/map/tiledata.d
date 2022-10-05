/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, tiledata module
 */
module pixelperfectengine.map.tiledata;

import pixelperfectengine.system.etc;

/**
 * Represents TileInfo that can be embedded into TGA and PNG files, also can be stored in other files.
 */
public class TileInfo {
	static enum char[4] IDENTIFIER_PNG = "tILE";	///Identifier for PNG ancillary chunk
	static enum ushort	IDENTIFIER_TGA = 0xFF00;	///Identifier for TGA developer extension
	/**
	 * Header used for shared information.
	 */
	public struct Header {
	align(1):
		public ubyte	tileWidth;		///Width of each tile
		public ubyte	tileHeight;		///Height of each tile
	}
	/**
	 * Index used for individual info for each tile in the file.
	 */
	align(1) public struct IndexF {
	align(1):
		public wchar	id;				///Identifier for each tile. 16bit value used for some support for unicode text.
		public ubyte	nameLength;		///Length of the namefield.
	}
	/**
	 * Index used for individual info for each tile in memory.
	 */
	public struct IndexM {
		public wchar	id;				///Identifier for each tile. 16bit value used for some support for unicode text.
		private string	_name;			///Name with protection from overflow to more than 255 chars
		/**
		 * Returns the name of the tile.
		 */
		public @property @safe @nogc pure nothrow string name() {
			return _name;
		}
		/**
		 * Sets the name of the tile if val is shorter than 255 characters, then returns the new name.
		 * Returns the old name if not.
		 */
		public @property @safe pure nothrow string name(string val) {
			if(val.length <= ubyte.max)
				_name = val;
			return _name;
		}
	}
	Header header;		///Header that stores all common data.
	IndexM[] indexes;	///Index for each tile in the file, even for "unused" tiles.
	/**
	 * Automatically generates itself from a bytestream.
	 */
	public this(ubyte[] source, uint totalWidth, uint totalHeight) @safe pure {
		header = reinterpretGet!Header(source[0..Header.sizeof]);
		source = source[Header.sizeof..$];
		indexes.length = (totalWidth / header.tileWidth) * (totalHeight / header.tileHeight);
		for(int i; i < indexes.length; i++) {
			const IndexF f = reinterpretGet!IndexF(source[0..IndexF.sizeof]);
			source = source[IndexF.sizeof..$];
			indexes[i].id = f.id;
			if(f.nameLength){
				indexes[i].name = (reinterpretCast!char(source[0..f.nameLength])).idup;
				source = source[f.nameLength..$];
			}
		}
	}
	/**
	 * Creates a new instance from scratch.
	 */
	public this(ubyte tileWidth, ubyte tileHeight, uint totalWidth, uint totalHeight) @safe pure {
		header = Header(tileWidth, tileHeight);
		indexes.length = (totalWidth / header.tileWidth) * (totalHeight / header.tileHeight);
	}
	/**
	 * Serializes itself into a bytestream.
	 */
	public ubyte[] serialize() @safe pure {
		ubyte[] result;
		result ~= reinterpretAsArray!ubyte(header);
		for(int i; i < indexes.length; i++) {
			string name = indexes[i].name;
			IndexF f = IndexF(indexes[i].id, cast(ubyte)name.length);
			result ~= reinterpretAsArray!ubyte(f);
			if(name.length)
				result ~= reinterpretCast!ubyte(name.dup);
		}
		return result;
	}
}
