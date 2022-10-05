/*
 * Copyright (C) 2015-2019, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, image file extensions module.
 */
module pixelperfectengine.graphics.extensions;

import pixelperfectengine.system.etc;

/**
 * Implements a custom sprite sheet module with variable sprite sizes.
 * Size should be ushort for TGA, and uint for PNG.
 */
public class ObjectSheet (Size = ushort) {
	static enum char[4] IDENTIFIER_PNG = "sHIT";	///Identifier for PNG ancillary chunk
	static enum ushort	IDENTIFIER_TGA = 0xFF01;	///Identifier for TGA developer extension
	/**
	 * Defines the header of an ObjectSheet in the bytestream
	 */
	align(1) public struct Header {
	align(1):
		uint	id;			///Identification if there's multiple of object sheets in a single file
		ushort	nOfIndexes;	///Number of indexes in a single instance
		ubyte	nameLength;	///Length of the name of this instance, can be zero
	}
	//memory initiated header
	uint		id;			///ID of this sheet
	protected string	_name;	///Name with overflow protection
	/**
	 * Defines a single index
	 */
	align(1) public struct Index (bool MemoryResident = true) {
	align(1):
		uint	id;			///ID of this object
		Size	x;			///Top-left origin point of the object (X)
		Size	y;			///Top-left origin point of the object (Y)
		ubyte	width;		///The width of this object
		ubyte	height;		///The height of this object
		byte	displayOffsetX;	///Describes the offset compared to the average when the object needs to be displayed.
		byte	displayOffsetY;	///Describes the offset compared to the average when the object needs to be displayed.
		static if(MemoryResident){
			private string _name;	///Name with character overflow protection
			///Default ctor
			this (uint id, Size x, Size y, ubyte width, ubyte height, byte displayOffsetX, byte displayOffsetY, string _name) 
					@safe pure {
				this.id = id;
				this.x = x;
				this.y = y;
				this.width = width;
				this.height = height;
				this.displayOffsetX = displayOffsetX;
				this.displayOffsetY = displayOffsetY;
				this._name = _name;
			}
			///Converts from a non memory resident type
			this (Index!false src) @safe pure {
				id = src.id;
				x = src.x;
				y = src.y;
				width = src.width;
				height = src.height;
				displayOffsetX = src.displayOffsetX;
				displayOffsetY = src.displayOffsetY;
			}
			///Returns the name of the object
			@property string name () @safe pure nothrow {
				return _name;
			}
			///Sets the name of the object if input's length is less or equal than 255
			@property string name (string val) @safe pure nothrow {
				if(val.length <= ubyte.max){
					_name = val;
				}
				return _name;
			}
		}else{
			ubyte nameLength;		///Length of next field
			///Convert from a memory resident type
			this (Index src) {
				id = src.id;
				x = src.x;
				y = src.y;
				width = src.width;
				height = src.height;
				displayOffsetX = src.displayOffsetX;
				displayOffsetY = src.displayOffsetY;
				nameLength = name.length;
			}
		}
	}
	Index!(true)[]		objects;	///Stores each index as a separate entity.
	/**
	 * Serializes itself from a bytestream.
	 */
	public this(ubyte[] source) @safe pure {
		const Header h = reinterpretGet!Header(source[0..Header.sizeof]);
		source = source[Header.sizeof..$];
		id = h.id;
		indexes.length = h.nOfIndexes;
		if(h.nameLength){
			name = reinterpretCast!char(source[0..h.nameLength]).idup;
			source = source[h.nameLength..$];
		}
		for(ushort i ; i < indexes.length ; i++){
			const Index!false index = reinterpretGet!(Index!(false))(source[0..(Index!(false)).sizeof]);
			source = source[(Index!(false)).sizeof..$];
			indexes[i] = Index!(true)(index);
			if (index.nameLength) {
				indexes[i].name = reinterpretCast!char(source[0..index.nameLength]).idup;
				source = source[index.nameLength..$];
			}
		}
	}
	/**
	 * Creates a new instance from scratch
	 */
	public this(string _name, uint id){
		this._name = _name;
		this.id = id;
	}
	///Returns the name of the object
	@property string name() @safe pure nothrow {
		return _name;
	}
	///Sets the name of the object if input's length is less or equal than 255
	@property string name(string val) @safe pure nothrow {
		if(val.length <= ubyte.max){
			_name = val;
		}
		return _name;
	}
	/**
	 * Serializes itself to bytestream.
	 */
	public ubyte[] serialize() @safe pure {
		ubyte[] result;
		result ~= toStream(Header(id, cast(uint)indexes.length), cast(ubyte)_name.length);
		result ~= reinterpretCast!ubyte(_name.dup);
		foreach (i ; indexes) {
			result ~= toStream(Index!(false)(i));
			if (i.name.length)
				result ~= reinterpretCast!ubyte(i.name.dup);
		}
		return result;
	}
}
/**
 * Implements Adaptive Framerate Animation data, that can be embedded into regular bitmaps.
 * Works with either tile or object sheet extensions.
 */
