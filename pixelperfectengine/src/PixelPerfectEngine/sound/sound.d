/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, sound module
 */

module PixelPerfectEngine.sound.sound;

import bindbc.sdl.mixer;
import std.conv;
public import PixelPerfectEngine.system.exc;

public class SoundStream{
	public Mix_Chunk*[int] soundBank;
	public this(){
		loadSDLMixer();
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
