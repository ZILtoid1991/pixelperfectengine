module pixelperfectengine.map.mapformat;
/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map.mapformat module
 */
import newsdlang;

import pixelperfectengine.graphics.layers;
import pixelperfectengine.graphics.raster : PaletteContainer;
import pixelperfectengine.graphics.shaders;
import std.stdio;
import std.exception : enforce;
import std.typecons : BitFlags;
import pixelperfectengine.system.etc : parseHex;
import std.format : format;
import std.conv : to;
import collections.treemap;
public import pixelperfectengine.map.mapdata;
import pixelperfectengine.system.file;
import pixelperfectengine.physics.objectcollision;
import pixelperfectengine.system.exc : PPEException;
import pixelperfectengine.system.etc : hashCalc;

@safe:
/**
 * Serializes/deserializes XMF map data in SDLang format.
 * Each layer can contain objects (eg. for marking events, clipping, or sprites if applicable), tilemapping (not for SpriteLayers), embedded
 * data such as tilemapping or scripts, and so on.
 *
 * Also does some basic resource managing.
 *
 * Note on layer tags:
 * As of this version, additional tags within layers must have individual names. Subtags within a parent also need to have individual names.
 * Namespaces are reserved for internal use (eg. file sources, objects).
 */
public class MapFormat {
	public TreeMap!(int,DLTag) 	layerData;	///Layerdata stored as SDLang tags.
	public TreeMap!(int,Layer)	layeroutput;///Used to fast map and object data pullback in editors
	protected DLTag 			metadata;	///Stores metadata.
	protected DLDocument		root;		///Root tag for common information.
	public TileInfo[][int]		tileDataFromExt;///Stores basic TileData that are loaded through extensions
	/**
	 * Associative array used for rendering mode lookups in one way. (DEPRECATED!)
	 */
	public static immutable RenderingMode[string] renderingModeLookup;
	shared static this() {
		renderingModeLookup["null"] = RenderingMode.init;
		renderingModeLookup["Copy"] = RenderingMode.Copy;
		renderingModeLookup["Blitter"] = RenderingMode.Blitter;
		renderingModeLookup["AlphaBlend"] = RenderingMode.AlphaBlend;
		renderingModeLookup["Add"] = RenderingMode.Add;
		renderingModeLookup["AddBl"] = RenderingMode.AddBl;
		renderingModeLookup["Subtract"] = RenderingMode.Subtract;
		renderingModeLookup["SubtractBl"] = RenderingMode.SubtractBl;
		renderingModeLookup["Diff"] = RenderingMode.Diff;
		renderingModeLookup["DiffBl"] = RenderingMode.DiffBl;
		renderingModeLookup["Multiply"] = RenderingMode.Multiply;
		renderingModeLookup["MultiplyBl"] = RenderingMode.MultiplyBl;
		renderingModeLookup["Screen"] = RenderingMode.Screen;
		renderingModeLookup["ScreenBl"] = RenderingMode.ScreenBl;
		renderingModeLookup["AND"] = RenderingMode.AND;
		renderingModeLookup["OR"] = RenderingMode.OR;
		renderingModeLookup["XOR"] = RenderingMode.XOR;
	}
	/**
	 * Creates new instance from scratch.
	 */
	public this(string name, int resX, int resY) {
		root = new DLDocument();
		metadata = new DLTag("Metadata", null, null);
		root.add(metadata);
		metadata.add(new DLTag("Version", null, [new DLValue(1), new DLValue(0)]));
		metadata.add(new DLTag("Name", null, [Value(name)]));
		metadata.add(new DLTag("Resolution", null, [Value(resX), Value(resY)]));
	}
	/**
	 * Serializes itself from file.
	 */
	public this(F)(F file) {
		//File f = File(path, "rb");
		char[] source;
		source.length = cast(size_t)file.size;
		source = file.rawRead(source);
		root = readDOM(cast(string)source);
		//Just quickly go through the tags and sort them out
		foreach (DLTag t0 ; root.tags) {
			switch (t0.namespace) {
				case "Layer":
					const int priority = t0.values[1].get!int;
					layerData[priority] = t0;
					// RenderingMode lrd = renderingModeLookup.get(t0.getTagValue!string("RenderingMode"), RenderingMode.Copy);
					string shdrPathV, shdrPathF;
					GLShader shdr, shdr32;
					DLTag shdrDescr = t0.getTag("ShaderProgram"), shdrDescr32 = t0.getTag("ShaderProgram32");
					if (shdrDescr) {
						shdrPathV = shdrDescr.values[0].get!string;
						shdrPathF = shdrDescr.values[1].get!string;
						shdr = GLShader(loadShader(shdrPathV), loadShader(shdrPathF));
					}
					if (shdrDescr32) {
						shdrPathV = shdrDescr.values[0].get!string;
						shdrPathF = shdrDescr.values[1].get!string;
						shdr32 = GLShader(loadShader(shdrPathV), loadShader(shdrPathF));
					}
					switch (t0.name) {
						case "Tile":
							layeroutput[priority] = new TileLayer(t0.values[2].get!int, t0.values[3].get!int, shdr);
							break;
						case "Sprite":
							layeroutput[priority] = new SpriteLayer(shdr, shdr32);
							break;
						default:
							throw new Exception("Unsupported layer format");
					}
					break;
				
				default:
					if(t0.name == "Metadata"){
						metadata = t0;
					}
					break;
			}
		}
		//assert(layerData.length == layeroutput.length);
	}
	/**
	 * Loads tiles from disk to all layers. Also loads the palette.
	 * TODO: Add dpk support
	 * Params:
	 *   paletteTarget: The destination, where the palettes should be loaded into.
	 */
	public void loadTiles(PaletteContainer paletteTarget) {
		import pixelperfectengine.system.file;
		foreach (key, value ; layerData) {
			if (value.name != "Tile") continue;
			DLTag[] tileSource = getAllTileSources(key);
			foreach (t0; tileSource) {
				string path = t0.getValue!string();
				Image i = loadImage(File(resolvePath(path), "rb"));
				void helperFunc(T)(T bitmap, DLTag source) {
					TileLayer tl = cast(TileLayer)layeroutput[key];
					DLTag tileInfo = source.searchTag(["Embed:TileInfo"]);
					int tW = tl.getTileWidth, tH = tl.getTileHeight;
					int numOfCol = bitmap.width / tW, numOfRow = bitmap.height / tH;
					int imageID = hashCalc(path);
					tl.addBitmapSource(bitmap, imageID, cast(ubyte)source.getAttribute!int("palShift"));
					if(tileInfo !is null) {
						foreach (Tag t1 ; tileInfo.tags) {
							int tileNum = t1.values[0].get!int();
							int x = tileNum % numOfCol;
							int y = (tileNum - x) % numOfRow;
							tl.addTile(cast(wchar)t1.values[1].get!int(), imageID, x * tW, y * tH);
						}
					}
				}
				switch(i.getBitdepth){
					case 2, 4, 8:
						Bitmap8Bit bitmap = loadBitmapFromImage!(Bitmap8Bit)(i);
						helperFunc(bitmap, t0);
						break;
					case 32:
						Bitmap32Bit bitmap = loadBitmapFromImage!(Bitmap32Bit)(i);
						helperFunc(bitmap, t0);
						break;
					default:
						throw new Exception("Unsupported image bitdepth");
						
				}
				if (paletteTarget !is null && isPaletteFileExists(path)) {
					paletteTarget.loadPaletteChunk(loadPaletteFromImage(i), cast(ushort)t0.getAttribute!int("offset", 0));
				}
				//debug writeln(paletteTarget.palette);
			}
		}
	}
	/** 
	 * Loads the sprites associated with the layer ID.
	 * Params:
	 *   layerID = the ID of the layer.
	 *   paletteTarget = target for any loaded palettes, ideally the raster.
	 * Returns: An associative array with sprite identifiers as the keys, and the sprite bitmaps as its elements.
	 * Note: It's mainly intended for editor placeholders, but also could work with production-made games as long
	 * as the limitations don't intercept anything major.
	 */
	public void loadSprites(int layerID, PaletteContainer paletteTarget) {
		import pixelperfectengine.system.file;
		SpriteLayer currSpriteLayer = cast(SpriteLayer)layeroutput[layerID];
		// ABitmap[int] result;
		Image[string] imageBuffer;	//Resource manager to minimize reloading image files
		Tag tBase = layerData[layerID];
		if (tBase.name != "Sprite") return;
		foreach (DLTag t0; tBase.tags) {
			switch (t0.fullname) {
				case "File:SpriteSource":
					string filename = t0.values[1].get!string();
					int imageID = hashCalc(filename);
					const int id = t0.values[0].get!int();
					if (imageBuffer.get(filename, null) is null) {
						imageBuffer[filename] = loadImage(File(resolvePath(filename)));
						switch (imageBuffer[filename].getBitdepth) {
						case 1, 2, 4, 8:
							currSpriteLayer.addBitmapSource(loadBitmapFromImage!Bitmap8Bit(imageBuffer[filename]), imageID,
									imageBuffer[filename].getBitdepth);
							break;
						default:
							currSpriteLayer.addBitmapSource(loadBitmapFromImage!Bitmap32Bit(imageBuffer[filename]), imageID, 32);
							break;
						}
					}

					if (t0.searchAttribute!int("horizOffset", -1) != -1 && t0.searchAttribute!int("vertOffset") != -1 &&
							t0.searchAttribute!int("width") && t0.searchAttribute!int("height")) {
						const int hOffset = t0.searchAttribute!int("horizOffset"), vOffset = t0.searchAttribute!int("vertOffset"),
							w = t0.searchAttribute!int("width"), h = t0.searchAttribute!int("height");
						currSpriteLayer.createSpriteMaterial(id, imageID, Box.bySize(hOffset, vOffset, w, h));
					} else {
						currSpriteLayer.createSpriteMaterial(id, imageID);
					}
					break;
				case "File:SpriteSheet":
					string filename = t0.values[0].get!string();
					int imageID = hashCalc(filename);
					if (imageBuffer.get(filename, null) is null) {
						imageBuffer[filename] = loadImage(File(resolvePath(filename)));
						switch (imageBuffer[filename].getBitdepth) {
						case 1, 2, 4, 8:
							currSpriteLayer.addBitmapSource(loadBitmapFromImage!Bitmap8Bit(imageBuffer[filename]), imageID,
									imageBuffer[filename].getBitdepth);
							break;
						default:
							currSpriteLayer.addBitmapSource(loadBitmapFromImage!Bitmap32Bit(imageBuffer[filename]), imageID, 32);
							break;
						}
					}
					foreach (DLTag t1 ; t0.tags) {
						if (t1.name == "SheetData") {
							foreach (DLTag t2 ; t1.tags) {
								const int id = t2.values[0].get!int(), hOffset = t2.values[1].get!int(), vOffset = t2.values[2].get!int(),
										w = t2.values[3].get!int(), h = t2.values[4].get!int();
								currSpriteLayer.createSpriteMaterial(id, imageID, Box.bySize(hOffset, vOffset, w, h));
							}
						}
					}
					break;
				case "File:Palette":
					string filename = t0.expectValue!string();
					if (imageBuffer.get(filename, null) is null) {
						imageBuffer[filename] = loadImage(File(filename));
					}
					Color[] pal = loadPaletteFromImage(imageBuffer[filename]);
					const size_t palLength = t0.getAttribute!int("palShift") ? 1<<(t0.getAttribute!int("palShift")) : pal.length;
					const int palOffset = t0.getAttribute!int("offset");
					paletteTarget.loadPaletteChunk(pal[0..palLength], cast(ushort)palOffset);
					break;
				default:
					break;
			}
		}
		
		// return result;
	}
	/**
	 * Returns all objects belonging to a `layerID` in an array.
	 */
	public MapObject[] getLayerObjects(int layerID) {
		DLTag t0 = layerData[layerID];
		if (t0 is null) return null;
		MapObject[] result;
		try {
			foreach (DLTag t1; t0.namespaces["Object"].tags) {
				MapObject obj = parseObject(t1, layerID);
				if (obj !is null)
					result ~= obj;
			}
		} catch (Exception e) {
			debug writeln(e);
			return null;
		}
		return result;
	}
	/**
	 * Loads all sprites and objects to thir respective layers and the supplied ObjectCollisionDetector.
	 * Params:
	 *   paletteTarget: A raster to load the palettes into. Must be not null.
	 *   ocd: The supplied ObjectCollisionDetector. Can be null.
	 * Note: This is a default parser and loader, one might want to write a more complicated one for their application.
	 */
	public void loadAllSpritesAndObjects(PaletteContainer paletteTarget, ObjectCollisionDetector ocd) {
		import pixelperfectengine.physics.common;
		foreach (key, value; layeroutput) {
			loadSprites(key, paletteTarget);
			MapObject[] objList = getLayerObjects(key);
			/+if (spr.length) +/
			{
				SpriteLayer sl = cast(SpriteLayer)value;
				foreach (MapObject key0; objList) {
					if (key0.type == MapObject.MapObjectType.sprite) {
						SpriteObject so = cast(SpriteObject)key0;
						sl.addSprite(so.ssID, so.pID, Point(so.x, so.y), so.palSel, so.palShift, so.masterAlpha);
						// sl.addSprite(spr[so.ssID], so.pID, so.x, so.y, so.palSel, so.palShift, so.masterAlpha, so.scaleHoriz,
						// 		so.scaleVert, so.rendMode);
						if (ocd !is null && so.flags.toCollision) {
							Box spriteCoord = sl.getSpriteCoordinate(so.pID).boxOf;
							ocd.objects[so.pID] = CollisionShape(spriteCoord, null);
						}
					} else if (ocd !is null && key0.type == MapObject.MapObjectType.box && key0.flags.toCollision) {
						BoxObject bo = cast(BoxObject)key0;
						ocd.objects[bo.pID] = CollisionShape(bo.position, null);
					}
				}
			} /+else if (ocd !is null) {
				foreach (MapObject key0; objList) {
					if (ocd !is null && key0.type == MapObject.MapObjectType.box && key0.flags.toCollision) {
						BoxObject bo = cast(BoxObject)key0;
						ocd.objects[bo.pID] = CollisionShape(bo.position, null);
					}
				}
			}+/
		}
	}
	/**
	 * Loads mapping data from disk to all layers.
	 */
	public void loadMappingData () {
		import pixelperfectengine.system.etc : reinterpretCast;
		foreach (key, value ; layerData) {
			Tag t0 = value.getTag("Embed:MapData");
			if (t0 !is null) {
				TileLayer tl = cast(TileLayer)layeroutput[key];
				//writeln(t0.getValue!(ubyte[])());
				tl.loadMapping(value.values[4].get!int(), value.values[5].get!int(), 
						reinterpretCast!MappingElement(t0.expectValue!(ubyte[])()));

				continue;
			}
			t0 = value.getTag("File:MapData");
			if (t0 !is null) {
				TileLayer tl = cast(TileLayer)layeroutput[key];
				MapDataHeader mdf;
				File mapfile = File(resolvePath(t0.expectValue!string()));
				tl.loadMapping(value.values[4].get!int(), value.values[5].get!int(), loadMapFile(mapfile, mdf));
			}
		}
	}
	/**
	 * Saves the document to disc.
	 * Params:
	 *   path = the path where the document is should be saved to.
	 */
	public void save(string path) {
		debug writeln(root.tags);
		foreach(int i, DLTag t; layerData){
			if(t.name == "Tile")
				pullMapDataFromLayer (i);
		}
		string output = root.toSDLDocument();
		File f = File(path, "wb+");
		f.write(output);
	}
	/**
	 * Returns the given metadata.
	 * Params:
	 *   name = the name of the parameter.
	 * Template params:
	 *   T = The type of the parameter.
	 */
	public T getMetadata(T)(string name)
			if (T.stringof == int.stringof || T.stringof == string.stringof) {
		return metadata.getTagValue!T(name);
	}
	/**
	 * Returns the requested layer.
	 */
	public Layer opIndex(int index) pure {
		return layeroutput[index];
	}
	/**
	 * Returns all layer's basic information.
	 */
	public LayerInfo[] getLayerInfo() {
		import std.algorithm.sorting : sort;
		LayerInfo[] result;
		foreach (Tag t ; layerData) {
			result ~= LayerInfo(LayerInfo.parseLayerTypeString(t.name), t.values[1].get!int(), t.values[0].get!string());
		}
		result.sort;
		return result;
	}
	/**
	 * Returns a specified layer's basic information.
	 */
	public LayerInfo getLayerInfo(int pri) {
		Tag t = layerData[pri];
		if (t !is null) return LayerInfo(LayerInfo.parseLayerTypeString(t.name), t.values[1].get!int(), 
				t.values[0].get!string());
		else return LayerInfo.init;
	}
	/**
	 * Alters a tile layer data.
	 * Params:
	 *   layerNum = The numer of the layer
	 *   dataNum = The index of the data
	 *   value = The new value.
	 * Template params:
	 *   T = The type of the parameter.
	 */
	public void alterTileLayerInfo(T)(int layerNum, int dataNum, T value) {
		layerData[layerNum].values[dataNum] = new DLValue(value);
	}
	/**
	 * Returns a selected tile layer's all tile's basic information.
	 * Mainly used to display information in editors.
	 * Params:
	 *   pri = Layer priority ID
	 * Returns: an array with the tile information.
	 */
	public TileInfo[] getTileInfo(int pri) {
		import std.algorithm.sorting : sort;
		TileInfo[] result;
		try {
			foreach (DLTag t0 ; layerData[pri].namespaces["File"].tags) {
				//writeln(t0.toSDLString);
				if (t0.name == "TileSource") {
					DLTag t1 = t0.searchTag("Embed:TileInfo");
					ushort palShift = cast(ushort)t0.searchAttribute!int("palShift", 0);
					if (t1 !is null) {
						foreach (DLTag t2 ; t1.tags) {
							result ~= TileInfo(cast(wchar)t2.values[0].get!int(), palShift, t2.values[1].get!int(), 
									t2.values[2].get!string());
						}
					}
				}
			}
		} catch (DOMRangeException e) {	///Just means there's no File namespace within the tag. Should be OK.
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		//writeln(result.length);
		result ~= tileDataFromExt.get(pri, []);
		result.sort;
		return result;
	}
	/**
	 * Adds TileInfo to a TileLayer from an array.
	 * Joins together multiple chunks with the same source identifier. (should be a path)
	 * Params:
	 *   pri = Layer priority ID.
	 *   list = An array of TileInfo, which need to be added to the document.
	 *   source = The file origin of the tiles (file or DataPak path).
	 *   dpkSource = Path to the DataPak file if it's used, null otherwise.
	 */
	public void addTileInfo(int pri, TileInfo[] list, string source, string dpkSource = null) {
		if(list.length == 0) throw new Exception("Empty list!");
		Tag t;
		try{
			foreach (DLTag t0 ; layerData[pri].namespaces["File"].tags) {
				if (t0.name == "TileSource" && t0.values[0] == source && t0.getAttribute!string("dataPakSrc", null) == dpkSource) {
					t = t0.getTag("Embed:TileInfo", null);
					if (t is null) { 
						t = new Tag(t0, "Embed", "TileInfo");
					}
					break;
				}
			}
			foreach (item ; list) {
				new Tag(t, null, null, [Value(cast(int)item.id), Value(item.num), Value(item.name)]);
			}
		} catch (Exception e) {
			debug writeln (e);
		}
		//writeln(t.tags.length);
		assert(t.tags.length == list.length);
	}
	/**
	 * Adds TileInfo to a TileLayer from a preexiting tag.
	 * Joins together multiple chunks with the same source identifier. (should be a path)
	 * Params:
	 *   pri = Layer priority ID.
	 *   t = The SDL tag to be added to the Layer.
	 *   source = The file origin of the tiles (file or DataPak path).
	 *   dpkSource = Path to the DataPak file if it's used, null otherwise.
	 */
	public void addTileInfo(int pri, Tag t, string source, string dpkSource = null) {
		foreach (DLTag t0 ; layerData[pri].accessNamespace("File").tags) {
			if (t0.name == "TileSource" && t0.values[0] == source && t0.searchAttribute!string("dataPakSrc", null) == dpkSource) {
				t0.add(t);
				return;
			}
		}

	}
	/**
	 * Adds a single TileInfo to a preexisting chunk on the layer.
	 */
	public void addTile(int pri, TileInfo item, string source, string dpkSource = null) {
		foreach (DLTag t0 ; layerData[pri].accessNamespace("File").tags) {
			if (t0.name == "TileSource" && t0.values[0] == source && t0.searchAttribute!string("dataPakSrc", null) == dpkSource) {
				DLTag t1 = t0.searchTag("Embed:TileInfo");
				if (t1 !is null) {
					new Tag (t1, null, null, [Value(cast(int)item.id), Value(item.num), Value(item.name)]);
				}
			}
		}
	}
	///Ditto, but from preexiting Tag.
	public void addTile(int pri, Tag t, string source, string dpkSource = null) {
		foreach (DLTag t0 ; layerData[pri].accessNamespace("File").tags) {
			if (t0.name == "TileSource" && t0.values[0] == source && t0.searchAttribute!string("dataPakSrc", null) == dpkSource) {
				DLTag t1 = t0.searchTag("Embed:TileInfo");
				t1.add(t);
			}
		}
	}
	/**
	 * Renames a single tile.
	 * Params:
	 *   pri = Layer priority ID.
	 *   id = Tile character ID.
	 *   newName = The new name of the tile.
	 * Returns: the previous name if the action was successful, or null if there was some issue.
	 */
	public string renameTile(int pri, int id, string newName) {
		foreach (DLTag t0 ; layerData[pri].accessNamespace("File").tags) {
			if (t0.name == "TileSource") {
				DLTag t1 = t0.searchTag("Embed:TileInfo");
				if (t1 !is null) {
					foreach (Tag t2; t1.tags) {
						if (t2.values[0].get!int() == id) {
							string oldName = t2.values[2].get!string();
							t2.values[2] = Value(newName);
							return oldName;
						}
					}
				}
				
			}
		}
		return null;
	}
	/**
	 * Removes a single tile from a TileInfo chunk.
	 * Params:
	 *   pri = Layer priority ID.
	 *   id = Tile character ID.
	 *   source = The file origin of the tiles (file or DataPak path).
	 *   dpkSource = Path to the DataPak file if it's used, null otherwise.
	 * Returns: a tag as a backup if tile is found and removed, or null if it's not found.
	 */
	public DLTag removeTile(int pri, int id, string source, string dpkSource = null) {
		foreach (Tag t0 ; layerData[pri].accessNamespace("File").tags) {
			if (t0.name == "TileSource") {
				DLTag t1 = t0.getTag("Embed:TileInfo");
				if (t1 !is null) {
					source = t0.values[0].get!string();
					dpkSource = t0.searchAttribute!string("dpkSource", null);
					foreach (DLTag t2; t1.tags) {
						if (t2.values[0].get!int() == id) {
							return t2.removeFromParent();
						}
					}
				}
				
			}
		}
		return null;
	}
	/**
	 * Removes a given layer of any kind.
	 * Params:
	 *   pri = Layer priority ID.
	 * Returns: the Tag of the layer as a backup.
	 */
	public DLTag removeLayer(int pri) {
		DLTag backup = layerData[pri];
		layeroutput.remove(pri);
		layerData.remove(pri);
		return backup.removeFromParent();
	}
	/**
	 * Adds a layer from preexsting tag.
	 * Params:
	 *   pri = Layer priority ID.
	 *   t = The tag containing layer information.
	 *   l = The layer.
	 */
	public void addNewLayer(int pri, DLTag t, Layer l) {
		layeroutput[pri] = l;
		layerData[pri] = t;
		root.add(t);
	}
	/**
	 * Adds a newly created TileLayer to the document.
	 * Params:
	 *   pri = Layer priority ID.
	 *   tX = Tile width.
	 *   tY = Tile height.
	 *   mX = Map width.
	 *   mY = Map height.
	 *   name = Name of the layer.
	 *   l = The layer itself.
	 */
	public void addNewTileLayer(int pri, int tX, int tY, int mX, int mY, string name, TileLayer l) {
		layeroutput[pri] = l;
		l.setRasterizer(getHorizontalResolution, getVerticalResolution);
		layerData[pri] = new DLTag("Tile", "Layer", [
				new DLValue(name), new DLValue(pri), new DLValue(tX), new DLValue(tY), new DLValue(mX), new DLValue(mY)
		]);
		root.add(layerData[pri]);
		// new Tag(layerData[pri], null, "RenderingMode", [Value("Copy")]);
	}
	/**
	 * Adds a new tag to a layer.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = Name of the tag.
	 *   args = The values of the tag.
	 */
	public void addTagToLayer(T...)(int pri, string name, T args) {
		DLElement[] vals;
		foreach (arg; args) {
			vals ~= new DLValue(arg);
		}
		DLTag t0 = new Tag(name, null, vals);
		layerData[pri].add(t0);
	}
	/**
	 * Adds a new property tag to a layer's tag.
	 * Note: Property tag must be first created by `addTagToLayer`.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = Name of the tag.
	 *   parent = Name of the tag this one will be contained by.
	 *   args = The values to be added to the tag.
	 */
	public void addPropertyTagToLayer(T...)(int pri, string name, string parent, T args) {
		DLElement[] vals;
		foreach (arg; args) {
			vals ~= new DLValue(arg);
		}
		DLTag t0 = new DLTag(layerData[pri].expectTag(parent), null, name, vals);
	}
	/**
	 * Gets the values of a layer's root tag.
	 * Params:
	 *   pri = Layer priority ID.
	 * Returns: an array containing all the values belonging to the root tag.
	 */
	public DLValue[] getLayerRootTagValues(int pri) {
		return layerData[pri].values;
	}
	/**
	 * Gets the values of a layer's tag.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = The name of the tag.
	 * Returns: an array containing all the values belonging to the given tag.
	 */
	public DLValue[] getLayerTagValues(int pri, string name) {
		return layerData[pri].searchTagX([name]).values;
	}
	/**
	 * Gets the values of a layer's property tag.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = The name of the property tag.
	 *   parent = The name of the tag the property tag is contained within.
	 * Returns: an array containing all the values belonging to the given property tag.
	 */
	public DLValue[] getLayerPropertyTagValues(int pri, string name, string parent) {
		return layerData[pri].searchTagX([parent]).searchTagX([name]).values;
	}
	/**
	 * Edits the values of a layer's tag. 
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = Name of the tag.
	 *   args = The values to be added to the tag.
	 * Returns: the original values in an array.
	 */
	public DLValue[] editLayerTagValues(T...)(int pri, string name, T args) {
		DLValue[] backup = layerData[pri].searchTagX([name]).values;
		foreach (DLValue v ; backup) v.removeFromParent();
		DLElement[] vals;
		foreach (arg ; args) vals ~= new DLValue(arg);
		//new Tag(layerData[pri], null, name, vals);
		layerData[pri].searchTagX([name]).add(vals);
		return backup;
	}
	/**
	 * Edits the values of a layer's property tag.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = Name of the tag.
	 *   parent = Name of the tag this one will be contained by.
	 *   args = The values to be added to the tag.
	 * Returns: the original values in an array.
	 */
	public DLValue[] editLayerPropertyTagValues(T...)(int pri, string name, string parent, T args) {
		DLValue[] backup = layerData[pri].searchTagX([parent]).searchTagX([name]).values;
		foreach (DLValue v ; backup) v.removeFromParent();
		DLElement[] vals;
		foreach (arg; args) vals ~= new DLValue(arg);
		layerData[pri].searchTagX([parent]).searchTagX([name]).add(vals);
		return backup;
	}
	/**
	 * Removes a layer's tag.
	 * Params:
	 *   pri = Layer priority ID.
	 *   name = Name of the tag.
	 * Returns: a backup for undoing.
	 */
	public DLTag removeLayerTagValues(int pri, string name) {
		return layerData[pri].searchTagX(name).removeFromParent();
	}
	/**
	 * Adds an embedded MapData to a TileLayer.
	 * Params:
	 *   pri = Layer priority ID.
	 *   base64Code = The data to be embedded,
	 */
	public void addEmbeddedMapData(int pri, ubyte[] base64Code) {
		layerData[pri].add(new DLTag("MapData", "Embed", [new DLValue(base64Code)]));
	}
	/**
	 * Adds an embedded MapData to a TileLayer.
	 * Params:
	 *   pri = Layer priority ID.
	 *   me = The data to be embedded,
	 */
	public void addEmbeddedMapData(int pri, MappingElement2[] me) {
		import pixelperfectengine.system.etc : reinterpretCast;
		addEmbeddedMapData(pri, reinterpretCast!ubyte(me));
	}
	/**
	 * Adds a TileData file to a TileLayer.
	 * Filename should contain relative path.
	 * Params:
	 *   pri = Layer priority ID.
	 *   filename = Path to the map data file. (Either on the disk or within the DataPak file)
	 *   dataPakSrc = Path to the DataPak source file if used, null otherwise.
	 */
	public void addMapDataFile(int pri, string filename, string dataPakSrc = null) {
		DLElement[] a;
		if (dataPakSrc !is null) {
			a ~= new DLAttribute("dataPakSrc", DLVar(dataPakSrc, DLValueType.String, DLStringType.Backtick));
		}
		layerData[pri].add(new DLTag("MapData", "File", [new DLValue(filename)] ~ a));
	}
	/**
	 * Removes embedded TileData from a TileLayer.
	 * Params:
	 *   pri = Layer priority ID.
	 * Returns: a backup for undoing.
	 */
	public DLTag removeEmbeddedMapData(int pri) {
		return layerData[pri].searchTagX(["Embed:MapData"]).removeFromParent();
	}
	/**
	 * Removes a TileData file from a TileLayer.
	 * Params:
	 *   pri = Layer priority ID.
	 * Returns: a backup for undoing.
	 */
	public Tag removeMapDataFile(int pri) {
		return layerData[pri].searchTagX(["File:MapData"]).removeFromParent();
	}
	/**
	 * Pulls TileLayer data from the layer, and stores it in the preconfigured location.
	 * Params:
	 *   pri = Layer priority ID.
	 * Only works with uncompressed data due to the need of recompression.
	 */
	public void pullMapDataFromLayer(int pri) {
		import pixelperfectengine.system.etc : reinterpretCast;
		ITileLayer t = cast(ITileLayer)layeroutput[pri];
		MappingElement2[] mapping = t.getMapping;
		if (layerData[pri].searchTag("Embed:MapData") !is null) {
			layerData[pri].searchTag("Embed:MapData").values[0].set(reinterpretCast!ubyte(mapping));
		} else if (layerData[pri].searchTag("File:MapData") !is null) {
			string filename = layerData[pri].searchTag("File:MapData").values[0].get!string();
			MapDataHeader mdh = MapDataHeader(layerData[pri].values[4].get!int, layerData[pri].values[5].get!int);
			saveMapFile(mdh, mapping, File(filename, "wb"));
		}
	}
	/**
	 * Adds a tile source file (file that contains the tiles) to a TileLayer.
	 * Params:
	 *   pri = Layer priority ID.
	 *   filename = Path to the file.
	 *   dataPakSrc = Path to the DataPak file if used, null otherwise.
	 *   palShift = Amount of palette shiting, 0 for default.
	 */
	public void addTileSourceFile(int pri, string filename, string dataPakSrc = null, int palShift = 0) {
		DLElement[] a;
		if (dataPakSrc !is null) a ~= new DLAttribute("dataPakSrc", null,
				DLVar(dataPakSrc, DLValueType.String, DLStringType.Backtick));
		if (palShift) a ~= new DLAttribute("palShift", null, DLVar(palShift, DLValueType.Integer, DLNumberStyle.Decimal));
		layerData[pri].add(new DLTag("TileSource", "File", [new DLValue(filename)] ~ a));
	}
	/**
	 * Removes a tile source.
	 * Params:
	 *   pri = Layer priority ID.
	 *   filename = Path to the file.
	 *   dataPakSrc = Path to the DataPak file if used, null otherwise.
	 * Returns: a backup copy of the tag.
	 */
	public DLTag removeTileSourceFile(int pri, string filename, string dataPakSrc = null) {
		try {
			auto namespace = layerData[pri].accessNamespace("File");
			foreach (DLTag t ; namespace.tags) {
				if (t.name == "TileSource" && t.values[0] == filename &&
						t.searchAttribute!string("dataPakSrc", null) == dataPakSrc) {
					return t.removeFromParent();
				}
			}
		} catch (DLException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return null;
	}
	/**
	 * Accesses tile source tags in documents for adding extra data (eg. tile names).
	 * Params:
	 *   pri = Layer priority ID.
	 *   filename = Path to the file.
	 *   dataPakSrc = Path to the DataPak file if used, null otherwise.
	 */
	public DLTag getTileSourceTag(int pri, string filename, string dataPakSrc = null) {
		try {
			auto namespace = layerData[pri].namespaces["File"];
			foreach (t ; namespace.tags) {
				if (t.name == "TileSource" && t.values[0] == filename && t.getAttribute!string("dataPakSrc", null) == dataPakSrc) {
					return t;
				}
			}
		} catch (DLException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return null;
	}
	/**
	 * Returns all tile sources for a given layer.
	 * Intended to use with a loader.
	 * Params:
	 *   pri = Layer priority ID.
	 */
	public DLTag[] getAllTileSources (int pri) {
		DLTag[] result;
		try {
			void loadFromLayer(int _pri) {
				//auto namespace = layerData[pri].namespaces["File"];
				foreach (DLTag t ; layerData[_pri].accessNamespace("File").tags) {
					if (t.name == "TileSource") {
						result ~= t;
					}
				}
			}
			loadFromLayer(pri);
			foreach (DLTag t ; layerData[pri].accessNamespace("Shared").tags) {
				if (t.name == "TileData") {
					loadFromLayer(t.values[0].get!int());
				}
			}
		} catch (DLException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return result;
	}
	/**
	 * Adds a palette file source to the document.
	 * Params:
	 *   filename = Path to the file containing the palette.
	 *   dataPakSrc = Path to the DataPak file if used, null otherwise.
	 *   offset = Palette offset, or where the palette should be loaded.
	 *   palShift = Palette shifting, or how many bits the target bitmap will use.
	 */
	public DLTag addPaletteFile (string filename, string dataPakSrc, int offset, int palShift) {
		DLElement[] a;
		if (offset) a ~= new DLAttribute("offset", null, DLVar(offset, DLValueType.Integer, DLNumberStyle.Decimal));
		if (palShift) a ~= new DLAttribute("palShift", null, DLVar(palShift, DLValueType.Integer, DLNumberStyle.Decimal));
		if (dataPakSrc.length) a ~= new DLAttribute("dataPakSrc",
				DLVar(dataPakSrc, DLValueType.String, DLStringType.Backtick));
		DLTag t = new DLTag("Palette", "File", [new DLValue(filename)] ~ a);
		root.add(t);
		return t;
	}
	/**
	 * Adds an embedded palette to the document.
	 * Params:
	 *   c = The palette to be embedded.
	 *   name = Name of the palette.
	 *   offset = Palette offset, or where the palette should be loaded.
	 */
	public DLTag addEmbeddedPalette (Color[] c, string name, int offset) {
		import pixelperfectengine.system.etc : reinterpretCast;
		DLElement[] a;
		if (offset) a ~= new DLAttribute("offset", null, DLVar(offset, DLValueType.Integer, DLNumberStyle.Decimal));
		DLTag t = new DLTag("Palette", "Embed", [new DLValue(name), new DLValue(reinterpretCast!ubyte(c))] ~ a);
		root.add(t);
		return t;
	}
	/**
	 * Returns whether the given palette file source exists.
	 * Params:
	 *   filename = Path to the file containing the palette.
	 *   dataPakSrc = Path to the DataPak file if used, null otherwise.
	 * Returns: True if the palette file source exists.
	 */
	public bool isPaletteFileExists (string filename, string dataPakSrc = null) {
		foreach (DLTag t0 ; root.tags) {
			if (t0.fullname == "File:Palette") {
				if (t0.getValue!string() == filename && t0.getAttribute!string("dataPakSrc", null) == dataPakSrc) 
					return true;
			}
		}
		return false;
	}
	/**
	 * Returns the name of the map from metadata.
	 */
	public string getName () {
		return metadata.getTagValue!string("Name");
	}
	/**
	 * Adds an object to a layer.
	 * Intended for editor use.
	 * Params:
	 *   layer = The ID of the layer.
	 *   t = The serialized tag of the object.
	 * Returns: The backup of the previous object's copy, or null if no object have existed with the same ID.
	 */
	public DLTag addObjectToLayer(int layer, DLTag t) {
		DLTag result;
		try {
			foreach (DLTag t0; layerData[layer].accessNamespace("Object").tags) {
				if (t0.values[1].get!int == t.values[1].get!int) {
					layerData[layer].add(t);
					result = t0.removeFromParent();
					break;
				}
			}
		} catch (Exception e) {
			debug writeln(e);
		}
		layerData[layer].add(t);
		return result;
	}
	/**
	 * Removes an object from a layer.
	 * Intended for editor use.
	 * Params:
	 *   layer = ID of the layer from which we want to remove the object from.
	 *   objID = ID of the object we want to remove.
	 * Returns: the tag of the object that has been removed if the operation is successful.
	 */
	public DLTag removeObjectFromLayer(int layer, int objID) {
		try {
			foreach (DLTag t0; layerData[layer].accessNamespace("Object").tags) {
				if (t0.values[1].get!int == objID) {
					return t0.removeFromParent();
				}
			}
		} catch (Exception e) {
			debug writeln(e);
		}
		return null;
	}
	/**
	 * Returns the horizontal resolution.
	 */
	public int getHorizontalResolution () {
		return metadata.searchTagX(["Resolution"]).values[0].get!int();
	}
	/**
	 * Returns the vertical resolution.
	 */
	public int getVerticalResolution () {
		return metadata.searchTagX(["Resolution"]).values[1].get!int();
	}
}
/**
 * Represents a single object within a layer, that can represent many different things.
 * All objects have a priority identifier (int), a group identifier (int), and a name.
 */
abstract class MapObject {
	/**
	 * Enumerator used for differentiating between multiple kinds of objects.
	 * The value serialized as a string as the name of a tag.
	 */
	public enum MapObjectType : ubyte {
		box,			///Can be used for collision detection, event marking for scripts, and masking. Has two coordinates.
		/**
		 * Only applicable for SpriteLayer.
		 * Has one coordinate, a horizontal and vertical scaling indicator (int), and a source indicator (int).
		 */
		sprite,
		polyline,
	}
	///Defines various flags for objects
	public enum MapObjectFlags : ushort {
		toCollision		=	1<<0,	///Marks the object to be included to collision detection.

	}
	public int 			pID;		///priority identifier
	public int			gID;		///group identifier (equals with layer number)
	public string		name;		///name of object
	protected MapObjectType	_type;	///type of the object
	public BitFlags!MapObjectFlags	flags;///Contains property flags
	public DLTag		mainTag;	///Tag that holds the data related to this mapobject + ancillary tags
	///Returns the type of this object
	public @property MapObjectType type () const @nogc nothrow @safe pure {
		return _type;
	}
	///Serializes the object into an SDL tag
	public abstract DLTag serialize () @trusted;
	/**
	 * Checks if two objects have the same identifier.
	 */
	public bool opEquals (MapObject rhs) @nogc @safe nothrow pure const {
		return pID == rhs.pID && gID == rhs.gID;
	}
	override size_t toHash() const @nogc @safe pure nothrow {
		static if (size_t.sizeof == 8) return pID | (cast(ulong)gID<<32L);
		else return pID ^ (gID<<16) ^ (gID>>>16);
	}
}
/**
 * Implements a Box object. Adds a single Coordinate property to the default MapObject
 */
public class BoxObject : MapObject {
	public Box			position;	///position of object on the layer
	
	/**
	 * Creates a new instance from scratch.
	 */
	public this (int pID, int gID, string name, Box position)  {
		this.pID = pID;
		this.gID = gID;
		this.name = name;
		this.position = position;
		_type = MapObjectType.box;
		mainTag = new Tag("Object", "Box", [Value(name), Value(pID), Value(position.left), Value(position.top), 
				Value(position.right), Value(position.bottom)]);
	}
	/**
	 * Deserializes itself from a Tag.
	 */
	public this (DLTag t, int gID) @trusted {
		name = t.values[0].get!string();
		pID = t.values[1].get!int();
		position = Box(t.values[2].get!int(), t.values[3].get!int(), t.values[4].get!int(), t.values[5].get!int());
		this.gID = gID;
		_type = MapObjectType.box;
		//ancillaryTags = t.tags;
		mainTag = t;
		if (t.getTag("ToCollision"))
			flags.toCollision = true;
	}
	/**
	 * Serializes the object into an SDL tag
	 */
	public override DLTag serialize () @trusted {
		return mainTag;
	}
	///Gets the identifying color of this object.
	public Color color() @trusted {
		Tag t0 = mainTag.getTag("Color");
		if (t0) {
			return parseColor(t0);
		} else {
			return Color.init;
		}
	}
	///Sets the identifying color of this object.
	public Color color(Color c) @trusted {
		Tag t0 = mainTag.getTag("Color");
		if (t0) {
			t0.remove;
		} 
		mainTag.add(storeColor(c));
		return c;
	}
}
/**
 * Implements a sprite object. Adds a sprite source identifier, X and Y coordinates, and two 1024 based scaling indicator.
 */
public class SpriteObject : MapObject {
	public int 			ssID;	///Sprite source identifier
	public int			x;		///X position
	public int			y;		///Y position
	public int			lrX = -1;///Position of the lower-right corner
	public int			lrY = -1;///Position of the lower-right corner
	public ushort		palSel;	///Palette selector. Selects the given palette for the object.
	public ubyte		palShift;	///Palette shift value. Determines palette length (2^x).
	public ubyte		masterAlpha;///The main alpha channel of the sprite.
	/**
	 * Creates a new instance from scratch.
	 */
	public this (int pID, int gID, string name, int ssID, int x, int y, int lrX = -1, int lrY = -1,
			ushort palSel = 0, ubyte palShift = 0, ubyte masterAlpha = 0xFF) {
		this.pID = pID;
		this.gID = gID;
		this.name = name;
		this.ssID = ssID;
		this.x = x;
		this.y = y;
		this.lrX = lrX;
		this.lrY = lrY;
		_type = MapObjectType.sprite;
		DLElement[] attr;
		if (lrX >= 0)
			attr ~= new DLAttribute("lrCornerX", null, DLVar(lrX, DLValueType.Integer, DLNumberStyle.Decimal));
		if (lrY >= 0)
			attr ~= new DLAttribute("lrCornerY", null, DLVar(lrY, DLValueType.Integer, DLNumberStyle.Decimal));
		if (palSel)
			attr ~= new DLAttribute("palSel", null, DLVar(cast(int)palSel, DLValueType.Integer, DLNumberStyle.Hexadecimal));
		if (palShift)
			attr ~= new DLAttribute("palShift", null, DLVar(cast(int)palShift, DLValueType.Integer, DLNumberStyle.Decimal));
		if (masterAlpha)
			attr ~= new DLAtribute("masterAlpha", null, DLVar(cast(int)masterAlpha, DLValueType.Integer, DLNumberStyle.Decimal));
		mainTag = new DLTag("Sprite", "Object",
				[new DLValue(name), new DLValue(pID), new DLValue(ssID), new DLValue(x), new DLValue(y)]);

	}
	/**
	 * Deserializes itself from a Tag.
	 */
	public this (DLTag t, int gID) {
		this.gID = gID;
		name = t.values[0].get!string();
		pID = t.values[1].get!int();
		ssID = t.values[2].get!int();
		x = t.values[3].get!int();
		y = t.values[4].get!int();
		lrX = t.searchAttribute!int("lrCornerX", -1);
		lrY = t.searchAttribute!int("lrCornerY", -1);
		palSel = cast(ushort)t.searchAttribute!int("palSel", 0);
		palShift = cast(ubyte)t.searchAttribute!int("palShift", 0);
		masterAlpha = cast(ubyte)t.searchAttribute!int("masterAlpha", 255);
		mainTag = t;
		_type = MapObjectType.sprite;
		if (t.getTag("ToCollision"))
			flags.toCollision = true;
	}
	/**
	 * Serializes the object into an SDL tag
	 */
	public override DLTag serialize () {
		return mainTag;
	}
	
}
/**
 * Describes a polyline object for things like Vectoral Tile Layer.
 */
public class PolylineObject : MapObject {
	///The points of the object's path.
	public Point[]		path;
	public this (int pID, int gID, string name, Point[] path) {
		this.gID = gID;
		this.pID = pID;
		this.name = name;
		this.path = path;
		mainTag = new DLTag("Polyline", "Object", [new DLValue(name), new DLValue(pID),
			new DLTag("Begin", null, [new DLValue(path[0].x), new DLValue(path[0].y)])
		]);
		foreach (Point key ; path[1..$-1]) {
			mainTag.add(new DLTag("Segment", null, [new DLValue(key.x), new DLValue(key.y)]));
		}
		if (path[0] == path[$-1]) {
			mainTag.add(new DLTag(mainTag, null, "Close"));
		} else {
			mainTag.add(new DLTag(mainTag, null, "Segment", [new DLValue(path[$-1].x), new DLValue(path[$-1].y)]));
		}
	}
	public this (DLTag t, int gID) @trusted {
		this.gID = gID;
		name = t.values[0].get!string();
		pID = t.values[1].get!int();
		foreach (DLTag t0 ; t.tags) {
			switch (t0.name) {
				case "Begin":
					enforce!MapFormatException(path.length == 0, "'Begin' node found in the middle of the path.");
					goto case "Segment";
				case "Segment":
					enforce!MapFormatException(path.length != 0, "No 'Begin' node found");
					path ~= Point(t0.values[0].get!int, t0.values[1].get!int);
					break;
				case "Close":
					path ~= path[0];
					break;
				default:
					break;
			}
		}
		mainTag = t;
		_type = MapObjectType.polyline;
	}
	/**
	 * Sets the color to 'c' for the polyline object's given segment indicated by 'num'.
	 */
	public Color color(Color c, int num) @trusted {
		int i;
		foreach (Tag t0 ; mainTag.tags) {
			switch (t0.name) {
				case "Begin", "Segment", "Close":
					if (num == i) {
						t0.add(storeColor(c));
						return c;
					}
					i++;
					break;
				default:
					break;
			}
		}
		throw new PPEException("Out of index error!");
	}
	/**
	 * Returns the color for the polyline object's given segment indicated by 'num'.
	 */
	public Color color(int num) @trusted {
		int i;
		foreach (Tag t0 ; mainTag.tags) {
			switch (t0.name) {
				case "Begin", "Segment", "Close":
					if (num == i) {
						Tag t1 = t0.getTag("Color");
						if (t1) {
							return parseColor(t1);
						} else {
							return Color.init;
						}
					}
					i++;
					break;
				default:
					break;
			}
		}
		throw new PPEException("Out of index error!");
	}
	override public Tag serialize() @trusted {
		return Tag.init; // TODO: implement
	}
}
///Parses a color from SDLang Tag 't', then returns it as the engine's default format.
public Color parseColor(DLTag t) @trusted {
	Color c;
	switch (t.values.length) {
		case 1:
			if (t.values[0].type == DLValueType.Integer)
				c.base = cast(uint)t.getValue!long();
			else
				c.base = parseHex!uint(t.getValue!string);
			break;
		case 4:
			c.a = cast(ubyte)t.values[0].get!int();
			c.r = cast(ubyte)t.values[1].get!int();
			c.g = cast(ubyte)t.values[2].get!int();
			c.b = cast(ubyte)t.values[3].get!int();
			break;
		default:
			throw new MapFormatException("Unrecognized color format tag!");
	}
	return c;
}
///Serializes the engine's color format into an SDLang Tag.
public Tag storeColor(Color c) @trusted {
	return new Tag(null, "Color", [Value(format("%08x", c.base))]);
}
/**
 * Parses an ofject from an SDLang tag.
 * Params:
 *   t = The source tag.
 *   gID = Group (layer) ID.
 * Returns: The parsed object.
 */
public MapObject parseObject(DLTag t, int gID) @trusted {
	if (t.namespace != "Object") return null;
	switch (t.name) {
		case "Box":
			return new BoxObject(t, gID);
		case "Sprite":
			return new SpriteObject(t, gID);
		case "Polyline":
			return new PolylineObject(t, gID);
		default:
			return null;
	}
}
/**
 * Simple LayerInfo struct, mostly for internal communications.
 */
public struct LayerInfo {
	LayerType	type;	///Type of layer
	int			pri;	///Priority of layer
	string		name;	///Name of layer
	int opCmp (LayerInfo rhs) const pure @safe @nogc {
		if (pri > rhs.pri)
			return 1;
		else if (pri < rhs.pri)
			return -1;
		else
			return 0;
	}
	/**
	 * Parses a string as a layer type
	 */
	static LayerType parseLayerTypeString (string s) pure @safe {
		import std.uni : toLower;
		s = toLower(s);
		switch (s) {
			case "tile":
				return LayerType.Tile;
			case "sprite":
				return LayerType.Sprite;
			case "transformabletile":
				return LayerType.TransformableTile;
			default:
				return LayerType.init;
		}
	}
}
/**
 * Simple TileInfo struct, mostly for internal communication and loading.
 */
public struct TileInfo {
	wchar		id;		///ID of the tile in wchar format
	ushort		palShift;	///palShift offset of the tile
	int			num;	///Number of tile in the file
	string		name;	///Name of the tile
	int opCmp (TileInfo rhs) const pure @safe @nogc {
		if (id > rhs.id)
			return 1;
		else if (id < rhs.id)
			return -1;
		else
			return 0;
	}
	public string toString() const pure {
		import std.conv : to;
		return to!string(id) ~ ";" ~ to!string(num) ~ ";" ~ name;
	}
}
public class MapFormatException : PPEException {
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
