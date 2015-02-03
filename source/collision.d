module collision;

//
// Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
//
// VDP Engine, collision detector module

import std.conv;

import graphics.sprite;
import system.etc;

/*
 *Use this interface to listen to collision events.
 */
public interface CollisionListener{
    //Invoked when two sprites have collided.
    //IMPORTANT: Might generate "mirrored collisions" if both sprites are moving. Be aware of it when you're developing your program.
    public void spriteCollision(string source1, string source2);

}
/*
 *Interface that enables to test sprites on the play field to other sprites.
 */
public interface Collidable{
    //Returns the representing coordinates.
    public Coordinate getIPosition();
    public bool getTransparency(ushort x, ushort y);
    public string getID();
}
/*
 *Sprite to sprite collision detector. Collision detection is invoked when a sprite is moving, thus only testing sprites that are moving with all other sprites on the list.
 *Implements the SpriteMovementListener interface, be sure you have added you collision detector to all of the sprites that you want to test for collision.
 */
public class CollisionDetector : SpriteMovementListener{
    private Collidable[string] cList;
    private CollisionListener[string] cl;
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
    //Adds an element that implemented the Collidable interface.
    public void addCollidable(Collidable c){
        string s = c.getID();
        cList[s] = c;
    }
    //Removes an element that implemented the Collidable interface.
    public void removeCollidable(Collidable c){
        string s = c.getID();
        cList.remove(s);
    }
    //Implemented from the SpriteMovementListener interface, invoked when a sprite moves.
    //Tests the sprite that invoked it with all other in its list.
    public void spriteMoved(string ID){
        Collidable cB = cList[ID];
        foreach(cA ; cList){
            if(!(cA == cB)){
                if(testCollision(cA, cB)){
                    invokeCollisionEvent(cA, cB);
                }
            }

        }
    }
    //Tests if the two objects have collided. Returns true if they had.
    //EXPERIMENTAL: Currently only tests boxes to boxes, pixel-precision testing still does not work,
    public bool testCollision(Collidable a, Collidable b){
        Coordinate ca = a.getIPosition();
        Coordinate cb = b.getIPosition();
        Coordinate cc;
        int cX, cY;
        if (ca.yb < cb.ya) return false;
        if (ca.ya > cb.yb) return false;

        if (ca.xb < cb.xa) return false;
        if (ca.xa > cb.xb) return false;

        /*if (ca.yb > cb.yb) cc.yb = cb.yb;
        else cc.yb = ca.yb;

        if (ca.ya < cb.ya) cc.ya = cb.ya;
        else cc.ya = ca.ya;

        if (ca.xb > cb.xb) cc.xb = cb.xb;
        else cc.xb = ca.xb;

        if (ca.xa < cb.xa) cc.xa = cb.xa;
        else cc.xa = ca.xa;

        cX = cc.xa - cc.xb;
        cY = cc.ya - cc.yb;

        for(int i ; i =< cX ; i++){
            for(int j ; i =< cY ; j++){
                if((sa.readPixel()) && (sb.readPixel())){
                    return true;
                }
            }
        }*/

        return true;
    }
    //Invokes the collision events on all added CollisionListener.
    private void invokeCollisionEvent(Collidable cA, Collidable cB){
        foreach(e; cl){
            e.spriteCollision(cA.getID(), cB.getID());
        }
    }
}

