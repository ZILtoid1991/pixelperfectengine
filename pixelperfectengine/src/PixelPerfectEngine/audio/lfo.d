/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.lfo module
 */

module PixelPerfectEngine.audio.lfo;

/**
 * implements a low-frequency oscillator
 */

public struct LowFreqOsc(int Length){
	ubyte[Length] table;
	uint stepping;		///Current position
	uint cycle;			///Defines how much needs to be added to the counter each cycle
	uint forward;		///Steps the oscillator forward>>10 steps

	public @nogc ubyte step(){
		forward += cycle;
		return table[forward & (Length - 1)];
	}
}