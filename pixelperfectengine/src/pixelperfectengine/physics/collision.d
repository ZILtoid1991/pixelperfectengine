module pixelperfectengine.physics.collision;

/*
 * Copyright (C) 2015-2020, 2025, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, physics.collision module.
 */

public import pixelperfectengine.graphics.common;
public import pixelperfectengine.graphics.bitmap;
public import pixelperfectengine.graphics.layers : MappingElement2;
import pixelperfectengine.system.ecs;
package import pixelperfectengine.system.memory;
// import collections.treemap;

/**
 * Defines a shape for collision detection.
 */
public struct CollisionShape {
	Box				position;	///Position of the shape in the 2D space.
	Bitmap1Bit		shape;		///The shape defined by a 1 bit bitmap. Null if custom shape isn't needed
	mixin(ECS_MACRO);
	/**
	 * Creates a collision shape.
	 * Params:
	 *   ecsID = Entiry component system ID.
	 *   position = The position of the bounding box.
	 *   shape = The shape of the object in the form of a 1 bit bitmap if any, null otherwise.
	 */
	public this(int ecsID, Box position, Bitmap1Bit shape) @nogc @safe pure nothrow {
		this.ecsID = ecsID;
		this.position = position;
		this.shape = shape;
		//this.id = id;
	}
}
alias ObjectList = OrderedArraySet!CollisionShape;
/**
 * Contains information about an object collision event.
 */
public struct ObjectCollisionEvent {
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
	CollisionShape	shA;		///The object (A) that was tested against other objects
	CollisionShape	shB;		///The object (B) that was found colliding with the source object
	int				idA;		///ID of object A
	int				idB;		///ID of object B
	int				contextID;	///The context of the collision (e.g. tester ID)
	Type			type;		///Type of the object collision
	bool			isExtern;	///Origin (shA) is external
	Box				overlap;	///Overlapping area of the collision
	static ObjectCollisionEvent nullCollision() @nogc @safe pure nothrow {
		return ObjectCollisionEvent(CollisionShape.init, CollisionShape.init, 0, Box.init, Type.None);
	}
	///default CTOR
	public this(CollisionShape shA, CollisionShape shB, int contextID, Box overlap, Type type)
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
	CollisionShape		a;			///Source object
	int					contextID;	///The context of the collision (e.g. layer number)
	int					objectID;	///The ID of the object
	int					numTilesH;	///Number of overlapping tiles horizontally
	int					numTilesV;	///Number of overlapping tiles vertically
	MappingElement2[]	overlapList;///List of overlapping elements
	MappingElement2[] edgeTop() @safe pure nothrow const {
		return overlapList[0..numTilesH].dup;
	}
	MappingElement2[] edgeBottom() @safe pure nothrow const {
		return overlapList[$-numTilesH..$].dup;
	}
	MappingElement2[] edgeLeft() @safe pure nothrow const {
		MappingElement2[] result;
		result.reserve(numTilesV);
		for (int i ; i < numTilesV ; i++) {
			result ~= overlapList[i * numTilesH];
		}
		return result;
	}
	MappingElement2[] edgeRight() @safe pure nothrow const {
		MappingElement2[] result;
		result.reserve(numTilesV);
		for (int i ; i < numTilesV ; i++) {
			result ~= overlapList[(i * numTilesH) + numTilesH - 1];
		}
		return result;
	}
}
