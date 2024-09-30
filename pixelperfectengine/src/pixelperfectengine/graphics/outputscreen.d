/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.outputScreen module
 */
module pixelperfectengine.graphics.outputscreen;
import iota.window.oswindow;
import iota.window.types;

import pixelperfectengine.graphics.raster;
import pixelperfectengine.system.exc;
import std.stdio;
import std.conv;
//TODO: File marked for removal!
/+
/**
 * Output window, uses SDL to output the graphics on screen.
 * TODO: Refactor it for use with iota instead!
 */
public class OutputScreen : RefreshListener {
	private void OSWindow window;
	///Constructor. x , y : resolution of the window
	this(string title, ushort w, ushort h) {
		window = new OSWindow(title, title, -1, -1, w, h, WindowCfgFlags.IgnoreMenuKey);
	}
	~this(){
		SDL_DestroyWindow(window);
	}
	///Sets the main raster. Useful for changing rendering resolutions.
	public void setMainRaster(Raster r){
		mainRaster = r;
		//sdlTexture = SDL_CreateTextureFromSurface(renderer, mainRaster.getOutput());
	}
	///Enters into fullscreen mode.
	public void setToFullscreen(const SDL_DisplayMode* videoMode){
		if(SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN)){
			throw new VideoModeException("Error while changing to fullscreen mode!" ~ to!string(SDL_GetError()));
		}
		if(SDL_SetWindowDisplayMode(window, videoMode)){
			throw new VideoModeException("Error while changing to fullscreen mode!" ~ to!string(SDL_GetError()));
		}
	}
	///Changes video mode.
	public void setVideoMode(const SDL_DisplayMode* videoMode){
		/*if(SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN)){
			throw new VideoModeException("Error while changing video mode!" ~ to!string(SDL_GetError()));
		}*/
		if(SDL_SetWindowDisplayMode(window, videoMode)){
			throw new VideoModeException("Error while changing video mode!" ~ to!string(SDL_GetError()));
		}
	}
	///Exits fullscreen mode.
	public void setToWindowed(){
		if(SDL_SetWindowFullscreen(window, SDL_WINDOW_SHOWN)){
			throw new VideoModeException("Error while changing to windowed mode!" ~ to!string(SDL_GetError()));
		}
	}
	///Sets the scaling quality of the program, affects all output screens.
	public static void setScalingQuality(string q){
		switch(q){
			case "0": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0"); break;
			case "1": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1"); break;
			case "2": SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "2"); break;
			default: SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0"); break;
		}

	}
	///Sets the used video driver.
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

	///Displays the output from the raster when invoked.
	public void refreshFinished(){
		//SDL_Rect r = SDL_Rect(0,0,640,480);
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, mainRaster.getOutput,null,null);
		SDL_RenderPresent(renderer);

	}
}+/
