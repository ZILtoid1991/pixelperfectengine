/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, mapload module
 */
module map.mapload;

import std.xml;
import std.stdio;
import std.file;
import std.algorithm.searching;
import std.conv;

public import map.mapdata;
import graphics.layers;
import graphics.bitmap;
import system.file;
import system.exc;

/*
 * Stores, loads, and saves a level data from an XML and multiple MAP files.
 */

public class MapHandler{
	//public BackgroundLayer[] background;
	public MapData[] mapdataList;
	public ObjectData[] objectdataList;
	public ubyte[] palette;
	private string filename, name, app, creator, paletteSource, paletteDatSource;
	public string[string] metadata;
	private int nOfLayers;

	//public double[] scrollRatio;

	public this(string file){
		filename = file;
	}
	public this(){

	}

	public void loadMap(){
		string s = cast(string)std.file.read(filename);
		try{
			check(s);
		}
		catch(CheckException e){
			writeln(e.toString);
		}
		finally{
			auto doc = new Document(s);
			if(doc.tag.name != "Map")
				throw new MapFileException("File is not VDP map file!");
			/*name = doc.tag.attr.get("name", "");
			app = doc.tag.attr.get("app", "");
			creator = doc.tag.attr.get("creator", "");*/
			nOfLayers = to!int(doc.tag.attr["nOfLayers"]);
			//background = new BackgroundLayer[nOfLayers];
			mapdataList = new MapData[nOfLayers];

			bool palettePresent;
			foreach(Element e1; doc.elements){
				if(e1.tag.name == "TileLayer"){
					bool mapSourcePresent;
					//background[to!int(e1.tag.attr.get("priority", "1"))] = new BackgroundLayer(to!int(e1.tag.attr["tileX"]), to!int(e1.tag.attr["tileY"]));
					//scrollRatio[to!int(e1.tag.attr.get("priority", "1"))] = to!double(e1.tag.attr["scrollRatio"]);
					FileCollector[] fcList;
					foreach(Element e2; e1.elements){

						if(e2.tag.name == "TileSource"){
							FileCollector fc = FileCollector(e2.tag.attr["source"]);
							foreach(Element e3; e2.elements){
								if(e3.tag.name == "Tile"){
									fc.add(to!ushort(e3.tag.attr["ID"]), to!ushort(e3.tag.attr["num"]), e3.tag.attr["name"]);
									/*fc.IDcollection[e3.tag.attr["num"]] ~= e3.tag.attr["ID"];
									fc.numcollection ~= e3.tag.attr["num"];*/
								}
							}
							/*if(fc.datSource == ""){
								loadTilesFromFile(fc, to!int(e1.tag.attr.get("priority", "1")));
							}
							else{
								loadTilesFromDat(fc, to!int(e1.tag.attr.get("priority", "1")));
							}*/
							fcList ~= fc;
						}
						else if(e2.tag.name == "MapSource" && !mapSourcePresent){
							mapSourcePresent = true;

								MapData md = MapData(e2.text);
								md.source = e2.text;
								md.tileX = to!int(e1.tag.attr["tileX"]);
								md.tileY = to!int(e1.tag.attr["tileY"]);
								md.priority = to!int(e1.tag.attr.get("priority", "1"));
								md.scrollRatioX = to!double(e1.tag.attr["scrollRatioX"]);
								md.scrollRatioY = to!double(e1.tag.attr["scrollRatioY"]);
								md.fcList = fcList;
								mapdataList ~= md;



							//else{}							//place for loading map from DAT files
						}
												
						//background[to!int(e1.tag.attr.get("priority", "1"))].loadMapping(mapdataList[to!int(e1.tag.attr.get("priority", "1"))].mx, mapdataList[to!int(e1.tag.attr.get("priority", "1"))].my, mapdataList[to!int(e1.tag.attr.get("priority", "1"))].data);
					}
					if(!mapSourcePresent)
						throw new MapFileException("Map source not present exception!");
				}
				else if(e1.tag.name == "Playfield"){
					foreach(Element e2; e1.elements){
						if(e2.tag.name == "Object"){
							objectdataList ~= ObjectData(e2.tag.attr["type"], to!int(e2.tag.attr["posX"]), to!int(e2.tag.attr["posY"]), e2.text);
						}
					}
				}
				else if(e1.tag.name == "Palette"){
					palettePresent = true;
					/*if(e1.tag.attr.get("datSource","") == "")
						palette = cast(ubyte[])std.file.read(e1.text);*/
					//place for loading palette from DAT files
				}else if(e1.tag.name == "Meta"){
					foreach(Element e2; e1.elements){
						/*i/f(e2.tag.name == "Name"){
							name = e2.text;
						}else if(e2.tag.name == "App"){
							app = e2.text;
						}else if(e2.tag.name == "Creator"){
							creator = e2.text;
						}*/
						metadata[e2.tag.name] = e2.text;
					}
				}

			}
			/*if(!palettePresent)
				throw new MapFileException("Palette not present exception!");*/
		}
	}

