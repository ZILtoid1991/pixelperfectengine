module collision;

//
// Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
//
// VDP Engine, collision detector module

import std.conv;
import std.stdio;
import std.algorithm;

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
 *Sprite to sprite collision detector. Collision detection is invoked when a sprite is moving, thus only testing sprites that are moving with all other sprites on the list.
 *Implements the SpriteMovementListener interface, be sure you have added you collision detector to all of the sprites that you want to test for collision.
 */
public class CollisionDetector : SpriteMovementListener{
    //private Collidable[string] cList;
    private CollisionListener[string] cl;
	public ISpriteLayer source;
	private Bitmap16Bit[] sourceS;
	private Coordinate[] sourceC;
	private ushort sourceTI;
    public this(){
    }
    //Adds a CollisionListener to its list. c: the CollisionListener you want to add. s: an ID.
    public void addCollisionListener(CollisionListener c, string s){
        cl[s] = c;
    }
    //Removes a CollisionListener based on the ID
    public void removeCollisionListener(string s){
        cl.remove(s);
    }
    
    //Implemented from the SpriteMovementListener interface, invoked when a sprite moves.
    //Tests the sprite that invoked it with all other in its list.
    public void spriteMoved(int ID){
		sourceS = source.getSpriteSet();
		sourceC = source.getCoordinates();
		sourceTI = source.getTransparencyIndex();

		int j = sourceC.length;
		for(int i ; i < j ; i++){
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
		int testpoints[8];
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
        
			
        for(ushort j ; j <= cY ; j++){
			for(ushort i ; i <= cX ; i++){
				if((sourceS[a].readPixel((testpoints[0]+i),(testpoints[2]+j))!=sourceTI) && (sourceS[b].readPixel((testpoints[4]+i),(testpoints[6]+j))!=sourceTI)){
                    return true;
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
	private ISpriteLayer slSource;
	private BLInfo blInfo;
	private CollisionListener[] cl;

	public this(IBackgroundLayer bl, ISpriteLayer sl){
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