public class AdaptiveFramerateAnimationData {
	/**
	 * Header for an adaptive framerate animation
	 */
	align(1) public struct Header (bool MemoryResident = true) {
	align(1):
		uint	id;		///Identifier of the animation
		static if (!MemoryResident)
			uint	frames;	///Number of frames associated with this animation
		uint	source;	///Identifier of the object source. f tile extension is used instead of the sheet one, set it to zero.
		static if (!MemoryResident) {
			ubyte	nameLength;	///Length of the namefield
			///Default constructor
			this (uint id, uint frames, uint source, ubyte nameLength){
				this.id = id;
				this.frames = frames;
				this.source = source;
				this.nameLength = nameLength;
			}
			///Converts from memory-resident header
			this (Header!true val) {
				id = val.id;
				nameLength = cast(ubyte)val.name.length;
			}
		} else {
			private string	_name;	///Name of the animation
			///Converts from serialized header
			this (Header!false val) {
				id = val.id;
				source = val.source;
			}
			///Returns the name of the object
			@property string name() @safe pure nothrow {
				return _name;
			}
			///Sets the name of the object if input's length is less or equal than 255
			@property string name(string val) @trusted pure nothrow {
				void _helper() @system pure nothrow {
					_name = val;
				}
				if(val.length <= ubyte.max){
					_helper;
				}
				return _name;
			}
		}
	}
	/**
	 * Each index represents an animation frame
	 */
	align(1) public struct Index {
	align(1):
		uint	sourceID;	///Identifier of the frame source.
		uint	hold;		///Duration of the frame in hundreds of microseconds.
		byte	offsetX;	///Horizontal offset of the frame.
		byte	offsetY;	///Vertical offset of the frame.
	}
	Header!(true) header;		///Header of this instance.
	Index[] frames;		///Frames for each animation.
	/**
	 * Serializes itself from a bytestream.
	 */
	public this (ubyte[] stream) @safe pure {
		const Header!false h = reinterpretGet!(Header!false)(stream[0..(Header!false).sizeof]);
		stream = stream[(Header!false).sizeof..$];
		header = Header!true(h);
		header.name = reinterpretCast!char(stream[0..h.nameLength]).idup;
		stream = stream[h.nameLength..$];
		//rest should be composed of equal sized indexes
		frames = reinterpretCast!Index(stream);
		if (frames.length != h.frames) {
			throw new Exception ("Stream error!");
		}
	}
	/**
	 * Creates a new instance from scratch.
	 */
	public this (string _name, uint id, uint source) {
		header.name = _name;
		header.id = id;
		header.source = source;
	}
	/**
	 * Serializes the object into a bytestream.
	 */
	public ubyte[] serialize () @safe pure {
		ubyte[] result;
		result ~= reinterpretAsArray!(ubyte)(Header!false(header.id, cast(uint)frames.length, header.source, 
				cast(ubyte)header.name.length));
		result ~= reinterpretCast!ubyte(frames);
		return result;
	}
}
// test if all templates compile as they should, then test serialization functions
unittest {
	import std.random;

	//auto rnd = rndGen;

	ObjectSheet!ushort testObj = new ObjectSheet!ushort("Test", 0);
	for(int i ; i < 10 ; i++)
		testObj.objects ~= ObjectSheet!(ushort).Index(uniform!uint(), uniform!ushort(), uniform!ushort(), uniform!ubyte(),
				uniform!ubyte() ,uniform!byte(), uniform!ubyte());
	ubyte[] datastream = testObj.serialize();
	ObjectSheet!ushort secondTestObj = new ObjectSheet!ushort(datastream);
	for(int i ; i < 10 ; i++)
		assert(testObj.objects[i] == secondTestObj.objects[i]);
}
unittest {
	import std.random;

	//auto rnd = rndGen;

	ObjectSheet!uint testObj = new ObjectSheet!uint("Test", 0);
	for(int i ; i < 10 ; i++)
		testObj.objects ~= ObjectSheet!(uint).Index(uniform!uint(), uniform!ushort(), uniform!ushort(), uniform!ubyte(),
				uniform!ubyte() ,uniform!byte(), uniform!ubyte());
	ubyte[] datastream = testObj.serialize();
	ObjectSheet!uint secondTestObj = new ObjectSheet!uint(datastream);
	for(int i ; i < 10 ; i++)
		assert(testObj.objects[i] == secondTestObj.objects[i]);
}
unittest {
	import std.random;

	AdaptiveFramerateAnimationData testObj = new AdaptiveFramerateAnimationData("Test", 0, 0);
	for(int i ; i < 10 ; i++)
		testObj.frames ~= AdaptiveFramerateAnimationData.Index(uniform!uint(), uniform!uint(), uniform!byte(), 
				uniform!byte());
	ubyte[] datastream = testObj.serialize();
	AdaptiveFramerateAnimationData secondTestObj = new AdaptiveFramerateAnimationData(datastream);
	for(int i ; i < 10 ; i++)
		assert(testObj.frames[i] == secondTestObj.frames[i]);
}
