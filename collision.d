module collision;

//
// Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
//
// VDP Engine, collision detector module

import std.conv;
import std.stdio;
import std.algorithm;
import std.bitmanip;

import graphics.sprite;
import graphics.bitmap;
import system.etc;

import graphics.layers;
/*
 *Use this interface to listen to collision events.
 */
public interface CollisionListener{
	//Invoked when two sprites have collided.
	//IMPORTANT: Might generate "mirrored collisions" if both sprites are moving. Be aware of it when you're developing your program.
	public void spriteCollision(int source1, int source2);
	
	public void backgroundCollision(int spriteSource, TileSource[] tileSources);
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
/*
 * After 0.9.1, sprite collisions will no longer be detected from bitmaps, but instead from CollisionModels.
 * Uses Bitarrays for faster detection, custom shapes are possible via XMPs.
 */
public class CollisionModel{
	private BitArray ba;
	private int iX, iY;
	this(int x, int y){
		iX = x;
		iY = y;
		ba = BitArray();
		ba.length(x * y);
	}
	this(int x, int y, bool[] b){
		if(x * y != b.length){
			throw new Exception("Incorrect size of bitarray.");
		}
		iX = x;
		iY = y;
		ba = BitArray(b);

	}
	public bool getBit(int x, int y){
		return ba[x+(iX*y)];
	}
	/*
	 * Gets a row from the CollisionModel of a specified size and position.
	 * Extrabits: 0 = normal; 1 = extra startbit; 2 = extra endbit; 3 = both
	 */
	public BitArray getRowForDetection(int row, int from, int length, ubyte extraBits){
		BitArray ba0 = BitArray();
		if((extraBits == 1 || extraBits == 3) && ba[(iX*row)+from-1]){
			ba0 ~= true;
		}else{
			ba0 ~= false;
		}
		//ba0 ~= ba[(iX*row)+from..(iX*row)+from+length];

		if((extraBits == 2 || extraBits == 3) && ba[(iX*row)+from+length+1]){
			ba0 ~= true;
		}else{
			ba0 ~= false;
		}
		return ba0;
	}
}
/*
 *Sprite to sprite collision detector. Collision detection is invoked when a sprite is moving, thus only testing sprites that are moving with all other sprites on the list.
 *Implements the SpriteMovementListener interface, be sure you have added you collision detector to all of the sprites that you want to test for collision.
 */
public class CollisionDetector : SpriteMovementListener{
	//private Collidable[string] cList;
	private CollisionListener[] cl;
	public ISpriteCollision source;
	//private Bitmap16Bit[int] sourceS;
	private CollisionModel[int] collisionModels;
	private Coordinate[int] sourceC;
	private FlipRegister[int] sourceFR;
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
		cl[] = c;
	}
	//Removes a CollisionListener based on the ID
	public void removeCollisionListener(string s){
		cl.remove(s);
	}
	
