module map.mapdata;
/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, mapdata module
 */
import std.stdio;
import std.file;
import std.conv;
/*
public struct TileLayerData{
	public string source, name;
	public wchar[] data;
	public int mx, my, tileX, tileY, priority;
	public double scrollRatioX, scrollRatioY;
	public FileCollector[] fcList;

	public this(int x, int y, wchar[] d){
		data = d;
		mx = x;
		my = y;
	}

	public this(int x, int y){
		mx = x;
		my = y;
		data.length = mx * my;
	}

	public this(string filename){
		wchar[] d = cast(wchar[])std.file.read(filename);
		mx = d[0];
		my = d[1];
		data = d[2..(d.length-1)];
	}

	public void store(string filename){
		wchar[] d;
		d ~= to!wchar(mx);
		d ~= to!wchar(my);
		d ~= data;
		std.file.write(filename, d);
	}
}

public struct ObjectData{
	public int posX, posY;
	public string type, aux;

	public this(string t, int x, int y, string a = null){
		type = t;
		posX = x;
		posY = y;
		aux = a;
	}
}

public struct FileCollector{
	public string source; /// Name of the XMP file
	public string[wchar] IDcollection;	/// ID of bitmap in the XMP
	public string[ushort] names;	/// Used for editors
	
	/*public this(){

	}

	public void add(wchar ID, ushort num, string name =""){
		numcollection ~= num;
		IDcollection[num] = ID;
		names[num] = name;
	}
}*/