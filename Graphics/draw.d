/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, graphics.draw module
 */

module graphics.draw;

import std.stdio;
import std.math;
import std.conv;

import graphics.bitmap;
import system.etc;

public class BitmapDrawer
{
	public Bitmap16Bit output;
	public ushort brushTransparency;
	
	public this(int x, int y){
		output = new Bitmap16Bit(x, y);

	}
	
	public void drawLine(int xa, int xb, int ya, int yb, ushort color, int brushsize = 1){
		if(brushsize > 1){
			xa = xa - brushsize / 2;
			xb = xb - brushsize / 2;
			ya = ya - brushsize / 2;
			yb = yb - brushsize / 2;
		}
		if(xa == xb){
			for(int i ; i < brushsize ; i++){
				if(ya < yb){
					for(int j ; j <= (yb - ya) ; j++){

						output.writePixel(xa, ya + j, color);
					}
				}else{
					for(int j ; j >= (yb - ya) ; j--){
						output.writePixel(xa, ya + j, color);
					}
				}
				xa++;
				xb++;
			}
		}else if(ya == yb){
			for(int i ; i < brushsize ; i++){
				if(xa < xb){
					for(int j ; j <= (xb - xa) ; j++){
						output.writePixel(xa + j, ya, color);
					}
				}else{
					for(int j ; j >= (xb - xa) ; j--){
						output.writePixel(xa + j, ya, color);
					}
				}
				ya++;
				yb++;
			}
		}else{
			if(xa < xb){
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((yb - ya) * (yb - ya))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j <= xb - xa ; j++){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya + y, color);
						}
					}
				}else{
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((ya - yb) * (ya - yb))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j <= xb - xa ; j++){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya - y, color);
						}
					}
				}
			}else{
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((yb - ya) * (yb - ya))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j >= xb - xa ; j--){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya + y, color);
						}
					}
				}else{
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((ya - yb) * (ya - yb))));
					for(int i ; i < brushsize ; i++){
						for(int j ; j >= xb - xa ; j--){
							int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
							output.writePixel(xa + j, ya - y, color);
						}
					}
				}
			}
		}
	}
	
	public void drawLine(int xa, int xb, int ya, int yb, Bitmap16Bit brush){
		if(xa == xb){
			
			if(ya < yb){
				for(int j ; j < (yb - ya) ; j++){
					insertBitmap(xa, ya + j, brush);
				}
			}else{
				for(int j ; j > (yb - ya) ; j--){
					insertBitmap(xa, ya + j, brush);
				}
			}
			xa++;
			xb++;
			
		}else if(ya == yb){
			
			if(xa > xb){
				for(int j ; j < (xa - xb) ; j++){
					insertBitmap(xa + j, ya, brush);
				}
			}else{
				for(int j ; j > (xa - xb) ; j--){
					insertBitmap(xa + j, ya, brush);
				}
			}
			ya++;
			yb++;
			
		}else{
			if(xa < xb){
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((yb - ya) * (yb - ya))));
					
					for(int j ; j < xb - xa ; j++){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya + y, brush);
					}
					
				}else{
					int xy = to!int(sqrt(to!double((xb - xa) * (xb - xa)) + ((ya - yb) * (ya - yb))));
					
					for(int j ; j < xb - xa ; j++){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya - y, brush);
					}
					
				}
			}else{
				if(ya < yb){
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((yb - ya) * (yb - ya))));
					
					for(int j ; j > xb - xa ; j--){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya + y, brush);
					}
					
				}else{
					int xy = to!int(sqrt(to!double((xa - xb) * (xa - xb)) + ((ya - yb) * (ya - yb))));
					
					for(int j ; j > xb - xa ; j--){
						int y = to!int(sqrt(to!double(xy * xy) - ((xa + j)*(xa + j))));
						insertBitmap(xa + j, ya - y, brush);
					}
					
				}
			}
		}
	}
	
	public void insertBitmap(int x, int y, Bitmap16Bit bitmap){
		for(int iy ; iy < bitmap.getY ; iy++){
			for(int ix ; ix < bitmap.getX ; ix++){
				if(bitmap.readPixel(ix, iy) != brushTransparency)
					output.writePixel(x + ix, y + iy, bitmap.readPixel(ix, iy));
			}
		}
	}
	public void insertBitmapSlice(int x, int y, Bitmap16Bit bitmap, Coordinate slice){
		//writeln(x,',',y,',',slice.xa,',',slice.ya,',',slice.xb,',',slice.yb);
		for(int iy ; iy < slice.getYSize ; iy++){
			for(int ix ; ix < slice.getXSize ; ix++){
				//writeln(x + ix,',',y + iy);
				if(bitmap.readPixel(ix + slice.xa, iy + slice.ya) != brushTransparency)
					output.writePixel(x + ix, y + iy, bitmap.readPixel(ix + slice.xa, iy + slice.ya));
			}
		}
	}
	
	public void drawRectangle(int xa, int xb, int ya, int yb, ushort color, int brushsize = 1){
		drawLine(xa, xa, ya, yb, color, brushsize);
		drawLine(xb, xb, ya, yb, color, brushsize);
		drawLine(xa, xb, ya, ya, color, brushsize);
		drawLine(xa, xb, yb, yb, color, brushsize);
	}
	
	public void drawRectangle(int xa, int xb, int ya, int yb, Bitmap16Bit brush){
		xa = xa + brush.getX;
		ya = ya + brush.getY;
		xb = xb - brush.getX;
		yb = yb - brush.getY;
		drawLine(xa, xa, ya, yb, brush);
		drawLine(xb, xb, ya, yb, brush);
		drawLine(xa, xb, ya, ya, brush);
		drawLine(xa, xb, yb, yb, brush);
	}
	
	public void drawFilledRectangle(int xa, int xb, int ya, int yb, ushort color){
		//writeln(xa); writeln(ya); writeln(xb); writeln(yb);
		for(int y = ya ; y < yb ; y++){
			for(int x = xa ; x < xb ; x++){

				//writeln(x); writeln(y);
				output.writePixel(x, y, color);
			}
		}
	}
	
	public void drawFilledRectangle(int xa, int xb, int ya, int yb, Bitmap16Bit brush){
		xa = xa + brush.getX;
		ya = ya + brush.getY;
		xb = xb - brush.getX;
		yb = yb - brush.getY;
		for(int i ; i < (yb - ya); i++)
			drawLine(xa, xb, ya + i, ya + i, brush);
	}
	
	public void drawText(int x, int y, wstring text, Bitmap16Bit[wchar] fontSet, int style = 0){
		int length;
		for(int i ; i < text.length ; i++){
			length += fontSet[text[i]].getX;
		}
		//writeln(text);
		if(style == 0){
			x = x - (length / 2);
			y -= fontSet['a'].getY() / 2;
		}
		foreach(wchar c ; text){

			insertBitmap(x, y, fontSet[c]);
			x = x + fontSet[c].getX();
		}
	}
}