	//Implemented from the SpriteMovementListener interface, invoked when a sprite moves.
	//Tests the sprite that invoked it with all other in its list.
	public void spriteMoved(int ID){
		//sourceS = source.getSpriteSet();
		sourceC = source.getCoordinates();
		sourceFR = source.getFlipRegisters();
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
	//Tests if the two objects have collided. Returns true if they had. Pixel precise.
	public bool testCollision(int a, int b){
		Coordinate ca = sourceC[a];
		Coordinate cb = sourceC[b];
		Coordinate cc;
		int cX, cY;
		int[8] testpoints;
		if (ca.yb <= cb.ya) return false;
		if (ca.ya >= cb.yb) return false;
		
		if (ca.xb <= cb.xa) return false;
		if (ca.xa >= cb.xb) return false;
		
		if (ca.yb >= cb.yb){ 
			cc.yb = cb.yb;
			testpoints[3] = (ca.ya - ca.yb - (ca.yb - cb.yb));
			testpoints[7] = (cb.ya - cb.yb);
		}
		else{ 
			cc.yb = ca.yb;
			testpoints[3] = (ca.ya - ca.yb);
			testpoints[7] = (cb.ya - cb.yb - (cb.yb - ca.yb));
		}
		
		if (ca.ya <= cb.ya){ 
			cc.ya = cb.ya;
			testpoints[2] = (cb.ya - ca.ya);
			testpoints[6] = 0;
		}
		else{ 
			cc.ya = ca.ya;
			testpoints[2] = 0;
			testpoints[6] = (ca.ya - cb.ya);
			//writeln(ca.ya);
		}
		
		if (ca.xb >= cb.xb){ 
			cc.xb = cb.xb;
			testpoints[1] = (ca.xa - ca.xb - (ca.xb - cb.yb));
			testpoints[5] = (cb.xa - cb.xb);
		}
		else {
			cc.xb = ca.xb;
			testpoints[1] = (ca.xa - ca.xb);
			testpoints[5] = (cb.xa - cb.xb - (cb.xb - ca.ya));
		}
		
		if (ca.xa <= cb.xa){ 
			cc.xa = cb.xa;
			testpoints[0] = (cb.xa - ca.xa);
			testpoints[4] = 0;
		}
		else {
			cc.xa = ca.xa;
			testpoints[0] = 0;
			testpoints[4] = (ca.xa - cb.xa);
		}
		
		cX = cc.xb - cc.xa;
		cY = cc.yb - cc.ya;
		
		//writeln(testpoints[0]);
		//writeln(testpoints[1]);
		//writeln(testpoints[2]);
		//writeln(testpoints[3]);
		//writeln(testpoints[4]);
		//writeln(testpoints[5]);
		//writeln(testpoints[6]);
		//writeln(testpoints[7]);
		if(sourceFR[b] == FlipRegister.NORM){
			if(sourceFR[a] == FlipRegister.NORM){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.X){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.Y){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else{
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}
		}else if(sourceFR[b] == FlipRegister.X){
			if(sourceFR[a] == FlipRegister.NORM){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.X){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.Y){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}else{
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+j))){
							return true;
						}
					}
				}
			}
		}else if(sourceFR[b] == FlipRegister.Y){
			if(sourceFR[a] == FlipRegister.NORM){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.X){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.Y){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else{
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}
		}else{
			if(sourceFR[a] == FlipRegister.NORM){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.X){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else if(sourceFR[a] == FlipRegister.Y){
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}else{
				for(int j ; j <= cY ; j++){
					for(int i ; i <= cX ; i++){
						if(collisionModels[a].getBit((testpoints[0]+ca.getXSize()-i),(testpoints[2]+ca.getYSize-j)) && collisionModels[b].getBit((testpoints[4]+cb.getXSize-i),(testpoints[6]+cb.getYSize-j))){
							return true;
						}
					}
				}
			}
		}
		return false;
	}
	//Invokes the collision events on all added CollisionListener.
	private void invokeCollisionEvent(int a, int b){
		foreach(e; cl){
			e.spriteCollision(a, b);
		}
	}
}
/*
 *Collision detector without the pixel precision function. 
 */
public class QCollisionDetector : CollisionDetector{
	public this(){
		super();
	}
	public override bool testCollision(int a, int b){
		Coordinate ca = sourceC[a];
		Coordinate cb = sourceC[b];
		
		if (ca.yb <= cb.ya) return false;
		if (ca.ya >= cb.yb) return false;
		
		if (ca.xb <= cb.xa) return false;
		if (ca.xa >= cb.xb) return false;
		return true;
	}
}
/*
 *Tests for background/sprite collision. Preliminary.
 *IMPORTANT! Both layers have to have the same scroll values, or else odd things will happen.
 */
public class BackgroundTester : SpriteMovementListener{
	private IBackgroundLayer blSource;
	private Bitmap16Bit[wchar] blBMP;
	private wchar[] mapping;
	public wchar[] ignoreList;
	private ISpriteCollision slSource;
	private BLInfo blInfo;
	private CollisionListener[] cl;
	
	public this(IBackgroundLayer bl, ISpriteCollision sl){
		blSource = bl;
		slSource = sl;
		blInfo = blSource.getLayerInfo();
	}
	
	public void addCollisionListener(CollisionListener c){
		cl ~= c;
	}
	
	public void spriteMoved(int ID){
		mapping = blSource.getMapping();
		Coordinate spritePos = slSource.getCoordinates()[ID];
		
		int  x1 = (spritePos.xa-(spritePos.xa%blInfo.tileX))/blInfo.tileX, y1 = (spritePos.ya-(spritePos.ya%blInfo.tileY))/blInfo.tileY, 
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
			invokeCollisionEvent(ID, ts);
	}
	private void invokeCollisionEvent(int spriteSource, TileSource[] tileSources){
		foreach(c; cl){
			c.backgroundCollision(spriteSource, tileSources);
		}
	}
}