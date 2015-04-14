/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, raster module
 */
module graphics.raster;

import graphics.layers;
import graphics.bitmap;
import derelict.sdl2.sdl;
//public import graphics.color;
import std.conv;
import std.stdio;

//Used to invoke the blitting when the raster finished its work.
public interface RefreshListener{
    public void refreshFinished();
}

//Used to read the output from the raster and show it on the screen.
public interface IRaster{
    public SDL_Surface* getOutput();
}

//Reads the data from the layers, then writes it to an SDL_Surface.
public class Raster : IRaster{
    private ushort rX, rY;
    public SDL_Surface* workpad;
    //IMPORTANT: Color 0 is used as a default and writes it to the raster if it can't find a layer with non-transparent pixel at a given position
    //public Color[ushort] palette;
	//private ubyte[ushort] colorR;
	//private ubyte[ushort] colorG;
	//private ubyte[ushort] colorB;
	private ubyte[] palette;
    private ILayer[] layerList;
    private bool r;
	private int doubleBufferRegisters[2];
    private RefreshListener[int] rL;
	public Bitmap16Bit frameBuffer[2];

    //Default constructor. x and y : represent the resolution of the raster.
    public this(ushort x, ushort y){
        workpad = SDL_CreateRGBSurface(SDL_SWSURFACE, x, y, 32, 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000);
        rX=x;
        rY=y;
		frameBuffer[0] = new Bitmap16Bit(x,y);
		frameBuffer[1] = new Bitmap16Bit(x,y);
	}
    //Adds a RefreshListener to its list.
    public void addRefreshListener(RefreshListener r, int i){
        rL[i] = r;
    }
	//Writes a color at the last position
	public void addColor(ubyte r, ubyte g, ubyte b)	{
		/*colorR[c] = r;
		colorG[c] = g;
		colorB[c] = b;*/

		palette ~= r;
		palette ~= g;
		palette ~= b;
		//palette[c][3] = [r,g,b];
	}

	public void editColor(ushort c, ubyte r, ubyte g, ubyte b){
		palette[c*3] = r;
		palette[(c*3)+1] = g;
		palette[(c*3)+2] = b;
	}

	public void setupPalette(int i){
		palette.length = i * 3;
	}

	public void clearFramebuffer(){
		frameBuffer.clear();
	}
    //Replaces the layer at the given number.
    public void replaceLayer(ILayer l, int i){
		l.setRasterizer(rX, rY);
        layerList[i] = l;
    }
    //Adds a layer at the highest available priority. 0 is highest.
    public void addLayer(ILayer l){
		l.setRasterizer(rX, rY);
        layerList ~= l;
    }
    
    public void refresh(){
        r = true;
		//this.clearFramebuffer();
		if(doubleBufferRegisters[0] == 0){
			doubleBufferRegisters[0] = 1;
			doubleBufferRegisters[1] = 0;
		}else{
			doubleBufferRegisters[0] = 1;
			doubleBufferRegisters[1] = 0;
		}
		for(int i ; i < layerList.length ; i++){
			layerList[i].updateRaster(frameBuffer[doubleBufferRegisters[0]]);
		}
        SDL_LockSurface(workpad);
		frameBuffer[1] = frameBuffer[0];
		writeToWorkpad(frameBuffer[doubleBufferRegisters[1]]);


	
		

        SDL_UnlockSurface(workpad);
        r = false;
		//this.clearFramebuffer();
        foreach(r; rL){
            (&r).refreshFinished;
        }
		//frameBuffer.clear();
    }

	/*public void getPixel(ushort i, ushort j){
		int layerNum = 0;
		bool next;
		do{
			
			if(layerNum == layerList.length){
				writeToWorkpad(i,j,0);
				next = true;
			}
			else{
				PixelData pd = layerList[layerNum].getPixelData(i,j);
				
				if(!pd.alpha){
					//writeln(0);
					writeToWorkpad(i,j,pd.color);
					next = true;
				}
				else{
					layerNum++;
				}
			}
		}while(!next);
	}*/
    //Returns the workpad.
    public SDL_Surface* getOutput(){
        return workpad;
    }
    //Writes a pixel to the given place.
    private void writeToWorkpad(Bitmap16Bit selFB){
        //if(color != 0)        writeln(color);
		for(int y ; y < rY ; y++){
			ushort[] chunk = frameBuffer[1].readRow(y);
			for(int x ; x < rX ; x++){
        		ubyte *p = cast(ubyte*)this.workpad.pixels + y * workpad.pitch + x * 4;
        		*p = palette[(chunk[x]*3)+2]; //colorB[color];
			    p = p +1;
				*p = palette[(chunk[x]*3)+1]; //colorG[color];
    			p = p +1;
				*p = palette[chunk[x]*3]; //colorR[color];
        		p = p +1;
        		*p = 255;
			}
		}

    }
    //Returns if the raster is refreshing.
    public bool isRefreshing(){
        return r;
    }
}
