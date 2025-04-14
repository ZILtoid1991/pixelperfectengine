module pixelperfectengine.map.mapdata;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map module
 */
import std.stdio;
import std.file;
import std.conv;
import std.base64;
import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.layers;
import pixelperfectengine.system.exc;
import pixelperfectengine.system.etc;
import core.stdc.stdlib;
import core.stdc.stdio;
import std.string;

version(Windows){
	import core.sys.windows.windows;
	import std.windows.syserror;
}else{
	import core.stdc.errno;
}

public import pixelperfectengine.system.exc;

/**
 * Contains the very basic data for the map binary file (*.mbf).
 * Length of the map is calculated as `length = sizeX * sizeY`, all words are 32 bits long, so size of map in bytes
 * equals `mapSize = length * 4`, and header should be 12 bytes in size.
 * Maps are always starting in the top-left corner of their tile layers.
 */
public struct MapDataHeader {
	public uint flags;		///Stores additional data about the binary map file as a boolean array. Bit 24-31 are user definable.
	public int sizeX;		///width of the map
	public int sizeY;		///Height of the map
	public enum RegisteredFlags {
		UD_PriorityField	=	1<<0,	///Priority field contains user-defined data
		UD_PalShiftField	=	1<<1,	///Palette-shift field contains user defined data
		Bit10AxisSwitch		=	1<<2,	///Bit 10 (bit 0 of priority field) switches X and Y axes
		NewFormat			=	1<<3,	///Use of new format
		GrAttrExtPres		=	1<<4,	///Graphics attribute extension field is present
		LogicAttrExtPres	=	1<<0,	///Logic attribute extension field is present
		RLEEnc				=	1<<8,	///Run length encoding is used for compression
		LZWCmpr				=	1<<9,	///LZW compression
		ZLib				=	1<<10,	///ZLib compression
		Zstd				=	1<<11,	///zstd compression

		LogicAttrExtSizeMask=	0x00_03_00_00,
		LogicAttrExtSize8	=	0x00_00_00_00,
		LogicAttrExtSize16	=	0x00_01_00_00,
		LogicAttrExtSize32	=	0x00_02_00_00,
		LogicAttrExtSize64	=	0x00_03_00_00,
	}
	/**
	 * Creates a MapDataHeader with the supplied parameters.
	 * Params:
	 *   sizeX = Width of the map.
	 *   sizeY = Height of the map.
	 */
	this(int sizeX, int sizeY) {
		flags = RegisteredFlags.NewFormat;
		this.sizeX = sizeX;
		this.sizeY = sizeY;
	}
}

/**
 * Saves a map to an external file.
 * Will be deprecated soon.
 */
public deprecated void saveMapFile(MapDataHeader* header, ref MappingElement[] map, string name) {
	FILE* outputStream = fopen(toStringz(name), "wb");
	if(outputStream is null){
		import std.conv;
		version(Windows){
			DWORD errorCode = GetLastError();
		}else version(Posix){
			int errorCode = errno;
		}
		throw new FileAccessException("File access error! Error number: " ~ to!string(errorCode));
	}

	fwrite(cast(void*)header, MapDataHeader.sizeof, 1, outputStream);
	fwrite(cast(void*)map.ptr, MappingElement.sizeof, map.length, outputStream);

	fclose(outputStream);
}
/**
 * Saves a map to an external file.
 * See documentation about the format.
 */ 
public void saveMapFile(F = File)(MapDataHeader header, MappingElement[] map, F file) @trusted {
	ubyte[] writeBuf = reinterpretAsArray!(ubyte)(header);
	file.rawWrite(writeBuf);
	file.rawWrite(map);
}
/**
 * Saves a map to an external file.
 * See documentation about the format.
 */
public void saveMapFile(F = File)(MapDataHeader header, MappingElement2[] map, F file) @trusted {
	ubyte[] writeBuf = reinterpretAsArray!(ubyte)(header);
	file.rawWrite(writeBuf);
	file.rawWrite(map);
}
/**
 * Loads a map from an external file.
 */
public MappingElement[] loadMapFile(F = File)(F file, ref MapDataHeader header){
	ubyte[] readbuffer;
	MappingElement[] result;
	readbuffer.length = MapDataHeader.sizeof;
	readbuffer = file.rawRead(readbuffer);
	header = reinterpretGet!MapDataHeader(readbuffer);
	if (header.flags & MapDataHeader.RegisteredFlags.NewFormat) return null;
	result.length = header.sizeX * header.sizeY;
	result = file.rawRead(result);
	return result;
}
/**
 * Loads a map from an external file.
 */
public MappingElement2[] loadMapFile2(F = File)(F file, ref MapDataHeader header){
	ubyte[] readbuffer;
	MappingElement[] result;
	readbuffer.length = MapDataHeader.sizeof;
	readbuffer = file.rawRead(readbuffer);
	header = reinterpretGet!MapDataHeader(readbuffer);
	if ((header.flags & MapDataHeader.RegisteredFlags.NewFormat) == 0) return null;
	result.length = header.sizeX * header.sizeY;
	result = file.rawRead(result);
	return result;
}

/**
 * Loads a map from a BASE64 string.
 */
public MappingElement[] loadMapFromBase64(in char[] input, int length){
	MappingElement[] result;
	result.length = length;
	Base64.decode(input, cast(ubyte[])cast(void[])result);
	return result;
}

/**
 * Saves a map to a BASE64 string.
 */
public char[] saveMapToBase64(in MappingElement[] input){
	char[] result;
	Base64.encode(cast(ubyte[])cast(void[])input, result);
	return result;
}
