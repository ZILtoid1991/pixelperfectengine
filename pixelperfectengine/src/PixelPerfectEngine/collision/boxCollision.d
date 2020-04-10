module PixelPerfectEngine.collision.boxCollision;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.boxCollision module.
 */

import PixelPerfectEngine.graphics.common;
//import PixelPerfectEngine.system.binarySearchTree;
import PixelPerfectEngine.collision;

/**
 * Detects if two boxes have collided.
 * The boxes can be any shape if needed.
 */
public class BoxCollisionDetector{
	public Coordinate[int] objects;
	public CollisionListener cl;


	public this(){
		
	}
	/**
	 * Tests all shapes for each other.
	 */
	public void testAll(){
		foreach(objectA; objects.byKey){
			foreach(objectB; objects.byKey){
				if(objectA != objectB){
					if(areColliding(objects[objectA], objects[objectB])){
						cl.spriteCollision(new CollisionEvent(objectA,objectB));
					}
				}
			}
		}
	}
	/**
	 * Tests a single shape to every other on the list
	 */
	public void testSingle(int objectA){
		foreach(objectB; objects.byKey){
			if(objectA != objectB){
				if(areColliding(objects[objectA], objects[objectB])){
					cl.spriteCollision(new CollisionEvent(objectA,objectB));
				}
			}
		}
	}
	/**
	 * Tests two boxes together. Returns true on collision.
	 */
	public bool areColliding(ref Coordinate a, ref Coordinate b){
		if (a.bottom < b.top) return false;
		if (a.top > b.bottom) return false;
		
		if (a.right < b.left) return false;
		if (a.left > b.right) return false;
		return true;
	}
}