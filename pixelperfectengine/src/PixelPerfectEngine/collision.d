module PixelPerfectEngine.collision;

/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision detector module
 */

import std.conv;
import std.stdio;
import std.algorithm;
//import std.bitmanip;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.advBitArray;

import PixelPerfectEngine.graphics.layers;
/*
 *Use this interface to listen to collision events.
 */
public interface CollisionListener{
	//Invoked when two sprites have collided.
	//IMPORTANT: Might generate "mirrored collisions" if both sprites are moving. Be aware of it when you're developing your program.
	public void spriteCollision(CollisionEvent ce);
	
	public void backgroundCollision(CollisionEvent ce);
}
/*
 *Used with the BackgroundDetector. 
 */
public struct TileSource{
	public int x, y;
	public wchar id;
	this(int xx, int yy, wchar idid){
		x = xx;
		y = yy;
		id = idid;
	}
}
/**
 * After 0.9.1, sprite collisions will no longer be detected from bitmaps, but instead from CollisionModels.
 * Uses Bitarrays for faster detection, custom shapes are possible via XMPs.
 */
public class CollisionModel{
	protected AdvancedBitArray ba;
	protected int iX, iY;

	this(int x, int y, AdvancedBitArray b){
		iX = x;
		iY = y;
		ba = b;
		//writeln(b);
	}
	public bool getBit(int x, int y){
		return ba[x+(iX*y)];
	}
	/// Creates a default collision model from a Bitmap32Bit, by pixel transparency.

	/// Creates a default collision model from a Bitmap16Bit, by pixel index.
}
/**
 *Sprite to sprite collision detector. Collision detection is invoked when a sprite is moving, thus only testing sprites that are moving with all other sprites on the list. It tests rows to each other istead of pixels to speed up the process.
 */
public class CollisionDetector : SpriteMovementListener{
	//private Collidable[string] cList;
	public CollisionListener[] cl;
	public ISpriteCollision source;
	//private Bitmap16Bit[int] sourceS;
	private CollisionModel[int] collisionModels;
	private Coordinate[int] sourceC;
	private BitmapAttrib[int] sourceSA;
	//private int[int] sourceSC;
	private ushort sourceTI;
	public this(){
	}
	/*
	 * Adds a CollisionModel. Make sure you match the index on the SpriteLayer and replace the CollisionModel alongside with the sprite
	 */
	public void addCollisionModel(CollisionModel c, int i){
		collisionModels[i] = c;
	}

	public void removeCollisionModel(int i){
		collisionModels.remove(i);
	}

	//Adds a CollisionListener to its list. c: the CollisionListener you want to add. s: an ID.
	public void addCollisionListener(CollisionListener c){
		cl ~= c;
	}
	//Removes a CollisionListener based on the ID
	/*public void removeCollisionListener(string s){
		cl.remove(s);
	}*/
	
	/// Implemented from the SpriteMovementListener interface, invoked when a sprite moves.
	/// Tests the sprite that invoked it with all other in its list.
	public void spriteMoved(int ID){
		
		//sourceS = source.getSpriteSet();
		sourceC = source.getCoordinates();
		sourceSA = source.getSpriteAttributes();
		//sourceSC = source.getSpriteSorter;
		//sourceTI = source.getTransparencyIndex();
		
		foreach(int i ; collisionModels.byKey()){
			
			if(ID == i){
				continue;
			}
			if(testCollision(i, ID)){
				invokeCollisionEvent(ID, i);
			}
			
			
		}
	}
	/// Tests if the two objects have collided. Returns true if they had. Pixel precise.
	public bool testCollision(int a, int b){
		
		Coordinate ca = sourceC[a]; // source
		Coordinate cb = sourceC[b]; // destiny

		// if two sprites don't overlap, then it won't test any further
		if (ca.bottom <= cb.top) return false;
		if (ca.top >= cb.bottom) return false;
		
		if (ca.right <= cb.left) return false;
		if (ca.left >= cb.right) return false;
		
		Coordinate cc; // test area coordinates
		int cTPA, cTPB; // testpoints 

		// process the test area and calculate the test points
		if(ca.top >= cb.top){
			cc.top = ca.top;
			cTPA = ca.width() * (ca.top - cb.top);
		}else{
			cc.top = cb.top;
			cTPB = cb.width() * (cb.top - ca.top);
		}
		if(ca.bottom >= cb.bottom){
			cc.bottom = cb.bottom;
		}else{
			cc.bottom = ca.bottom;
		}
		if(ca.left >= cb.left){
			cc.left = ca.left;
			cTPA += ca.left - cb.left;
		}else{
			cc.left = cb.left;
			cTPB += cb.left - ca.left;
		}
		if(ca.right >= cb.right){
			cc.right = cb.right;
		}else{
			cc.right = ca.right;
		}
		//writeln("A: x: ", ca.left," y: ", ca.top, "B: x: ", cb.left," y: ", cb.top, "C: x: ", cc.left," y: ", cc.top);
		for(int y ; y < cc.height() ; y++){
			if(collisionModels[a].ba.test(cTPA, cc.width(), collisionModels[b].ba, cTPB)){
				return true;
			}
			cTPA += ca.width();
			cTPB += cb.width();
		}

		return false;
	}
	//Invokes the collision events on all added CollisionListener.
	private void invokeCollisionEvent(int a, int b){
		foreach(e; cl){
			e.spriteCollision(new CollisionEvent(a,b,a,b,sourceC[a],sourceC[b]));
		}
	}
}
/**
 *Collision detector without the pixel precision function. 
 */
