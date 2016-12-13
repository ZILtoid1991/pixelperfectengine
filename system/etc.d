module system.etc;

import std.conv;
import std.algorithm.mutation;
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
		wstring ws;
		foreach(c; ss){
			ws ~= c;
		}
		result ~= ws;
	}
	return result;
}
string intToHex(int i, int format = 0){
	string result;
	do{
		switch(i & 0x000F){
			case 1: result ~='1'; break;
			case 2: result ~='2'; break;
			case 3: result ~='3'; break;
			case 4: result ~='4'; break;
			case 5: result ~='5'; break;
			case 6: result ~='6'; break;
			case 7: result ~='7'; break;
			case 8: result ~='8'; break;
			case 9: result ~='9'; break;
			case 10: result ~='A'; break;
			case 11: result ~='B'; break;
			case 12: result ~='C'; break;
			case 13: result ~='D'; break;
			case 14: result ~='E'; break;
			case 15: result ~='F'; break;
			default: result ~='0'; break;
		}
		i = i / 16;
	}while(i > 0);
	if(result.length < format){
		for(int j = result.length ; j < format ; j++){
			result ~= '0';
		}
	}
	reverse(cast(char[])result);
	return result;
}
string intToOct(int i, int format){
	string result;
	do{
		switch(i & 0x0007){
			case 1: result ~='1'; break;
			case 2: result ~='2'; break;
			case 3: result ~='3'; break;
			case 4: result ~='4'; break;
			case 5: result ~='5'; break;
			case 6: result ~='6'; break;
			case 7: result ~='7'; break;
			default: result ~='0'; break;
		}
		i = i / 8;
	}while(i > 0);
	if(result.length < format){
		for(int j = result.length ; j < format ; j++){
			result ~= '0';
		}
	}
	reverse(cast(char[])result);
	return result;
}
int parseHex(string s){
	//std.stdio.writeln(s);
	int result;
	for(int i ; i < s.length; i++){
		result *= 16;
		switch(s[i]){
			case '0': break;
			case '1': result += 1; break;
			case '2': result += 2; break;
			case '3': result += 3; break;
			case '4': result += 4; break;
			case '5': result += 5; break;
			case '6': result += 6; break;
			case '7': result += 7; break;
			case '8': result += 8; break;
			case '9': result += 9; break;
			case 'a','A': result += 10; break;
			case 'b','B': result += 11; break;
			case 'c','C': result += 12; break;
			case 'd','D': result += 13; break;
			case 'e','E': result += 14; break;
			case 'f','F': result += 15; break;
			default: throw new Exception("String cannot be parsed!"); 
		}
	}
	return result;
}