/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map module
 */
module PixelPerfectEngine.map.mapload;

import std.xml;
import std.stdio;
import std.file;
import std.algorithm.mutation;
//import std.array;
import std.conv;
import PixelPerfectEngine.extbmp.extbmp;

//public import map.mapdata;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;

/**
 * Stores, loads, and saves a level data from an XML and multiple MAP files.
 */

public class ExtendibleMap{
	private void[] rawData, rawData0;
	private int headerLenght;
	private uint flags;
	private Element[] tileSource, objectSource;
	private TileLayerData[] tld;
	private SpriteLayerData[] sld;
	public string[string] metaData;
	public string filename;
	/// Load from datastream
	this(void[] data){
		rawData = data;
		headerLoad();
	}
	/// Load from file
	this(string filename){
		this.filename = filename;
		loadFile();
	}
	///Create new from scratch
	this(){

	}
	/// Loads the bitmaps for the Tilelayer from the XMP files
	Bitmap16Bit[wchar] loadTileSet(int num){
		Bitmap16Bit[wchar] result;

		foreach(Element e1; tileSource[num].elements){
			if(e1.tag.name == "File"){
				ExtendibleBitmap xmp = new ExtendibleBitmap(e1.tag.attr["source"]);
				foreach(Element e2; e1.elements){
					result[to!wchar(parseHex(e2.tag.attr["wcharID"]))] = loadBitmapFromXMP(xmp, e2.tag.attr["source"]);

				}
			}
		}
		return result;
	}
	Bitmap32Bit[wchar] load32BitTileSet(int num){
		Bitmap32Bit[wchar] result;
		foreach(Element e1; tileSource[num].elements){
			if(e1.tag.name == "File"){
				ExtendibleBitmap xmp = new ExtendibleBitmap(e1.tag.attr["source"]);
				foreach(Element e2; e1.elements){
					result[to!wchar(parseHex(e2.tag.attr["wcharID"]))] = load32BitBitmapFromXMP(xmp, e2.tag.attr["source"]);
				}
			}
		}
		return result;
	}
	void addFileToTileSource(int num, string file){
		Element e = new Element(new Tag("File"));
		e.tag.attr["source"] = file;
		tileSource[num] ~= e;
	}
	void addTileToTileSource(int num, wchar ID, string name, string source, string file){
		foreach(Element e; tileSource[num].elements){
			if(e.tag.attr["source"] == file){
				Element e0 = new Element("TileSource",name);
				e0.tag.attr["wcharID"] = intToHex(ID, 4);
				e0.tag.attr["source"] = source;
				e ~= e0;
				return;
			}
		}
	}
	void addTileLayer(TileLayerData t){
		tld ~= t;
		//create placeholder element
		Element e = new Element("TileLayer");
		tileSource ~= e;
	}
	TileLayerData getTileLayer(int num){
		return tld[num];
	}
	int getNumOfLayers(){
		return tld.length + sld.length;
	}
	void removeTileLayer(int num){
		tld = remove(tld, num);
		tileSource = remove(tileSource, num);
	}

