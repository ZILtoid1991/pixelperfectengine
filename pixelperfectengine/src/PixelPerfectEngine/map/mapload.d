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

public import PixelPerfectEngine.map.mapdata;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.system.etc;

/**
 * Stores, loads, and saves a level data from an XML and multiple MAP files.
 */

public class ExtendibleMap{
	//private void[] rawData;		///DEPRECATED. Binary data field buffer, no longer used.
	private Element[int] tileSource, objectSource;		///Stores XMP sources for the Layers
	public TileLayerData[int] tld;		///Stores the data regarding the tile layers.
	public SpriteLayerData[int] sld;		///Stores the data regarding the sprite layers.
	private string[int] mapDataFileSource;
	public string[string] metaData;		///Stores metadata. Serialized as: [index] = value &lt = &gt &lt index &gt value &lt / index &gt
	public string filename;			///Name of the file alongside with the path.
	/// Load from datastream

	/// Load from file
	this(string filename){
		this.filename = filename;
		loadFile();
	}
	///Create new from scratch
	this(){

	}

	/+public T[wchar] loadTileSet(T)(int num){
		T[wchar] result;

		foreach(Element e1; tileSource[num].elements){
			if(e1.tag.name == "File"){
				ExtendibleBitmap xmp = new ExtendibleBitmap(e1.tag.attr["source"]);
				foreach(Element e2; e1.elements){
					result[to!wchar(parseHex(e2.tag.attr["wcharID"]))] = loadBitmapFromXMP(T)(xmp, e2.tag.attr["source"]);

				}
			}
		}
		return result;
	}+/
	/// Loads the bitmaps for the Tilelayer from the XMP files
	public ABitmap[wchar] loadTileSet(int num){
		ABitmap[wchar] result;
		foreach(Element e1; tileSource[num].elements){
			if(e1.tag.name == "File"){
				ExtendibleBitmap xmp = new ExtendibleBitmap(e1.tag.attr["source"]);
				foreach(Element e2; e1.elements){
					result[to!wchar(parseHex(e2.tag.attr["wcharID"]))] = loadBitmapFromXMP!ABitmap(xmp, e2.tag.attr["source"]);

				}
			}
		}
		return result;
	}
	/// Loads the bitmaps for the Tilelayer from the XMP files
	/+deprecated Bitmap16Bit[wchar] loadTileSet(int num){
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
	/// Loads the 32bit bitmaps for the Tilelayer from the XMP files
	deprecated Bitmap32Bit[wchar] load32BitTileSet(int num){
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
	}+/
	/// Adds a new file for the tilesource.
	void addFileToTileSource(int num, string file){
		Element e = new Element(new Tag("File"));
		e.tag.attr["source"] = file;
		tileSource[num] ~= e;
	}
	/// Adds a new tile for the tilesource. If file source doesn't exist, it adds to the filelist. Source: the ID in the file.
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
		Element e = new Element(new Tag("File"));
		e.tag.attr["source"] = file;
		tileSource[num] ~= e;
		Element e0 = new Element("TileSource",name);
		e0.tag.attr["wcharID"] = intToHex(ID, 4);
		e0.tag.attr["source"] = source;
		e ~= e0;
	}
	/// Adds a new TileLayer to the file.
	void addTileLayer(TileLayerData t){
		tld[t.priority] = t;
		//create placeholder element
		Element e = new Element("tileSource");
		tileSource[t.priority] = e;
	}
	/// Gets the TileLayer from the file.
	TileLayerData getTileLayer(int num){
		return tld[num];
	}
	/// Gets the number of layers.
	size_t getNumOfLayers(){
		return tld.length + sld.length;
	}
	/// Removes a tilelayer.
	void removeTileLayer(int num){
		tld.remove(num);
		tileSource.remove(num);
	}
	/// Loads a file
	void loadFile(){
		string header = cast(string)std.file.read(filename);
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
					//tileSource ~= e1;
					int priority = to!int(e1.tag.attr["priority"]);
					MappingElement[] md;
					foreach(Element e2; e1.elements){
						switch(e2.tag.name){
							case "file":
								MapDataHeader mheader;
								md = loadMapFile(&mheader, e2.tag.text);
								mapDataFileSource[priority] = e2.tag.text;
								break;
							case "base64":
								//md = new MapData(to!int(e1.tag.attr["mX"]), to!int(e1.tag.attr["mY"]), e2.tag.text);
								md = loadMapFromBase64(e2.tag.text, to!int(e1.tag.attr["mX"]) * to!int(e1.tag.attr["mY"]));
								break;
							case "tileSource":
								tileSource[priority] = e2;
								break;
							default:
								break;
						}
					}
					tld[priority] = new TileLayerData(to!int(e1.tag.attr["tX"]), to!int(e1.tag.attr["tY"]),
						to!int(e1.tag.attr["mX"]), to!int(e1.tag.attr["mY"]), to!double(e1.tag.attr["sX"]), to!double(e1.tag.attr["sY"]),
						to!int(e1.tag.attr["priority"]), md, e1.tag.attr["name"], e1.tag.attr.get("subType",""));

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
					objectSource[to!int(e1.tag.attr["priority"])] = ea;
					sld[to!int(e1.tag.attr["priority"])] = s;
					break;
				default: break;
			}
		}
	}
	/// Saves the file to the given location
	void saveFile(string filename){
		this.filename = filename;
		saveFile();
	}
	/// Saves the file to the last location
	void saveFile(){
		auto doc = new Document(new Tag("HEADER"));
		auto e0 = new Element("MetaData");
		foreach(string s; metaData.byKey()){
			e0 ~= new Element(s, metaData[s]);
		}
		doc ~= e0;

		foreach(int i; tld.byKey){
			Element e1 = new Element("TileLayer");
			e1.tag.attr["name"] = tld[i].name;
			e1.tag.attr["tX"] = to!string(tld[i].tX);
			e1.tag.attr["tY"] = to!string(tld[i].tY);
			e1.tag.attr["mX"] = to!string(tld[i].mX);
			e1.tag.attr["mY"] = to!string(tld[i].mY);
			e1.tag.attr["sX"] = to!string(tld[i].sX);
			e1.tag.attr["sY"] = to!string(tld[i].sY);
			e1 ~= tileSource[i];
			if(tld[i].subtype)
				e1.tag.attr["subtype"] = tld[i].subtype;
			e1.tag.attr["priority"] = to!string(tld[i].priority);
			if(tld[i].isEmbedded){
				Element e2 = new Element("base64", to!string(saveMapToBase64(tld[i].mapping)));
			}else{
				Element e2 = new Element("file",mapDataFileSource[i]);
				//tld[i].mapping.save(mapDataFileSource[i]);
				MapDataHeader header = MapDataHeader(tld[i].mX, tld[i].mY);
				saveMapFile(&header, tld[i].mapping, mapDataFileSource[i]);
			}
			doc ~= e1;
			//e1.items ~= new ProcessingInstruction("map " ~ tld[i].getMapdataForSaving());

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


/**
 * Stores Data regarding to the TileLayer.
 */
public class TileLayerData{
	public MappingElement[] mapping;		///Mapping data.
	public bool isEmbedded;		///Whether the data is embedded with base64 coding or not.
	public bool warp;			///Toggle warp.
	public string name;			///Name of the layer, primarily used by the editors.
	public string subtype;		///Subtype of the layer, eg. 32bit, transformable.
	public int tX, tY;			///Sizes of the tile for the layer.
	public int mX, mY;			///Sizes of the mapping.
	public int priority;		///Layerpriority.
	public double sX, sY, sXOffset, sYOffset;		///Used by the autoscroll for paralax scrolling.

	/// Constructor for TileLayers with preexisting mapping.
	public this(int tX, int tY, int mX, int mY, double sX, double sY, int priority, MappingElement[] mapping, string name, string subtype = ""){
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
	/// Constructor for TileLayers without preexisting mapping.
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
		isEmbedded = true;
		/*wchar[] initMapping;
		initMapping.length = mX*mY;
		this.mapping = initMapping;*/
	}


}
/**
 * Stores data regarding to the SpriteLayer.
 */
public class SpriteLayerData{
	public string name;			///Name of the layer, primarily used by the editors.
	public string subtype;		///Subtype of the layer, eg. 32bit, transformable.
	public double sX, sY;		///Used by the autoscroll for paralax scrolling.
	public int priority;		///Layerpriority.
	public ObjectPlacement[] placement;		///Objectdata
	/// Creates a new spritelayer in the file
	this(string name, double sX, double sY, int priority, string subtype = ""){
		this.name = name;
		this.subtype = subtype;
		this.sX = sX;
		this.sY = sY;
		this.priority = priority;
	}
}
/**
 * Stores object placement data
 */
public class ObjectPlacement{
	protected Element[] auxObjectData;		///XML data regarding of this object.
	public int x, y;		///Position of the object.
	public int num;			///Identification number and rendering priority.
	public string ID;		///Type of the object
	/// Creates a new data.
	this(int x, int y, int num, string ID){
		this.x = x;
		this.y = y;
		this.num = num;
		this.ID = ID;
	}
	/// Sets XML data.
	public void setAuxData(Element[] auxData){
		auxObjectData = auxData;
	}
	/// Gets the XML data.
	/// It's recommended to inherit from the class instead and write custom functions instead.
	public Element[] getAuxData(){
		return auxObjectData;
	}
	public void addAuxData(Element[] e){
		auxObjectData ~= e;
	}
}