	public string[] getAllFilenames(){
		string[] result;
		foreach(a; mapdataList){
			foreach(b; a.fcList){
				result ~= b.source;
			}
		}
		return result;
	}

	public void saveMap(){
		auto doc = new Document(new Tag("Map"));
		doc.tag.attr["nOfLayers"] = to!string(nOfLayers);

		/*doc.tag.attr["name"] = name;
		doc.tag.attr["app"] = app;
		doc.tag.attr["creator"] = creator;*/
		auto e0 = new Element("Meta");
		foreach(string s; metadata.byKey()){
			e0 ~= new Element(s, metadata[s]);
		}

		doc ~= e0;

		for(int i; i < mapdataList.length; i++){
			auto e1 = new Element("Layer");
			e1.tag.attr["priority"] = to!string(mapdataList[i].priority);
			e1.tag.attr["scrollRatioX"] = to!string(mapdataList[i].scrollRatioX);
			e1.tag.attr["scrollRatioY"] = to!string(mapdataList[i].scrollRatioY);
			e1.tag.attr["tileX"] = to!string(mapdataList[i].tileX);
			e1.tag.attr["tileY"] = to!string(mapdataList[i].tileY);

			foreach(FileCollector fc; mapdataList[i].fcList){
				auto e11 = new Element("TileSource");
				e11.tag.attr["source"] = fc.source;
				//e11.tag.attr["datSource"] = fc.datSource;
				foreach(ushort u; fc.numcollection){
					auto e111 = new Element("Tile");
					e111.tag.attr["number"] = to!string(u);
					e111.tag.attr["ID"] = to!string(fc.IDcollection[u]);
					e111.tag.attr["name"] = fc.names[u];
					e11 ~= e111;
				}
				e1 ~= e11;
			}

			auto e12 = new Element("MapSource", mapdataList[i].source);
			e12.tag.attr["datSource"] = to!string(mapdataList[i].datSource);
			e1 ~= e12;
			doc ~= e1;
		}

		auto e2 = new Element("Playfield");

		foreach(ObjectData od ; objectdataList){
			auto e21 = new Element("Object", od.aux);
			e21.tag.attr["posX"] = to!string(od.posX);
			e21.tag.attr["posY"] = to!string(od.posY);
			e21.tag.attr["type"] = od.type;

			e2 ~= e21;
		}

		doc ~= e2;

		auto e3 = new Element("Palette", paletteSource);
		e3.tag.attr["datSource"] = paletteDatSource;

		doc ~= e3;

		std.file.write(filename, doc.toString());
	}

	private static void loadTilesFromFile(FileCollector fc, int num){
		Bitmap16Bit[] tileList = loadBitmapFromFile(fc.source);
		foreach(ushort i; fc.numcollection){
			//background[num].addTile(tileList[i], fc.IDcollection[i]);
		}
	}
	private static void loadTilesFromDat(FileCollector fc, int num){

	}
}

