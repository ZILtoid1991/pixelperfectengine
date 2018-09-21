import derelict.sdl2.sdl;
import PixelPerfectEngine.system.common;
import editor;

int main(string[] argv){
	initialzeSDL();
	debug SDL_SetHint(SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING, "1");
	
    if(argv.length > 1){
		
	}
	Editor e = new Editor();
	e.whereTheMagicHappens();

    return 0;
}