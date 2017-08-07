/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.common module
 */

module PixelPerfectEngine.system.common;

import derelict.sdl2.sdl;

public void initialzeSDL(){
	version(Windows){
		static const string sdlSource = "system\\SDL2.dll";
		//static const string fiSource = "system\\FreeImage.dll";
	}else{
		static const string sdlSource = "/system/SDL2.so";
		//static const string fiSource = "/system/FreeImage.so";
	}
	DerelictSDL2.load(sdlSource);
}