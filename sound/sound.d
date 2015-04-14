module sound.sound;

import derelict.sdl2.mixer;
import derelict.sdl2.sdl;
import std.conv;
public import system.exc;

public class SoundStream{
	public Mix_Chunk*[int] soundBank;
	public this(){
		DerelictSDL2Mixer.load();
		if(Mix_OpenAudio( 44100, MIX_DEFAULT_FORMAT, 2, 2048 ) < 0){
			//string msg = Mix_GetError();
			throw new AudioInitializationException(to!string(Mix_GetError()) , __FILE__, __LINE__, null);
		}
	}
	public ~this(){
		foreach(foo ; soundBank){
			Mix_FreeChunk(foo);
		}
	}
	public void play(int number, int channel, int loops){
		Mix_PlayChannel(channel, soundBank[number], loops);

	}
	public void halt(int channel){
		Mix_HaltChannel(channel);

	}

}
