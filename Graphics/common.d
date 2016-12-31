/*
 * Copyright (c) 2015-2017, by Laszlo Szeremi, under Boost license
 * 
 * Pixel Perfect Engine, graphics.common module
 */

module graphics.common;

/**
 * Represents a box on a 2D field.
 */
public struct Coordinate{
	public int left, top, right, bottom;
	this(int left, int top, int right, int bottom){
		this.left=left;
		this.top=top;
		this.right=right;
		this.bottom=bottom;
	}
	public int getXSize(){
		return right-left;
	}
	public int getYSize(){
		return bottom-top;
	}
	public void move(int x, int y){
		right = x + getXSize();
		bottom = y + getYSize();
		left = x;
		top = y;
	}
	public void relMove(int x, int y){
		left = left + x;
		right = right + x;
		top = top + y;
		bottom = bottom + y;
	}
}