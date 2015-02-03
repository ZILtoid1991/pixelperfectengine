/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, layer module
 */
module graphics.layers;

import graphics.sprite;
import std.conv;
import system.etc;
import std.stdio;

//Used mainly to return both the color ID and the transparency at the same time to reduce CPU time.
public struct PixelData {
    public bool alpha;
    public ushort color;
    this(bool a, ushort c){
        alpha = a;
        color = c;
    }
}

public interface ILayer{
    // Returns color.
    public ushort getPixel(ushort x, ushort y);
    // Returns if the said pixel's color is equals with the transparent color index.
    public bool isTransparent(ushort x, ushort y);
    // Returns the PixelData.
    public PixelData getPixelData(ushort x, ushort y);
}

abstract class Layer : ILayer{

    // scrolling position
    private int sX, sY;


    //Absolute scrolling.
    public void scroll(int x, int y){
        sX=x;
        sY=y;
    }
    //Relative scrolling. Positive values scrolls the layer left and up, negative values scrolls the layer down and right.
    public void relScroll(int x, int y){
        sX=sX+x;
        sY=sY+y;
    }
    //Getters for the scroll positions.
    public int getSX(){
        return sX;
    }
    public int getSY(){
        return sY;
    }
}

public class BackgroundLayer : Layer{
    private ushort tileX, tileY, mX, mY;
    private uint totalX, totalY;
    private wchar[] mapping;
    private Tile[wchar] tileSet;
    //Constructor. tX , tY : Set the size of the tiles on the layer.
    this(ushort tX, ushort tY){
        tileX=tX;
        tileY=tY;
    }
    //Gets the the ID of the given element from the mapping. x , y : Position.
    public wchar readMapping(ushort x, ushort y){
        return mapping[x+(mX*y)];
    }
    //Writes to the map. x , y : Position. w : ID of the tile.
    public void writeMapping(ushort x, ushort y, wchar w){
        mapping[x+(mX*y)]=w;
    }
    //Loads a mapping from an array. x , y : Sizes of the mapping. map : an array representing the elements of the map.
    //x*y=map.length
    public void loadMapping(ushort x, ushort y, wchar[] map){
        mX=x;
        mY=y;
        mapping = map;
        totalX=mX*tileX;
        totalY=mY*tileY;
    }
    //Adds a tile to the tileSet. t : The tile. id : The ID in wchar to differentiate between different tiles.
    //IMPORTANT: In the future, adding a tile with a different tile size will result in an exception.
    public void addTile(Tile t, wchar id){
        if(t.getXSize()==tileX && t.getYSize()==tileY){
            tileSet[id]=t;
        }
    }
    //Removes the tile with the ID from the set.
    public void removeTile(wchar id){
        tileSet.remove(id);
    }

    public ushort getPixel(ushort x, ushort y){
        ushort aX = to!ushort((sX+x)%tileX), aY = to!ushort((sY+y)%tileY);
        ushort pX = to!ushort(((sX+x)-aX)/tileX), pY = to!ushort(((sY+y)-aY)/tileY);
        wchar w = readMapping(pX, pY);
        return tileSet[w].readPixel(aX, aY);
    }

    public bool isTransparent(ushort x, ushort y){
        if (((x+sX)>=0&&((x+sX)<totalX))&&((y+sY)>=0&&((y+sY)<totalY))){
            ushort aX = to!ushort((sX+x)%tileX), aY = to!ushort((sY+y)%tileY);
            ushort pX = to!ushort(((sX+x)-aX)/tileX), pY = to!ushort(((sY+y)-aY)/tileY);
            wchar w = readMapping(pX, pY);
            return tileSet[w].isTransparentPixel(aX, aY);
        }
        return true;
    }

    public PixelData getPixelData(ushort x, ushort y){
        if (((x+sX)>=0&&((x+sX)<totalX))&&((y+sY)>=0&&((y+sY)<totalY))){
            ushort aX = to!ushort((sX+x)%tileX), aY = to!ushort((sY+y)%tileY);
            ushort pX = to!ushort(((sX+x)-aX)/tileX), pY = to!ushort(((sY+y)-aY)/tileY);
            wchar w = readMapping(pX, pY);
            return PixelData(tileSet[w].isTransparentPixel(aX, aY), tileSet[w].readPixel(aX, aY));
        }
        return PixelData(true, 0);
    }
}
public class SpriteLayer : Layer{
    public Sprite[int] spriteSet;


    public void addSprite(Sprite s, int n){
        spriteSet[n]=s;
    }
    public void removeSprite(int n){

        spriteSet.remove(n);

    }
/*    public void moveSprite(int n, int x, int y){
        coordinates[spriteSet[n]]=Coordinate(x,y);

    }
    public void relMoveSprite(int n, int x, int y){
        coordinates[spriteSet[n]].x=coordinates[spriteSet[n]].x+x;
        coordinates[spriteSet[n]].y=coordinates[spriteSet[n]].y+y;
    }*/

    public ushort getPixel(ushort x, ushort y){
        foreach(s; spriteSet){
            if(x>=(s.getPosition().xa + sX) && y>=(s.getPosition().ya + sY) && x<(s.getPosition().xb + sX) && y < (s.getPosition().yb + sY)){
                return s.readPixel(to!ushort(x-(s.getPosition().xa + sX)), to!ushort(y-(s.getPosition().ya + sY)));

            }
        }
        return 0;
    }
    public bool isTransparent(ushort x, ushort y){
        foreach(s; spriteSet){
            if(x>=(s.getPosition().xa + sX) && y>=(s.getPosition().ya+sY) && x<(s.getPosition().xb + sX) && y<(s.getPosition().yb + sY)){
                return s.isTransparentPixel(to!ushort(x-(s.getPosition().xa+sX)), to!ushort(y-(s.getPosition().ya+sY)));

            }
        }
        return true;
    }
    public PixelData getPixelData(ushort x, ushort y){
        foreach(s; spriteSet){
            if(x>=(s.getPosition().xa + sX) && y>=(s.getPosition().ya+sY) && x<(s.getPosition().xb + sX) && y<(s.getPosition().yb + sY)){
                //writeln(0);
                return PixelData(s.isTransparentPixel(to!ushort(x-(s.getPosition().xa+sX)), to!ushort(y-(s.getPosition().ya+sY))) , s.readPixel(to!ushort(x-(s.getPosition().xa+sX)), to!ushort(y-(s.getPosition().ya+sY))));

            }
        }
        return PixelData(true, 0);
    }
}

