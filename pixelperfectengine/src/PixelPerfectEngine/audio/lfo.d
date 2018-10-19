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
	public ubyte[Length]* table;
	private uint cycle;			///Defines how much needs to be added to the counter each cycle
	private uint forward;		///Steps the oscillator forward>>16 steps
	/**
	 * Steps a single cycle forward in a milisecond
	 */
	public @nogc void step(){
		forward += cycle;

	}
	public @nogc @property nothrow ubyte output(){
		return table[0][forward >> 16 & (Length - 1)];
	}
	/**
	 * Sets the frequency of the LFO.
	 */
	public @nogc void setFrequency(float freq){
		cycle = cast(uint)((freq / 1000f) * 65_536f);
	}
	public @nogc void reset(){
		forward = 0;
	}
}
