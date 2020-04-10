module PixelPerfectEngine.collision.pixelPreciseCollision;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision.pixelPreciseCollision module.
 */

import PixelPerfectEngine.system.advBitArray;

import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.graphics.bitmap;
//import PixelPerfectEngine.system.binarySearchTree;
import PixelPerfectEngine.collision;
import PixelPerfectEngine.collision.boxCollision;

public struct CollisionShape{
	Coordinate position;
	AdvancedBitArray shape;		///
	BitmapAttrib attributes;
}
/**
 * Capable of detecting collision on a pixel basis.
 */
public class PixelPreciseCollisionDetector{
	CollisionShape[int] objects;
	CollisionListener cl;
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
	public void testSingle(int objectA){
		
	}
	/**
	 * Tests two boxes together. Returns true on collision.
	 */
	protected bool areColliding(ref CollisionShape a, ref CollisionShape b){
		if (a.position.bottom < b.position.top) return false;
		if (a.position.top > b.position.bottom) return false;
		
		if (a.position.right < b.position.left) return false;
		if (a.position.left > b.position.right) return false;

		Coordinate cc; // test area coordinates
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
		for(int y ; y < cc.height() ; y++){
			if(a.shape.test(cTPA, cc.width(), b.shape, cTPB)){
				return true;
			}
			cTPA += a.position.width();
			cTPB += b.position.width();
}

		return false;
	}
}