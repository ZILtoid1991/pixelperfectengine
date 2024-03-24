module pixelperfectengine.collision.common;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.common module.
 */

public import pixelperfectengine.graphics.common;
public import pixelperfectengine.graphics.bitmap;
public import pixelperfectengine.graphics.layers : MappingElement;
import collections.treemap;

/**
 * Defines a shape for collision detection.
 */
public struct CollisionShape {
	Box				position;	///Position of the shape in the 2D space.
	Bitmap1Bit		shape;		///The shape defined by a 1 bit bitmap. Null if custom shape isn't needed
	/**
	 * Creates a collision shape.
	 * Params:
	 *   position: The position of the bounding box.
	 *   shape: The shape of the object in the form of a 1 bit bitmap if any, null otherwise.
	 */
	public this(Box position, Bitmap1Bit shape) @nogc @safe pure nothrow {
		this.position = position;
		this.shape = shape;
		//this.id = id;
	}
}
alias ObjectMap = TreeMap!(int, CollisionShape);
/**
 * Contains information about an object collision event.
 */
public class ObjectCollisionEvent {
	/**
	 * Defines types of object collisions that can happen
	 */
	public enum Type : ubyte {
		None,				///No collision have been occured
		//BoxCorner,		//TODO: Implement
		BoxOverlap,			///Two boxes are overlapping
		BoxEdge,			///Two edges are one pixel apart
		ShapeOverlap,		///Two shapes overlap each other
	}
	CollisionShape*	shA;		///The object (A) that was tested against other objects
	CollisionShape*	shB;		///The object (B) that was found colliding with the source object
	int				idA;		///ID of object A
	int				idB;		///ID of object B
	int				contextID;	///The context of the collision (e.g. tester ID)
	Box				overlap;	///Overlapping area of the collision
	Type			type;		///Type of the object collision
	///default CTOR
	public this(CollisionShape* shA, CollisionShape* shB, int contextID, Box overlap, Type type) 
			@nogc @safe pure nothrow {
		this.shA = shA;
		this.shB = shB;
		this.contextID = contextID;
		this.overlap = overlap;
		this.type = type;
	}
}
/**
 * Contains information about an object to TileLayer collision event.
 * Custom Bitmap shapes won't be used.
 *
 * Note: Might get removed in the future.
 */
public struct TileCollisionEvent {
	CollisionShape*		a;			///Source object
	int					contextID;	///The context of the collision (e.g. layer number)
	int					objectID;	///The ID of the object
	int					numTilesH;	///Number of overlapping tiles horizontally
	int					numTilesV;	///Number of overlapping tiles vertically
	MappingElement[]	overlapList;///List of overlapping elements
	MappingElement[] edgeTop() @safe pure nothrow const {
		return overlapList[0..numTilesH].dup;
	}
	MappingElement[] edgeBottom() @safe pure nothrow const {
		return overlapList[$-numTilesH..$].dup;
	}
	MappingElement[] edgeLeft() @safe pure nothrow const {
		MappingElement[] result;
		result.reserve(numTilesV);
		for (int i ; i < numTilesV ; i++) {
			result ~= overlapList[i * numTilesH];
		}
		return result;
	}
	MappingElement[] edgeRight() @safe pure nothrow const {
		MappingElement[] result;
		result.reserve(numTilesV);
		for (int i ; i < numTilesV ; i++) {
			result ~= overlapList[(i * numTilesH) + numTilesH - 1];
		}
		return result;
	}
}