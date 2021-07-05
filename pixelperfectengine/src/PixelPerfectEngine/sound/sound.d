/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, sound module
 */

module PixelPerfectEngine.sound.sound;

import bindbc.sdl.mixer;
import std.conv;
public import PixelPerfectEngine.system.exc;

/**
 * Implements a simple way for audio playback, through the use of SDL2_mixer.
 *
 * It's simple to use, but very limited and will be deprecated. `PixelPerfect.audio` will implement a system for 
 * plugin-based audio playback,
 * with MIDI 2.0 support.
 *
 * Only one instance should be used.
 */
public class SoundStream {
	/**
	 * The sound samples stored within this class.
	 */
	public Mix_Chunk*[int] soundBank;
	/**
	 * Default CTOR.
	 *
	 * Opens SDL_Mixer, or throws an AudioInitializationException if it fails.
	 */
	public this(){
		loadSDLMixer();
		if(Mix_OpenAudio(44_100, MIX_DEFAULT_FORMAT, 2, 2048) < 0){
			//string msg = Mix_GetError();
			throw new AudioInitializationException(to!string(Mix_GetError()) , __FILE__, __LINE__, null);
		}
	}
	public ~this(){
		foreach(foo ; soundBank){
			Mix_FreeChunk(foo);
		}
	}
	/**
	 * Plays a sound sample from the bank at the specified channel. Can be looped.
	 */
	public void play(int number, int channel = -1, int loops = 0){
		Mix_PlayChannel(channel, soundBank[number], loops);
	}
	/**
	 * Halts the playback on the specified channel.
	 */
	public void halt(int channel){
		Mix_HaltChannel(channel);

	}

}
