module PixelPerfectEngine.collision.common;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.common module.
 */

public import PixelPerfectEngine.graphics.common;
public import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.layers : MappingElement;
import collections.treemap;

/**
 * Defines a shape for collision detection.
 */
public struct CollisionShape {
	Box				position;	///Position of the shape in the 2D space.
	Bitmap1bit		shape;		///The shape defined by a 1 bit bitmap. Null if custom shape isn't needed
	///default CTOR
	public this(Box position, Bitmap1bit shape) @nogc @safe pure nothrow {
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
		None,
		BoxOverlap,
		BoxEdge,
		ShapeOverlap,
	}
	CollisionShape*	shA;		///The object that was tested against other objects
	CollisionShape*	shB;		///The object that was found colliding with other objects
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
 */
public class TileCollisionEvent {
	/**
	 * Defines individual tile collisions.
	 */
	public struct CollisionContext {
		Box					position;	///Position of the tile
		MappingElement		data;		///Data of the mapping element read out from the layer
	}
	CollisionShape		a;			///Source object
	int					contextID;	///The context of the collision (e.g. layer number)
	CollisionContext[]	overlap;	///All overlapping collisions
	CollisionContext[]	topEdge;	///Top edge collisions if any
	CollisionContext[]	bottomEdge;	///Bottom edge collisions if any
	CollisionContext[]	leftEdge;	///Left edge collisions if any
	CollisionContext[]	rightEdge;	///Right edge collisions if any
}