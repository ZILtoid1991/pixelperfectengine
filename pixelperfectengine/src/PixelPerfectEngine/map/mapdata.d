module PixelPerfectEngine.map.mapdata;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map module
 */
import std.stdio;
import std.file;
import std.conv;
//import std.base64;
import PixelPerfectEngine.graphics.bitmap;
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
	 * For embeding into maps
	 */
	/+public string getBase64String(){
		void[] data;
		data ~= cast(void[])header;
		data ~= cast(void[])mapping;
		return Base64.encode(data);
	}+/
}