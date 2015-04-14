/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, sprite module
 */
module graphics.sprite;
/*
public import graphics.bitmap;
import collision;
import std.conv;
//import std.stdio;
public import system.etc;



abstract class abstractSprite{
    private Bitmap16Bit source;

    private ushort transparencyColor;
    //Getters for the size
    public ushort getXSize(){
        return source.getX();
    }
    public ushort getYSize(){
        return source.getY();
    }
    //Reads the pixel from the bitmap source
    public ushort readPixel(ushort x, ushort y){
        return source.readPixel(x, y);
    }
    //Checks if the transparency color is equal to the given pixel
    public bool isTransparentPixel(ushort x, ushort y){
        if(source.readPixel(x, y)==transparencyColor){
            return true;
        }
        return false;
    }
}
/*
 *General purpose sprite. Testable for collision, movable, no tie in size.
 *Flipping may result in the source bitmap flipping, will be improved in a later version.
 *//*
public class Sprite : abstractSprite {
	private bool fX, fY;
    //private int posX, posY;
    //private SpriteMovementListener[int] sml;
    //private string id;
    //Constructor. i : Bitmap source tC : Transparency color.
    this(Bitmap16Bit i, ushort tC){
        source = i;
        transparencyColor=tC;

    }
    //Absolute move.
    /*public void move(int x, int y){
        posX = x;
        posY = y;
        invokeMovementEvent();

    }*/
    //Relative move.
    /*public void relMove(int x, int y){
        posX = posX+x;
        posY = posY+y;
        invokeMovementEvent();
    }*/
    //Returns the position of the sprite.
    /*public Coordinate getPosition(){
        return Coordinate(posX, posY, posX + source.getX(), posY + source.getY);
    }
    public Coordinate getIPosition(){
        return Coordinate(posX, posY, posX + source.getX(), posY + source.getY);
    }*/
    //Flips X or Y
	/*
    public void flipX(){
		if(fX){

			fX = false;
		}
		else{

			fX = true;
		}
    }
    public void flipY(){
		if(fY){

			fY = false;
		}
		else{

			fY = true;
		}
    }
	public override ushort readPixel(ushort x, ushort y){
		if(fX){
			x = to!ushort((this.getXSize - 1) - x);
		}
		if(fY){
			y = to!ushort((this.getYSize - 1) - y);
		}
		return super.readPixel(x, y);
	}
    /*public void addSpriteMovementListener(SpriteMovementListener s, int i){
        sml[i] = s;
    }
    //Sets the ID for the collision detector
    public void setID(string s){
        id = s;
    }
    public string getID(){
        return id;
    }
    private void invokeMovementEvent(){
        foreach(s ; sml){
            s.spriteMoved(id);
        }
    }
    public bool getTransparency(ushort x, ushort y){
        return isTransparentPixel(x, y);
    }*/
//}
/*
 *Standard tile for the background layer.
 */
/*public class Tile : abstractSprite {
    this(Bitmap16Bit i, ushort tC){
        source = i;
        transparencyColor=tC;
    }
}*/
