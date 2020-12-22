module PixelPerfectEngine.collision.objectCollision;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.objectCollision module.
 */

import PixelPerfectEngine.system.advBitArray;

import collections.treemap;
import PixelPerfectEngine.collision.common;
//import PixelPerfectEngine.collision.boxCollision;

/**
 * Object-to-object collision detector.
 */
public class ObjectCollisionDetector {
	ObjectMap			objects;	///Contains all of the objects 
	int					contextID;	///Stores the identifier of this detector
	/**
	 * The delegate where the events will be passed.
	 * Must be set up before using the collision detector.
	 */
	void delegate(ObjectCollisionEvent event)			objectToObjectCollision;
	/**
	 * Tests all shapes against each other
	 */
	public void testAll() {
		foreach (int iA, ref CollisionShape shA; objects) {
			testSingle(iA, &shA);
		}
	}
	/**
	 * Tests a single shape against the others
	 */
	public void testSingle(int objectID) {
		testSingle(objectID, objects.ptrOf(objectID));
	}
	///Ditto
	protected void testSingle(int iA, CollisionShape* shA) {
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
	protected ObjectCollisionEvent testCollision(CollisionShape* shA, CollisionShape* shB) pure {
		if (shA.position.bottom < shB.position.top || shA.position.top > shB.position.bottom || 
				shA.position.right < shB.position.left || shA.position.left > shB.position.right){
			//test if edge collision have happened with side edges
			if (shA.position.bottom >= shB.position.top && shA.position.top <= shB.position.bottom && 
					(shA.position.right - shB.position.left == -1 || shA.position.left - shB.position.right == 1)) {
				//calculate edge collision area
				Coordinate cc;
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
				Coordinate cc;
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
			Coordinate ca, cb, cc; // test area coordinates
			ca.right = shA.position.width;
			ca.bottom = shA.position.height;
			cb.right = shB.position.width;
			cb.bottom = shB.position.height;
			if(shA.position.top >= shB.position.top){
				ca.top += shA.position.top - shB.position.top;
				cc.top = shA.position.top;
			} else {
				cb.top += shB.position.top - shA.position.top;
				cc.top = shB.position.top;
			}
			if(shA.position.bottom >= shB.position.bottom) {
				ca.bottom -= shA.position.bottom - shB.position.bottom;
				cc.bottom = shB.position.bottom;
			} else {
				cb.bottom -= shB.position.bottom - shA.position.bottom;
				cc.bottom = shA.position.bottom; 
			}
			if(shA.position.left >= shB.position.left) {
				ca.left += shA.position.left - shB.position.left;
				cc.left = shA.position.left;
			} else {
				cb.left += shB.position.left - shA.position.left;
				cc.left = shB.position.left;
			}
			if(shA.position.right >= shB.position.right) {
				ca.right -= shA.position.right - shB.position.right;
				cc.right = shB.position.right;
			} else {
				cb.right -= shB.position.right - shA.position.right;
				cc.right = shA.position.right;
			}
			debug {
				assert ((ca.width == cb.width) && (cb.width == cc.width), "Width mismatch error!");
				assert ((ca.height == cb.height) && (cb.height == cc.height), "Height mismatch error!");
			}
			ObjectCollisionEvent event = new ObjectCollisionEvent(shA, shB, contextID, cc, ObjectCollisionEvent.Type.BoxOverlap);
			if(shA.shape !is null && shB.shape !is null) {
				for (int y ; y < cc.width ; y++) {
					for (int x ; x < cc.height ; x++) {
						if (shA.shape.readPixel(ca.left + x, ca.top + y) && shB.shape.readPixel(cb.left + x, cb.top + y)) {
							event.type = ObjectCollisionEvent.Type.ShapeOverlap;
							return event;
						}
					}
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