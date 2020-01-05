module PixelPerfectEngine.map.mapformat;
/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map.mapformat module
 */
import sdlang;

import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster : PaletteContainer;
import std.stdio;
public import PixelPerfectEngine.map.mapdata;

/**
 * Serializes/deserializes PPE map data in SDLang format.
 * Each layer can contain objects (eg. for marking events, clipping, or sprites if applicable), tilemapping (not for SpriteLayers), embedded
 * data such as tilemapping or scripts, and so on.
 * <br/>
 * Note on layer tags:
 * As of this version, additional tags within layers must have individual names. Subtags within a parent also need to have individual names.
 * Namespaces are reserved for internal use (eg. file sources, objects).
 */
public class MapFormat {
	public Tag[int] 	layerData;	///Layerdata stored as SDLang tags.
	public Layer[int]	layeroutput;	///Used to fast map and object data pullback in editors
	protected Tag 		metadata;	///Stores metadata.
	protected Tag		root;		///Root tag for common information.
	public TileInfo[][int]	tileDataFromExt;///Stores basic TileData that are loaded through extensions
	/**
	 * Creates new instance from scratch.
	 */
	public this (string name, int resX, int resY) @trusted {
		root = new Tag();
		metadata = new Tag(root, null, "Metadata");
		new Tag(metadata, null, "Version", [Value(1), Value(0)]);
		new Tag(metadata, null, "Name", [Value(name)]);
		new Tag(metadata, null, "Resolution", [Value(resX), Value(resY)]);
	}
	/**
	 * Serializes itself from file.
	 */
	public this (F)(F file) @trusted {
		//File f = File(path, "rb");
		char[] source;
		source.length = cast(size_t)file.size;
		source = file.rawRead(source);
		root = parseSource(cast(string)source);
		//Just quickly go through the tags and sort them out
		foreach (Tag t0 ; root.all.tags) {
			switch (t0.namespace) {
				case "Layer":
					const int priority = t0.values[1].get!int;
					layerData[priority] = t0;
					LayerRenderingMode lrd;
					switch (t0.getTagValue!string("RenderingMode")) {
						case "AlphaBlending":
							lrd = LayerRenderingMode.ALPHA_BLENDING;
							break;
						case "Blitter":
							lrd = LayerRenderingMode.BLITTER;
							break;
						case "Copy":
							lrd = LayerRenderingMode.COPY;
							break;
						default:
							break;
					}
					switch (t0.name) {
						case "Tile":
							layeroutput[priority] = new TileLayer(t0.values[2].get!int, t0.values[3].get!int, lrd);
							break;
						default:
							throw new Exception("Unsupported layer format");
					}
					break;
				/*case "Metadata":
					metadata = t0;
					break;*/
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
	 */
	public void loadTiles (PaletteContainer paletteTarget) @trusted {
		import PixelPerfectEngine.system.file;
		foreach (key, value ; layerData) {
			if (value.name != "Tile") continue;
			Tag[] tileSource = getAllTileSources(key);
			foreach (t0; tileSource) {
				string path = t0.getValue!string();
				Image i = loadImage(File(path, "rb"));
				void helperFunc(T)(T[] bitmaps, Tag source) {
					TileLayer tl = cast(TileLayer)layeroutput[key];
					Tag tileInfo = source.getTag("Embed:TileInfo", null);
					if(tileInfo !is null)
						foreach (t1 ; tileInfo.tags) {
							tl.addTile(bitmaps[t1.values[0].get!int()], cast(wchar)t1.values[1].get!int());
						}
				}
				switch(i.getBitdepth){
					case 4:
						Bitmap4Bit[] bitmaps = loadBitmapSheetFromImage!(Bitmap4Bit)(i, value.values[2].get!int(), 
								value.values[3].get!int());
						helperFunc(bitmaps, t0);
						break;
					case 8:
						Bitmap8Bit[] bitmaps = loadBitmapSheetFromImage!(Bitmap8Bit)(i, value.values[2].get!int(), 
								value.values[3].get!int());
						helperFunc(bitmaps, t0);
						break;
					case 16:
						Bitmap16Bit[] bitmaps = loadBitmapSheetFromImage!(Bitmap16Bit)(i, value.values[2].get!int(), 
								value.values[3].get!int());
						helperFunc(bitmaps, t0);
						break;
					case 32:
						Bitmap32Bit[] bitmaps = loadBitmapSheetFromImage!(Bitmap32Bit)(i, value.values[2].get!int(), 
								value.values[3].get!int());
						helperFunc(bitmaps, t0);
						break;
					default:
						throw new Exception("Unsupported image bitdepth");
						
				}
				if (paletteTarget !is null && isPaletteFileExists(path)) {
					paletteTarget.addPaletteChunk(loadPaletteFromImage(i));
				}
				//debug writeln(paletteTarget.palette);
			}
		}
	}
	/**
	 * Loads mapping data from disk to all layers.
	 */
	public void loadMappingData () @trusted {
		import PixelPerfectEngine.system.etc : reinterpretCast;
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
				File mapfile = File(t0.expectValue!string());
				tl.loadMapping(value.values[4].get!int(), value.values[5].get!int(), loadMapFile(mapfile, mdf));
			}
		}
	}
	/**
	 * Saves the document to disc.
	 */
	public void save (string path) @trusted {
		debug writeln(root.tags);
		foreach(i; layerData.byKey){
			if(layerData[i].name == "Tile")
				pullMapDataFromLayer (i);
		}
		string output = root.toSDLDocument();
		File f = File(path, "wb+");
		f.write(output);
	}
	/**
	 * Returns given metadata.
	 */
	public T getMetadata(T)(string name)
			if (T.stringof == int.stringof || T.stringof == string.stringof) {
		return metadata.getTagValue!T(name);
	}
	/**
	 * Returns the requested layer
	 */
	public Layer opIndex(int index) @safe pure {
		return layeroutput.get(index, null);
	}
	/**
	 * Returns all layer's basic information.
	 */
	public LayerInfo[] getLayerInfo() @trusted {
		import std.algorithm.sorting : sort;
		LayerInfo[] result;
		foreach (Tag t ; layerData) {
			result ~= LayerInfo(LayerInfo.parseLayerTypeString(t.name), t.values[1].get!int(), t.values[0].get!string());
		}
		result.sort;
		return result;
	}
	/**
	 * Returns a selected tile layer's all tile's basic information.
	 * Mainly used to display information in editors.
	 */
	public TileInfo[] getTileInfo(int pri) @trusted {
		import std.algorithm.sorting : sort;
		TileInfo[] result;
		foreach (Tag t0 ; layerData[pri].namespaces["File"].tags) {
			//writeln(t0.toSDLString);
			if (t0.name == "TileSource") {
				Tag t1 = t0.getTag("Embed:TileInfo");
				if (t1 !is null) {
					foreach (Tag t2 ; t1.tags) {
						result ~= TileInfo(cast(wchar)t2.values[0].get!int(), t2.values[1].get!int(), t2.values[2].get!string());
					}
				}

			}
		}
		//writeln(result.length);
		result ~= tileDataFromExt.get(pri, []);
		result.sort;
		return result;
	}
	/**
	 * Adds TileInfo to a TileLayer.
	 * Joins together multiple chunks with the same source identifier. (should be a path)
	 */
	public void addTileInfo(int pri, TileInfo[] list, string source, string dpkSource = null) @trusted {
		if(list.length == 0) throw new Exception("Empty list!");
		Tag t;
		try{
			foreach (Tag t0 ; layerData[pri].namespaces["File"].tags) {
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
	///Ditto, but from preexisting Tag.
	public void addTileInfo(int pri, Tag t, string source, string dpkSource = null) @trusted {
		foreach (Tag t0 ; layerData[pri].namespaces["File"].tags) {
			if (t0.name == "TileSource" && t0.values[0] == source && t0.getAttribute!string("dataPakSrc", null) == dpkSource) {
				t0.add(t);
				return;
			}
		}

	}
	/**
	 * Adds a single TileInfo to a preexisting chunk on the layer.
	 */
	public void addSingleTileInfo(int pri, TileInfo item, string source, string dpkSource = null) {
		foreach (Tag t0 ; layerData[pri].namespaces["File"].tags) {
			if (t0.name == "TileSource" && t0.values[0] == source && t0.getAttribute!string("dataPakSrc", null) == dpkSource) {
				Tag t1 = t0.getTag("Embed:TileInfo");
				if (t1 !is null) {
					new Tag (t1, null, null, [Value(cast(int)item.id), Value(item.num), Value(item.name)]);
				}
			}
		}
	}
	///Ditto, but from preexiting Tag.
	public void addSingleTileInfo(int pri, Tag t, string source) @trusted {
		foreach (Tag t0 ; layerData[pri].namespaces["Embed"].tags) {
			if (t0.name == "TileInfo" && t0.values.length >= 1 && t0.values[0].get!string() == source) {
				t0.add(t);
				return;
			}
		}
	}
	/**
	 * Removes a single tile from a TileInfo chunk.
	 * Returns a tag as a backup.
	 * Returns null if source is not found.
	 */
	public Tag removeTileInfo(int pri, string source) @trusted {
		foreach (Tag t0 ; layerData[pri].namespaces["Embed"].tags) {
			if (t0.name == "TileInfo" && t0.values.length >= 1 && t0.values[0].get!string() == source) {
				return t0.remove;
			}
		}
		return null;
	}
	/**
	 * Removes a given layer of any kind.
	 * Returns the Tag of the layer as a backup.
	 */
	public Tag removeLayer(int pri) @trusted {
		Tag backup = layerData[pri];
		layeroutput.remove(pri);
		layerData.remove(pri);
		return backup.remove;
	}
	/**
	 * Adds a layer from external tag.
	 */
	public void addNewLayer(int pri, Tag t, Layer l) @trusted {
		layeroutput[pri] = l;
		layerData[pri] = t;
		root.add(t);
	}
	/**
	 * Adds a new TileLayer to the document.
	 */
	public void addNewTileLayer(int pri, int tX, int tY, int mX, int mY, string name, TileLayer l) @trusted {
		layeroutput[pri] = l;
		l.setRasterizer(getHorizontalResolution, getVerticalResolution);
		layerData[pri] = new Tag(root, "Layer", "Tile", [Value(name), Value(pri), Value(tX), Value(tY), Value(mX), Value(mY)]);
		new Tag(layerData[pri], null, "RenderingMode", [Value("Copy")]);
		//root.add(layerData[pri]);
		//new Tag(null, null, "priority", [Value(pri)]);
	}
	/**
	 * Adds a new tag to a layer.
	 */
	public void addTagToLayer(T...)(int pri, string name, T args) @trusted {
		Value[] vals;
		foreach (arg; args) {
			vals ~= Value(arg);
		}
		new Tag(layerData[pri], null, name, vals);
	}
	/**
	 * Adds a new subtag to a layer's property tag.
	 */
	public void addSubTagToLayersProperty(T...)(int pri, string name, string parent, T args) @trusted {
		Value[] vals;
		foreach (arg; args) {
			vals ~= Value(arg);
		}
		new Tag(layerData[pri].expectTag(parent), null, name, vals);
	}
	/**
	 * Gets the values of a layer's root tag.
	 */
	public Value[] getLayerRootTagValues(int pri) @trusted {
		return layerData[pri].values;
	}
	/**
	 * Gets the values of a layer's tag.
	 */
	public Value[] getLayerTagValues(int pri, string name) @trusted {
		return layerData[pri].expectTag(name).values;
	}
	/**
	 * Gets the values of a layer's tag.
	 */
	public Value[] getLayerPropertyTagValues(int pri, string name, string parent) @trusted {
		return layerData[pri].expectTag(parent).expectTag(name).values;
	}
	/**
	 * Edits the values of a layer's tag. Returns the original values in an array.
	 */
	public Value[] editLayerTagValues(T...)(int pri, string name, T args) @trusted {
		Value[] backup = layerData[pri].expectTag(name).values;
		Value[] vals;
		foreach (arg; args) {
			vals ~= Value(arg);
		}
		//new Tag(layerData[pri], null, name, vals);
		layerData[pri].expectTag(name).values = vals;
		return backup;
	}
	/**
	 * Edits the values of a layer's subtag. Returns the original values in an array.
	 */
	public Value[] editLayerSubtagValues(T...)(int pri, string name, string parent, T args) @trusted {
		Value[] backup = layerData[pri].expectTag(parent).expectTag(name).values;
		Value[] vals;
		foreach (arg; args) {
			vals ~= Value(arg);
		}
		layerData[pri].expectTag(parent).expectTag(name).values = vals;
		return backup;
	}
	/**
	 * Removes a layer's tag.
	 * Returns a backup for undoing.
	 */
	public Tag removeLayerTagValues(int pri, string name) @trusted {
		return layerData[pri].expectTag(name).remove;
	}
	/**
	 * Adds an embedded MapData to a TileLayer.
	 */
	public void addEmbeddedMapData(int pri, ubyte[] base64Code) @trusted {
		layerData[pri].add(new Tag("Embed", "MapData", [Value(base64Code)]));
	}
	///Ditto
	public void addEmbeddedMapData(int pri, MappingElement[] me) @safe {
		import PixelPerfectEngine.system.etc : reinterpretCast;
		addEmbeddedMapData(pri, reinterpretCast!ubyte(me));
	}
	/**
	 * Adds a TileData file to a TileLayer.
	 * Filename must contain relative path.
	 */
	public void addMapDataFile(int pri, string filename, string dataPakSrc = null) @trusted {
		Attribute[] a;
		if (dataPakSrc !is null) a ~= new Attribute("dataPakSrc", Value(dataPakSrc));
		layerData[pri].add(new Tag("File", "MapData", [Value(filename)], a));
	}
	/+///Ditto, but for files found in DataPak archives
	public void addMapDataFile(int pri, string dataPakPath, string filename) @trusted {
		new Tag(layerData[pri], "File", "MapData", [Value(dataPakPath), Value(filename)]);
	}+/
	/**
	 * Removes embedded TileData from a TileLayer.
	 * Returns a backup for undoing.
	 */
	public Tag removeEmbeddedMapData(int pri) @trusted {
		return layerData[pri].expectTag("Embed:MapData").remove;
	}
	/**
	 * Removes a TileData file from a TileLayer.
	 * Returns a backup for undoing.
	 */
	public Tag removeMapDataFile(int pri) @trusted {
		return layerData[pri].expectTag("File:MapData").remove;
	}
	/**
	 * Pulls TileLayer data from the layer, and stores it in the preconfigured location.
	 * Only works with uncompressed data due to the need of recompression.
	 */
	public void pullMapDataFromLayer(int pri) @trusted {
		import PixelPerfectEngine.system.etc : reinterpretCast;
		ITileLayer t = cast(ITileLayer)layeroutput[pri];
		MappingElement[] mapping = t.getMapping;
		if (layerData[pri].getTag("Embed:MapData") !is null) {
			layerData[pri].getTag("Embed:MapData").values[0] = Value(reinterpretCast!ubyte(mapping));
		} else if (layerData[pri].getTag("File:MapData") !is null) {
			string filename = layerData[pri].getTag("File:MapData").getValue!string();
			MapDataHeader mdh = MapDataHeader(layerData[pri].values[3].get!int, layerData[pri].values[4].get!int);
			saveMapFile(mdh, mapping, File(filename, "wb"));
		}

	}
	/**
	 * Adds a tile source file to a TileLayer.
	 */
	public void addTileSourceFile(int pri, string filename, string dataPakSrc = null, int offset = 0) @trusted {
		Attribute[] a;
		if (dataPakSrc !is null) a ~= new Attribute("dataPakSrc", Value(dataPakSrc));
		if (offset) a ~= new Attribute("offset", Value(offset));
		new Tag(layerData[pri],"File", "TileSource", [Value(filename)], a);
	}
	/**
	 * Removes a tile source.
	 * Returns a backup copy.
	 */
	public Tag removeTileSourceFile(int pri, string filename, string dataPakSrc = null) @trusted {
		try {
			auto namespace = layerData[pri].namespaces["File"];
			foreach (t ; namespace.tags) {
				if (t.name == "TileSource" && t.values[0] == filename && t.getAttribute!string("dataPakSrc", null) == dataPakSrc) {
					return t.remove;
				}
			}
		} catch (DOMRangeException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return null;
	}
	/**
	 * Accesses tile source tags in documents for adding extra data (eg. tile names).
	 */
	public Tag getTileSourceTag(int pri, string filename, string dataPakSrc = null) @trusted {
		try {
			auto namespace = layerData[pri].namespaces["File"];
			foreach (t ; namespace.tags) {
				if (t.name == "TileSource" && t.values[0] == filename && t.getAttribute!string("dataPakSrc", null) == dataPakSrc) {
					return t;
				}
			}
		} catch (DOMRangeException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return null;
	}
	/**
	 * Returns all tile sources for a given layer.
	 * Intended to use with a loader.
	 */
	public Tag[] getAllTileSources (int pri) @trusted {
		Tag[] result;
		try {
			auto namespace = layerData[pri].namespaces["File"];
			foreach (t ; namespace.tags) {
				if (t.name == "TileSource") {
					result ~= t;
				}
			}
		} catch (DOMRangeException e) {
			debug writeln(e);
		} catch (Exception e) {
			debug writeln(e);
		}
		return result;
	}
	/**
	 * Adds a palette file source to the document.
	 */
	public Tag addPaletteFile (string filename, string dataPakSrc, int offset) @trusted {
		Attribute[] a;
		if (offset) a ~= new Attribute("offset", Value(offset));
		if (dataPakSrc.length) a ~= new Attribute("dataPakSrc", Value(dataPakSrc));
		return new Tag(root,"File", "Palette", [Value(filename)], a);
	}
	/**
	 * Adds an embedded palette to the document.
	 */
	public Tag addEmbeddedPalette (Color[] c, string name, int offset) @trusted {
		import PixelPerfectEngine.system.etc : reinterpretCast;
		Attribute[] a;
		if (offset) a ~= new Attribute("offset", Value(offset));
		return new Tag(root, "Embed", "Palette", [Value(name), Value(reinterpretCast!ubyte(c))], a);
	}
	/**
	 * Returns whether the given palette file source exists.
	 */
	public bool isPaletteFileExists (string filename/+, string dataPakSrc = ""+/) @trusted {
		foreach (t0 ; root.all.tags) {
			if (t0.getFullName.toString == "File:Palette") {
				if (t0.getValue!string() == filename /+&& t0.getAttribute!string("dataPakSrc", "") == dataPakSrc+/) 
					return true;
			}
		}
		return false;
	}
	/**
	 * Returns the name of the map from metadata.
	 */
	public string getName () @trusted {
		return metadata.getTagValue!string("Name");
	}
	/**
	 * Returns the horizontal resolution.
	 */
	public int getHorizontalResolution () @trusted {
		return metadata.getTag("Resolution").values[0].get!int();
	}
	/**
	 * Returns the vertical resolution.
	 */
	public int getVerticalResolution () @trusted {
		return metadata.getTag("Resolution").values[1].get!int();
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
	public enum MapObjectType {
		box,			///Can be used for collision detection, event marking for scripts, and masking. Has two coordinates.
		/**
		 * Only applicable for SpriteLayer.
		 * Has one coordinate, a horizontal and vertical scaling indicator (int), and a source indicator (int).
		 */
		sprite,
	}
	public int 			pID;		///priority identifier
	public int			gID;		///group identifier (equals with layer number)
	public string		name;		///name of object
	protected MapObjectType	_type;	///type of the object
	public Tag[]		ancillaryTags;	///Tags that hold extra information
	///Returns the type of this object
	public @property MapObjectType type () const @nogc nothrow @safe pure {
		return type;
	}
	///Serializes the object into an SDL tag
	public abstract Tag serialize () @trusted;
	/**
	 * Checks if two objects have the same identifier.
	 */
	public bool opEquals (MapObject rhs) @nogc @safe nothrow pure const {
		return pID == rhs.pID && gID == rhs.gID;
	}
}
/**
 * Implements a Box object. Adds a single Coordinate property to the default MapObject
 */
public class BoxObject : MapObject {
	public Coordinate	position;	///position of object on the layer
	/**
	 * Creates a new instance from scratch.
	 */
	public this (int pID, int gID, string name, Coordinate position) @nogc nothrow @safe pure {
		this.pID = pID;
		this.gID = gID;
		this.name = name;
		this.position = position;
		_type = MapObjectType.box;
	}
	/**
	 * Deserializes itself from a Tag.
	 */
	public this (Tag t, int gID) @trusted {
		name = t.values[0].get!string();
		pID = t.values[1].get!int();
		position = getCoordinate(t);
		this.gID = gID;
		_type = MapObjectType.box;
		//ancillaryTags = t.tags;
		foreach (tag ; t.tags)
			ancillaryTags ~= tag;
	}
	/**
	 * Serializes the object into an SDL tag
	 */
	public override Tag serialize () @trusted {
		return new Tag("Object", "Box", [Value(name), Value(pID)], [new Attribute("position","left",Value(position.left)),
				new Attribute("position","top",Value(position.top)), new Attribute("position","right",Value(position.right)),
				new Attribute("position","bottom",Value(position.bottom))], ancillaryTags);
	}
}
/**
 * Implements a sprite object. Adds a sprite source identifier, X and Y coordinates, and two 1024 based scaling indicator.
 */
public class SpriteObject : MapObject {
	protected int 		_ssID;	///Sprite source identifier
	public int			x;		///X position
	public int			y;		///Y position
	public int			scaleHoriz;	///Horizontal scaling value
	public int			scaleVert;	///Vertical scaling value
	/**
	 * Creates a new instance from scratch.
	 */
	public this (int pID, int gID, string name, int ssID, int x, int y, int scaleHoriz, int scaleVert) {
		this.pID = pID;
		this.gID = gID;
		this.name = name;
		this._ssID = ssID;
		this.x = x;
		this.y = y;
		this.scaleHoriz = scaleHoriz;
		this.scaleVert = scaleVert;
		_type = MapObjectType.sprite;
	}
	/**
	 * Deserializes itself from a Tag.
	 */
	public this (Tag t, int gID) @trusted {
		name = t.values[0].get!string();
		pID = t.values[1].get!int();
		_ssID = t.values[2].get!int();
		x = t.expectAttribute!int("x");
		y = t.expectAttribute!int("y");
		scaleHoriz = t.expectAttribute!int("scaleHoriz");
		scaleVert = t.expectAttribute!int("scaleVert");
		foreach (tag ; t.tags)
			ancillaryTags ~= tag;
	}
	/**
	 * Serializes the object into an SDL tag
	 */
	public override Tag serialize () @trusted {
		return new Tag("Object", "Sprite", [Value(name), Value(pID), Value(_ssID)], [new Attribute("x",Value(x)),
				new Attribute("y",Value(y)), new Attribute("scaleHoriz",Value(scaleHoriz)),
				new Attribute("scaleVert",Value(scaleVert))], ancillaryTags);
	}
}
/**
 * Gets a coordinate out from a Tag's Attributes with standard attribute namings.
 */
public Coordinate getCoordinate(Tag t) @trusted {
	return Coordinate(t.expectAttribute!int("position:left"), t.expectAttribute!int("position:top"),
			t.expectAttribute!int("position:right"), t.expectAttribute!int("position:bottom"));
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
	/+static int opCmp (LayerInfo lhs, LayerInfo rhs) pure @safe @nogc {
		if (lhs.pri > rhs.pri)
			return 1;
		else if (lhs.pri < rhs.pri)
			return -1;
		else
			return 0;
	}+/
	/**
	 * Parses a string as a layer type
	 */
	static LayerType parseLayerTypeString (string s) pure @safe @nogc {
		switch (s) {
			case "tile", "Tile", "TILE":
				return LayerType.tile;
			case "sprite", "Sprite", "SPRITE":
				return LayerType.sprite;
			case "transformableTile", "TransformableTile", "TRANSFORMABLETILE":
				return LayerType.transformableTile;
			default:
				return LayerType.NULL;
		}
	}
}
/**
 * Simple TileInfo struct, mostly for internal communication and loading.
 */
public struct TileInfo {
	wchar		id;		///ID of the tile in wchar format
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
