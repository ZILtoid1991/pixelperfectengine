module pixelperfectengine.physics.objectcollision;

/*
 * Copyright (C) 2015-2020, 2025, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, physics.objectCollision module.
 */

import collections.treemap;
import pixelperfectengine.physics.collision;
//import pixelperfectengine.collision.boxCollision;

/**
 * Object-to-object collision detector.
 *
 * Detects whether two objects have been collided, and if yes in what way. Capable of detecting:
 * * Box overlap
 * * Box edge
 * * Shape overlap
 * Note that shape overlap needs a custom collision shape for it to work, and cannot be mirrored in any way, instead
 * "pre-mirroring" has to be done. Also sprite scaling isn't supported by this very collision detector for custom shapes.
 */
public class ObjectCollisionDetector {
	ObjectList			objects;	///Contains all of the objects
	int					contextID;	///Stores the identifier of this detector
	/**
	 * The delegate where the events will be passed.
	 * Must be set up before using the collision detector.
	 */
	protected void delegate(ObjectCollisionEvent event)			objectToObjectCollision;
	/**
	 * Default CTOR that initializes the objectToObjectCollision, and contextID.
	 */
	public this (void delegate(ObjectCollisionEvent event) objectToObjectCollision, int contextID) @safe pure {
		assert(objectToObjectCollision !is null, "Delegate `objectToObjectCollision` must be a non-null value!");
		this.objectToObjectCollision = objectToObjectCollision;
		this.contextID = contextID;
	}
	/**
	 * Tests all shapes against each other
	 */
	public void testAll() {
		foreach (ref CollisionShape shA; objects) {
			int iA = shA.ecsID;
			testSingle(iA, &shA);
		}
	}
	/**
	 * Tests a single shape (objectID) against the others.
	 */
	public void testSingle(int objectID) {
		testSingle(objectID, &objects[objects.searchIndexBy(objectID)]);
	}
	///Tests a single shape against the others (internal).
	protected final void testSingle(int iA, CollisionShape* shA) {
		foreach (ref CollisionShape shB; objects) {
			int iB = shB.ecsID;
			if (iA != iB) {
				ObjectCollisionEvent event = testCollision(shA, &shB);
				if (event.type != ObjectCollisionEvent.Type.None) {
					event.idA = iA;
					event.idB = iB;
					objectToObjectCollision(event);
				}
			}
		}
	}
	/**
	 * Tests two objects. Calls cl if collision have happened, with the appropriate values.
	 */
	protected final ObjectCollisionEvent testCollision(CollisionShape* shA, CollisionShape* shB) @nogc pure nothrow {
		if (shA.position.bottom < shB.position.top || shA.position.top > shB.position.bottom || 
				shA.position.right < shB.position.left || shA.position.left > shB.position.right){
			//test if edge collision have happened with side edges
			if (shA.position.bottom >= shB.position.top && shA.position.top <= shB.position.bottom && 
					(shA.position.right - shB.position.left == -1 || shA.position.left - shB.position.right == 1)) {
				//calculate edge collision area
				Box cc;
				if(shA.position.top >= shB.position.top)
					cc.top = shA.position.top;
				else
					cc.top = shB.position.top;
				if(shA.position.bottom >= shB.position.bottom)
					cc.bottom = shB.position.bottom;
				else
					cc.bottom = shA.position.bottom;
				if (shA.position.right < shB.position.left) {
					cc.left = shA.position.right;
					cc.right = shB.position.left;
				} else {
					cc.left = shB.position.right;
					cc.right = shA.position.left;
				}
				return ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxEdge);
			} else if (shA.position.right >= shB.position.left && shA.position.left <= shB.position.right && 
					(shA.position.bottom - shB.position.top == -1 || shA.position.top - shB.position.bottom == 1)) {
				//calculate edge collision area
				Box cc;
				if(shA.position.left >= shB.position.left)
					cc.left = shA.position.left;
				else
					cc.left = shB.position.left;
				if(shA.position.right >= shB.position.right)
					cc.right = shB.position.right;
				else
					cc.right = shA.position.right;
				if (shA.position.bottom < shB.position.top) {
					cc.top = shA.position.bottom;
					cc.bottom = shB.position.top;
				} else {
					cc.top = shB.position.bottom;
					cc.bottom = shA.position.top;
				}
				return ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxEdge);
			} else return ObjectCollisionEvent.nullCollision;
		} else {
			//if there's a bitmap for both shapes, then proceed to per-pixel testing
			Box ca, cb, cc; // test area coordinates
			//ca: Shape a's overlap area
			//cb: Shape b's overlap area
			//cc: global overlap area
			//
			if (shA.position.top <= shB.position.top) {
				ca.top = shB.position.top - shA.position.top;
				cc.top = shB.position.top;
			} else {
				cb.top = shA.position.top - shB.position.top;
				cc.top = shA.position.top;
			}
			if(shA.position.bottom <= shB.position.bottom) {
				cc.bottom = shA.position.bottom;
				//cb.bottom = shB.position.bottom - shA.position.bottom;
				//ca.bottom = shB.position.height - 1;
			} else {
				cc.bottom = shB.position.bottom;
				//ca.bottom = shA.position.bottom - shB.position.bottom;
				//cb.bottom = shA.position.height - 1;
			}
			ca.bottom = ca.top + cc.height - 1;
			cb.bottom = cb.top + cc.height - 1;
			if (shA.position.left <= shB.position.left) {
				ca.left = shB.position.left - shA.position.left;
				cc.left = shB.position.left;
			} else {
				cb.left = shA.position.left - shB.position.left;
				cc.left = shA.position.left;
			}
			if (shA.position.right <= shB.position.right) {
				cc.right = shA.position.right;
				//cb.right = shB.position.right - shA.position.right;
				//ca.right = shB.position.width - 1;
			} else {
				cc.right = shB.position.right;
				//ca.right = shA.position.right - shB.position.right;
				//cb.right = shA.position.width - 1;
			}
			ca.right = ca.left + cc.width - 1;
			cb.right = cb.left + cc.width - 1;
			debug {
				assert ((ca.width == cb.width) && (cb.width == cc.width), "Width mismatch error!");
				assert ((ca.height == cb.height) && (cb.height == cc.height), "Height mismatch error!");
			}
			ObjectCollisionEvent event = ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxOverlap);
			if(shA.shape !is null && shB.shape !is null) {
				/+for (int y ; y < cc.height ; y++) {
					for (int x ; x < cc.width ; x++) {
						if (shA.shape.readPixel(ca.left + x, ca.top + y) && shB.shape.readPixel(cb.left + x, cb.top + y)) {
							event.type = ObjectCollisionEvent.Type.ShapeOverlap;
							return event;
						}
					}
				}+/
				if (shA.position.left <= shB.position.left) {
					if (shA.shape.testCollision(ca.top, ca.height, shB.shape, cb.top, ca.left, cb.width))
						event.type = ObjectCollisionEvent.Type.ShapeOverlap;
				} else {
					if (shB.shape.testCollision(cb.top, cb.height, shA.shape, ca.top, cb.left, cb.width))
						event.type = ObjectCollisionEvent.Type.ShapeOverlap;
				}
			}
			return event;
		}
	}
	
}
