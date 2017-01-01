/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, core module
 */
module graphics.core;

//import directx.d2d1;
import derelict.sdl2.sdl;
import graphics.raster;
import std.stdio;



/*
 *Output window, uses SDL to output the graphics on screen.
 */
public class OutputWindow : RefreshListener{
    private SDL_Window* window;
    private IRaster mainRaster;
    //private SDL_Texture* sdlTexture;
    public SDL_Renderer* renderer;
    private void* mPixels;
    private int mPitch;

    //Constructor. x , y : resolution of the window
    this(const char* title, ushort x, ushort y){
        SDL_Init(SDL_INIT_VIDEO);
        window = SDL_CreateWindow(title , SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, x, y, SDL_WINDOW_OPENGL);
        if (window == null) {
//                throw new Exception();
        }
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    }
    ~this(){
        SDL_DestroyWindow(window);
        SDL_Quit();

    }
    //Sets main raster.
    public void setMainRaster(IRaster r){
        mainRaster = r;
        //sdlTexture = SDL_CreateTextureFromSurface(renderer, mainRaster.getOutput());
    }
	public static void setScalingQuality(string q){
		switch(q){
			case "0": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0"); break;
			case "1": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1"); break;
			case "2": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "2"); break;
			default: SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0"); break;
		}

	}
	public static void setDriver(string drv){
		switch(drv){
			case "direct3d": SDL_SetHint(SDL_HINT_RENDER_DRIVER, "direct3d"); break;
			case "opengl": SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengl"); break;
			case "opengles2": SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengles2"); break;
			case "opengles": SDL_SetHint(SDL_HINT_RENDER_DRIVER, "opengles"); break;
			case "software": SDL_SetHint(SDL_HINT_RENDER_DRIVER, "software"); break;
			default: break;
		}
	}
    public void init(){
    }
    //Displays the output from the raster when invoked.
    public void refreshFinished(){
		//SDL_Rect r = SDL_Rect(0,0,640,480); 
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, mainRaster.getOutput,null,null);
		SDL_RenderPresent(renderer);

    }
}