	void loadFile(){
		//writeln(filename);
		try{
			rawData = std.file.read(filename);
			//flags = *cast(uint*)rawData.ptr;
			//headerLenght = *cast(int*)(rawData.ptr + 4);

			headerLoad();

			/*if(rawData.length > 8 + headerLenght){
				rawData0 = rawData[8 + headerLenght..rawData.length];
			}*/
			rawData.length = 0;

		}catch(Exception e){
			writeln(e.toString);
		}
	}
	//private void removeElement/(
	private void headerLoad(){
		string header = cast(string)rawData;
		Document d = new Document(header);
		foreach(Element e1; d.elements){
			switch(e1.tag.name){
				case "MetaData":
				//writeln("MetaData found");
					foreach(Element e2; e1.elements){
						metaData[e2.tag.name] = e2.text;
					}
					break;
				case "TileLayer":
					string s;
					foreach(Item pi ; e1.items){
						s = pi.toString();
						if(s.length > 4){
							if(s[0..6] == "<?map "){
								s = s[6..(s.length-2)];
							}
						}
					}
					int from = 8 + headerLenght + to!int(e1.tag.attr["dataOffset"]), dataLength = to!int(e1.tag.attr["dataLength"]);
					tld ~= new TileLayerData(to!int(e1.tag.attr["tX"]), to!int(e1.tag.attr["tY"]), 
						to!int(e1.tag.attr["mX"]), to!int(e1.tag.attr["mY"]), to!double(e1.tag.attr["sX"]), to!double(e1.tag.attr["sY"]),
						to!int(e1.tag.attr["priority"]), TileLayerData.getMapdataFromString(s), e1.tag.attr["name"], e1.tag.attr.get("subType",""));
					tileSource ~= e1;
					
					break;
				case "SpriteLayer":
					auto ea = new Element("SpriteLayer");
					SpriteLayerData s = new SpriteLayerData(e1.tag.attr["name"], to!double(e1.tag.attr["sX"]), to!double(e1.tag.attr["sY"]), 
						to!int(e1.tag.attr["priority"]), e1.tag.attr.get("subType",""));
					foreach(Element e2; e1.elements){
						if(e2.tag.name == "Object"){
							ObjectPlacement o = new ObjectPlacement(to!int(e2.tag.attr["x"]), to!int(e2.tag.attr["y"]), to!int(e2.tag.attr["num"]),e2.tag.attr["ID"]);
							o.addAuxData(e2.elements);

						}else{
							ea ~= e2;
						}
					}
					objectSource ~= ea;
					sld ~= s;
					break;
				default: break;
			}
		}	
	}
	void saveFile(string filename){
		this.filename = filename;
	}
	void saveFile(){
		auto doc = new Document(new Tag("HEADER"));
		auto e0 = new Element("MetaData");
		foreach(string s; metaData.byKey()){
			e0 ~= new Element(s, metaData[s]);
		}
		doc ~= e0;

		for(int i; i < tileSource.length; i++){
			Element e1 = tileSource[i];
			e1.tag.attr["name"] = tld[i].name;
			e1.tag.attr["tX"] = to!string(tld[i].tX);
			e1.tag.attr["tY"] = to!string(tld[i].tY);
			e1.tag.attr["mX"] = to!string(tld[i].mX);
			e1.tag.attr["mY"] = to!string(tld[i].mY);
			e1.tag.attr["sX"] = to!string(tld[i].sX);
			e1.tag.attr["sY"] = to!string(tld[i].sY);
			e1.tag.attr["subtype"] = tld[i].subtype;
			e1.tag.attr["priority"] = to!string(tld[i].priority);
			//e1.tag.attr["dataOffset"] = to!string(rawData0.length);
			//rawData0 ~= cast(void[])tld[i].mapping;
			//e1.tag.attr["dataLength"] = to!string(tld[i].mapping.length * wchar.sizeof);
			doc ~= e1;
			e1.items ~= new ProcessingInstruction("map " ~ tld[i].getMapdataForSaving());

		}

		for(int i; i < objectSource.length; i++){
			Element e1 = objectSource[i];
			e1.tag.attr["name"] = sld[i].name;
			e1.tag.attr["sX"] = to!string(sld[i].sX);
			e1.tag.attr["sY"] = to!string(sld[i].sY);
			e1.tag.attr["subtype"] = sld[i].subtype;
			e1.tag.attr["priority"] = to!string(sld[i].priority);
			/*foreach(ObjectPlacement o;sld[i].placement){
				auto e2 = o.getAuxData();
				e2.tag.attr["x"] = to!string(o.x);
				e2.tag.attr["y"] = to!string(o.y);
				e2.tag.attr["num"] = to!string(o.num);
				e2.tag.attr["ID"] = o.ID;
				e1 ~= e2;
			}*/
			doc ~= e1;
		}
		string header = stringArrayJoin(doc.pretty());
		//rawData.length = 8;
		//*cast(uint*)rawData.ptr = flags;
		//*cast(int*)(rawData.ptr+4) = header.length;
		//rawData ~= cast(void[])header;
		//rawData ~= rawData0;
		std.file.write(filename, header);
		//rawData0.length = 0;
	}
}

/*public enum ExtMapFlags : uint{
	CompressionMethodNull 	= 	1,
	CompressionMethodZLIB 	= 	2,
	LongHeader              =   16,
	LongFile                =   32
}*/

public class TileLayerData{
	wchar[] mapping;
	string name, subtype;
	int tX, tY, mX, mY, priority;
	double sX, sY;
	static const string[dchar] translateTable;
	static const char[string] detranslateTable;
	static this(){
		translateTable = ['?' : "?_"];
		detranslateTable = ["?_" : '?'];
	}
	public this(int tX, int tY, int mX, int mY, double sX, double sY, int priority, wchar[] mapping, string name, string subtype = ""){
		this.tX = tX;
		this.tY = tY;
		this.mX = mX;
		this.mY = mY;
		this.sX = sX;
		this.sY = sY;
		this.priority = priority;
		this.mapping = mapping;
		this.name = name;
		this.subtype = subtype;
	}
	public this(int tX, int tY, int mX, int mY, double sX, double sY, int priority, string name, string subtype = ""){
		this.tX = tX;
		this.tY = tY;
		this.mX = mX;
		this.mY = mY;
		this.sX = sX;
		this.sY = sY;
		this.priority = priority;
		//this.mapping = mapping;
		this.name = name;
		this.subtype = subtype;

		wchar[] initMapping;
		initMapping.length = mX*mY;
		this.mapping = initMapping;
	}
	public void writeMapping(int x, int y, wchar tile){
		mapping[x + (mX * y)] = tile;
	}
	public wchar readMapping(int x, int y){
		return mapping[x + (mX * y)];
	}
	public string getMapdataForSaving(){
		import std.string;
		string result = cast(string)(cast(void[])(mapping));
		return translate(result, translateTable);
	}
	public static wchar[] getMapdataFromString(string input){
		import std.array;
		return cast(wchar[])(cast(void[])(replace(input, "?_", "?")));
	}
}

public class SpriteLayerData{
	string name, subtype;
	double sX, sY;
	int priority;
	ObjectPlacement[] placement;
	this(string name, double sX, double sY, int priority, string subtype = ""){
		this.name = name;
		this.subtype = subtype;
		this.sX = sX;
		this.sY = sY;
		this.priority = priority;
	}
}

public class ObjectPlacement{
	protected Element[] auxObjectData;
	int x, y, num;
	string ID;
	this(int x, int y, int num, string ID){
		this.x = x;
		this.y = y;
		this.num = num;
		this.ID = ID;
	}

	void addAuxData(Element[] auxData){
		auxObjectData = auxData;
	}

	Element[] getAuxData(){
		return auxObjectData;
	}
}