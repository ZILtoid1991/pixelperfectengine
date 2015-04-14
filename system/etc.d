module system.etc;

/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, system.etc module
 */

//Coordinate for simple return of the sprite positions.
public struct Coordinate{
    public int xa, ya, xb, yb; //xa : left ; ya : top ; xb : right ; yb : bottom
    this(int xi, int yi, int xj, int yj){
        xa=xi;
        ya=yi;
        xb=xj;
        yb=yj;
    }
	public int getXSize(){
		return xb-xa;
	}
	public int getYSize(){
		return yb-ya;
	}
	public void move(int x, int y){
		xb = x + getXSize();
		yb = y + getYSize();
		xa = x;
		ya = y;
	}
	public void relMove(int x, int y){
		xa = xa + x;
		xb = xb + x;
		ya = ya + y;
		yb = yb + y;
	}
}
