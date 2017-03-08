/*
 * Copyright (c) 2015-2017, by Laszlo Szeremi, under Boost license
 * 
 * Pixel Perfect Engine, graphics.common module
 */

module PixelPerfectEngine.graphics.common;

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
	/**
	* Use width() instead for better readability!
	*/
	public deprecated int getXSize(){
		return right-left;
	}
	/**
	* Use height() instead for better readability!
	*/
	public deprecated int getYSize(){
		return bottom-top;
	}
	/** 
	* Returns the width of the represented box.
	*/
	public int width(){
		return right-left;
	}
	/** 
	* Returns the height of the represented box.
	*/
	public int height(){
		return bottom-top;
	}
	/** 
	* Moves the box to the given position.
	*/
	public void move(int x, int y){
		right = x + width();
		bottom = y + height();
		left = x;
		top = y;
	}
	/** 
	* Moves the box by the given values.
	*/
	public void relMove(int x, int y){
		left = left + x;
		right = right + x;
		top = top + y;
		bottom = bottom + y;
	}
}