public class QCollisionDetector : CollisionDetector{
	public this(){
		super();
	}
	public override bool testCollision(int a, int b){
		Coordinate ca = sourceC[a];
		Coordinate cb = sourceC[b];
		
		if (ca.bottom <= cb.top) return false;
		if (ca.top >= cb.bottom) return false;
		
		if (ca.right <= cb.left) return false;
		if (ca.left >= cb.right) return false;
		return true;
	}
}
/*
 *Tests for background/sprite collision. Preliminary.
 *IMPORTANT! Both layers have to have the same scroll values, or else odd things will happen.
 */
public class BackgroundTester : SpriteMovementListener{
	private ITileLayer blSource;
	private Bitmap16Bit[wchar] blBMP;
	private wchar[] mapping;
	public wchar[] ignoreList;
	private ISpriteCollision slSource;
	private BLInfo blInfo;
	private CollisionListener[] cl;
	
	public this(ITileLayer bl, ISpriteCollision sl){
		blSource = bl;
		slSource = sl;
		blInfo = blSource.getLayerInfo();
	}
	
	public void addCollisionListener(CollisionListener c){
		cl ~= c;
	}
	
	public void spriteMoved(int ID){
		/*mapping = blSource.getMapping();
		Coordinate spritePos = slSource.getCoordinates()[ID];
		
		int  x1 = (spritePos.left-(spritePos.left%blInfo.tileX))/blInfo.tileX, y1 = (spritePos.ya-(spritePos.ya%blInfo.tileY))/blInfo.tileY, 
			x2 = (spritePos.xb-(spritePos.xb%blInfo.tileX))/blInfo.tileX, y2 = (spritePos.yb-(spritePos.yb%blInfo.tileY))/blInfo.tileY;
		TileSource[] ts;
		if(x1 >= 0 && y1 >= 0){
			for(int y = y1; y <= y2 ; y++){
				
				for(int x = x1 ; x <= x2 ; x++){
					if(spritePos.getXSize <= x * blInfo.tileX){
						wchar idT = mapping[x+(blInfo.mX*y)];
						
						if(!canFind(ignoreList, idT)){
							//writeln(idT);
							ts ~= TileSource(x, y, idT);
						}
					}
				}
			}
		}
		if(ts.length > 0)
			invokeCollisionEvent(ID, ts);*/
	}
	private void invokeCollisionEvent(int spriteSource, TileSource[] tileSources){

	}
}
public class CollisionEvent{
	public int sourceA, sourceB, hitboxA, hitboxB;		/// A = object that called the detection.
	public Coordinate posA, posB;
	public wchar[] top, bottom, left, right;

	public this(int sourceA, int sourceB, int hitboxA, int hitboxB, Coordinate posA, Coordinate posB){
		this.sourceA = sourceA;
		this.sourceB = sourceB;
		this.hitboxA = hitboxA;
		this.hitboxB = hitboxB;
		this.posA = posA;
		this.posB = posB;
	}
}