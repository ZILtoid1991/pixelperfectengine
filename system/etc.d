module system.etc;

import std.conv;
/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, system.etc module
 */

///For simple return of the sprite positions and for other uses where a standard box have to be described.
public struct Coordinate{
    public int xa, ya, xb, yb; ///xa : left ; ya : top ; xb : right ; yb : bottom
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

public wstring[] stringArrayConv(string[] s){
	wstring[] result;
	foreach(ss; s){
		result ~= to!wstring(s);
	}
	return result;
}