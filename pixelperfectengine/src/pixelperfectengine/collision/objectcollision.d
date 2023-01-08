module pixelperfectengine.collision.objectcollision;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.objectCollision module.
 */

import collections.treemap;
import pixelperfectengine.collision.common;
//import pixelperfectengine.collision.boxCollision;

/**
 * Object-to-object collision detector.
 *
 * Detects whether two objects have been collided, and if yes in what way. Capable of detecting:
 * * Box overlap
 * * Box edge
 * * Shape overlap
 * Note that shape overlap needs a custom collision shape for it to work, and cannot be mirrored in any way, instead
 * "pre-mirroring" has to be done. Also sprite scaling isn't supported by this very collision detector.
 */
public class ObjectCollisionDetector {
	ObjectMap			objects;	///Contains all of the objects 
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
		foreach (int iA, ref CollisionShape shA; objects) {
			testSingle(iA, &shA);
		}
	}
	/**
	 * Tests a single shape (objectID) against the others.
	 */
	public void testSingle(int objectID) {
		testSingle(objectID, objects.ptrOf(objectID));
	}
	///Ditto
	protected final void testSingle(int iA, CollisionShape* shA) {
		foreach (int iB, ref CollisionShape shB; objects) {
			if (iA != iB) {
				ObjectCollisionEvent event = testCollision(shA, &shB);
				if (event! is null) {
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
	protected final ObjectCollisionEvent testCollision(CollisionShape* shA, CollisionShape* shB) pure {
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
				return new ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxEdge);
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
				return new ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxEdge);
			} else return null;
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
				cb.bottom = shA.position.bottom - shB.position.top;
				ca.bottom = shB.position.height - 1;
				cc.bottom = shA.position.bottom;
			} else {
				ca.bottom = shB.position.bottom - shA.position.top;
				cb.bottom = shA.position.height - 1;
				cc.bottom = shB.position.bottom; 
			}
			if (shA.position.left <= shB.position.left) {
				ca.left = shB.position.left - shA.position.left;
				cc.left = shB.position.left;
			} else {
				cb.left = shA.position.left - shB.position.left;
				cc.left = shA.position.left;
			}
			if (shA.position.right <= shB.position.right) {
				cb.right = shA.position.right - shB.position.left;
				ca.right = shB.position.width - 1;
				cc.right = shA.position.right;
			} else {
				ca.right = shB.position.right - shA.position.left;
				cb.right = shA.position.width - 1;
				cc.right = shB.position.right;
			}
			debug {
				assert ((ca.width == cb.width) && (cb.width == cc.width), "Width mismatch error!");
				assert ((ca.height == cb.height) && (cb.height == cc.height), "Height mismatch error!");
			}
			ObjectCollisionEvent event = new ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxOverlap);
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
	/+/**
	 * Tests two boxes together. Returns true on collision.
	 */
	protected bool areColliding(ref CollisionShape a, ref CollisionShape b){
		if (a.position.bottom < b.position.top) return false;
		if (a.position.top > b.position.bottom) return false;
		
		if (a.position.right < b.position.left) return false;
		if (a.position.left > b.position.right) return false;

		Coordinate ca, cb, cc; // test area coordinates
		int cTPA, cTPB; // testpoints 

		// process the test area and calculate the test points
		if(a.position.top >= b.position.top){
			cc.top = a.position.top;
			cTPA = a.position.width() * (a.position.top - b.position.top);
		}else{
			cc.top = b.position.top;
			cTPB = b.position.width() * (b.position.top - a.position.top);
		}
		if(a.position.bottom >= b.position.bottom){
			cc.bottom = b.position.bottom;
		}else{
			cc.bottom = a.position.bottom;
		}
		if(a.position.left >= b.position.left){
			cc.left = a.position.left;
			cTPA += a.position.left - b.position.left;
		}else{
			cc.left = b.position.left;
			cTPB += b.position.left - a.position.left;
		}
		if(a.position.right >= b.position.right){
			cc.right = b.position.right;
		}else{
			cc.right = a.position.right;
		}
		//writeln("A: x: ", ca.left," y: ", ca.top, "B: x: ", cb.left," y: ", cb.top, "C: x: ", cc.left," y: ", cc.top);
		for(int y ; y < cc.height ; y++) {
			for(int x ; x < cc.width ; x++) {

			}
			cTPA += a.position.width();
			cTPB += b.position.width();
		}

		return false;
	}+/
}
