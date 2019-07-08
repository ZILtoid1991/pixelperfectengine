module PixelPerfectEngine.map.mapformat;
/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, map.mapformat module
 */
import sdlang;

import PixelPerfectEngine.graphics.layers;
import std.stdio;
public import PixelPerfectEngine.map.mapdata;

/**
 * Serializes/deserializes PPE map data in SDLang format.
 * Each layer can contain objects (eg. for marking events, clipping, or sprites if applicable), tilemapping (not for SpriteLayers), embedded
 * data such as tilemapping or scripts, and so on.
 * <br/>
 * Note on layer tags:
 * As of this version, additional tags within layers must have individual names. Subtags within a parent also need to have individual names.
 */
public class MapFormat {
	protected Tag[int] 	layerData;	///Layerdata stored as SDLang tags.
	protected Layer[int] layeroutput;	///Used to fast map and object data pullback in editors
	protected Tag 		metadata;	///Stores metadata.
	/**
	 * Creates new instance from scratch.
	 */
	public this (string name, int resX, int resY) @trusted {
		metadata = new Tag(null, null, "Metadata");
		new Tag(metadata, null, "Name", [Value(name)]);
		new Tag(metadata, null, "resX", [Value(resX)]);
		new Tag(metadata, null, "resY", [Value(resY)]);
	}
	/**
	 * Serializes itself from string.
	 */
	public this (string source) @trusted {
		Tag root = parseSource(source);
		//Just quickly go through the tags and sort them out
		foreach (Tag t0 ; root.tags) {
			switch (t0.namespace) {
				case "Layer":
					const int priority = t0.expectTagValue!int("priority");
					layerData[priority] = t0;
					break;
				default:
					if(t0.name == "Metadata"){
						metadata = t0;
					}
					break;
			}
		}
	}
	/**
	 * Returns the requested layer
	 */
	public Layer opIndex(int index) @safe pure {
		return layeroutput.get(index, null);
	}
	/**
	 * Adds a new TileLayer to the document.
	 */
	public void addNewTileLayer(int pri, int tX, int tY, int mX, int mY, string name, TileLayer l) @trusted {
		layeroutput[pri] = l;
		layerData[pri] = new Tag(null, "Layer", "Tile", [Value(name), Value(tX), Value(tY), Value(mX), Value(mY)]);
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
	 * Adds an embedded TileData to a TileLayer.
	 */
	public void addEmbeddedTileData(int pri, string base64Code) @trusted {
		new Tag(layerData[pri], "embed", "tileData", [Value(base64Code)]);
	}
	/**
	 * Adds a TileData file to a TileLayer.
	 * Filename must contain relative path, including datapak files.
	 */
	public void addTileDataFile(int pri, string filename) @trusted {
		new Tag(layerData[pri], "file", "tileData", [Value(filename)]);
	}
	/**
	 * Removes embedded TileData from a TileLayer.
	 * Returns a backup for undoing.
	 */
	public Tag removeEmbeddedTileData(int pri) @trusted {
		return layerData[pri].expectTag("embed:tileData").remove;
	}
	/**
	 * Removes a TileData file from a TileLayer.
	 * Returns a backup for undoing.
	 */
	public Tag removeTileDataFile(int pri) @trusted {
		return layerData[pri].expectTag("file:tileData").remove;
	}
	/**
	 * Pulls TileLayer data from the layer, and stores it in the preconfigured location.
	 */
	public void pullTileDataFromLayer(int pri) @trusted {

		ITileLayer t = cast(ITileLayer)layeroutput[pri];
		MappingElement[] mapping = t.getMapping;
		if (layerData[pri].getTag("embed:tileData") !is null) {
			layerData[pri].getTag("embed:tileData").values[0] = Value(saveMapToBase64(mapping).idup);
		} else if (layerData[pri].getTag("file:tileData") !is null) {
			string filename = layerData[pri].getTag("file:tileData").getValue!string();
			MapDataHeader mdh = MapDataHeader(layerData[pri].values[3].get!int, layerData[pri].values[4].get!int);
			saveMapFile(mdh, mapping, File(filename, "wb"));
		}

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
