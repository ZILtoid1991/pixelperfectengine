/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.common module
 */

module pixelperfectengine.system.common;

import bindbc.sdl;

public void initialzeSDL(){
	SDLSupport sdls = loadSDL();
	if(sdls == SDLSupport.noLibrary){
		version(Windows){
			import core.sys.windows.winuser;
			MessageBox(null, "SDL2.DLL was not found in the binary folder!\nIf required, please reinstall this software!",
					"Initialization Error", MB_ICONERROR);
		}else{
			import core.stdc.stdio;
			printf("Initialization error!\nSDL2 library is not installed.\n");
		}
	}
	version(Windows){
		debug
			SDL_SetHint("SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING","1");
	}
}
