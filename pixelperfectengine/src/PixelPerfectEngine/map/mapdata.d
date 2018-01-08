module PixelPerfectEngine.map.mapdata;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map module
 */
import std.stdio;
import std.file;
import std.conv;
import std.base64;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.layers;
import core.stdc.stdlib;
import core.stdc.stdio;
import std.string;

version(Windows){
	import core.sys.windows.windows;
	import std.windows.syserror;
}else{
	import core.stdc.errno;
}

public import PixelPerfectEngine.system.exc;
/**
 * Contains the very basic data for the map binary file (*.mbf).
 */
public struct MapDataHeader{
	public uint flags;
	public uint fileLength;
	public int sizeX;
	public int sizeY;
	this(uint fileLength, int sizeX, int sizeY){
		this.fileLength = fileLength;
		this.sizeX = sizeX;
		this.sizeY = sizeY;
	}
}
/**
 * Contains data for a single tile.
 */
public struct MapDataChunk{
	public wchar tileID;
	public BitmapAttrib attribute;
	public ubyte reserved; ///Reserved for future use, currently used as padding
	this(wchar tileID, bool hM, bool vM, ubyte pri){
		this.tileID = tileID;
		attribute = BitmapAttrib(hM,vM,pri);
	}
}
/**
 * Mainly stores TileLayer mapdata, can be repurposed for other kinds of layers
 */
public class MapData{
	MapDataHeader header;
	MapDataChunk[] mapping;
	this(int x, int y, MapDataChunk[] mapping){
		header = MapDataHeader(MapDataHeader.sizeof + (x * y * MapDataChunk.sizeof), x, y);
		this.mapping = mapping;
	}
	this(int x, int y, string base64string){
		header = MapDataHeader(MapDataHeader.sizeof + (x * y * MapDataChunk.sizeof), x, y);
		mapping = cast(MapDataChunk[])cast(void[])Base64.decode(base64string);
	}
	this(MapDataHeader header){
		this.header = header;
	}
	public wchar[] getCharMapping(){
		wchar[] result;
		foreach(ch; mapping){
			result ~= ch.tileID;
		}
		return result;
	}
	public BitmapAttrib[] getAttribMapping(){
		BitmapAttrib[] result;
		foreach(ch; mapping){
			result ~= ch.attribute;
		}
		return result;
	}
	/**
	 * Saves the MapData into a file.
	 */
	public void save(string filename){
		
		
		FILE* outputStream = fopen(toStringz(filename),"wb");
		if(!outputStream){
			version(Windows){
				DWORD errorCode = GetLastError();
				throw new FileAccessException("File access error no.: " ~ to!string(errorCode) ~ "\n" ~ sysErrorString(errorCode));
			}else{
				int errorCode = errno;
				throw new FileAccessException("File access error no.: " ~ to!string(errorCode));
			}
		}
		fwrite(cast(void*)&header, MapDataHeader.sizeof, 1, outputStream);
		fwrite(cast(void*)mapping.ptr, MapDataChunk.sizeof, header.sizeX * header.sizeY, outputStream);
		fclose(outputStream);
	}
	/**
	 * Loads and returns a MapData loaded into the memory.
	 */
	public static MapData load(string filename){
		FILE* inputStream = fopen(toStringz(filename),"rb");
		if(!inputStream){
			version(Windows){
				DWORD errorCode = GetLastError();
				throw new FileAccessException("File access error no.: " ~ to!string(errorCode) ~ "\n" ~ sysErrorString(errorCode));
			}else{
				int errorCode = errno;
				throw new FileAccessException("File access error no.: " ~ to!string(errorCode));
			}
		}
		MapDataHeader mdh;
		fread(cast(void*)&mdh, MapDataHeader.sizeof,1,inputStream);
		MapData output = new MapData(mdh);
		output.mapping.length = mdh.sizeX * mdh.sizeY;
		fread(cast(void*)output.mapping.ptr, MapDataChunk.sizeof, mdh.sizeX * mdh.sizeY,inputStream);
		fclose(inputStream);
		return output;
	}
	/**
	 * For embeding into maps
	 */
	public string getBase64String(){
		return Base64.encode(cast(ubyte[])cast(void[])mapping);
	}
	/**
	 * Load directly into a TileLayer
	 */
	public void loadIntoTileLayer(TileLayer t){
		BitmapAttrib[] ba;
		wchar[] chr;
		ba.length = header.sizeX * header.sizeY;
	}
}