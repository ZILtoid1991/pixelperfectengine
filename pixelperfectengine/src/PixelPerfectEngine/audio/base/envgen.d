module PixelPerfectEngine.audio.base.envgen;

import std.math : pow;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.envgen module.
 *
 * Contains ADSR envelope generation algorithms.
 */

/**
 * Envelope generator struct.
 *
 * Uses integer arithmetics for speed. Shaping is supported via the `gamma()` and `gammaF()` functions, and a 2.0 g value will make a logarithmic output.
 * Output is between 0 and 16 777 215, or 0.0 and 1.0 for floating point output via `gammaF()`
 */
public struct EnvelopeGenerator {
	/**
	 * Indicates the current stage of the envelope.
	 */
	public enum Stage : ubyte {
		Off,
		Attack,
		Decay,
		Sustain,
		Release,
	}
	//Note: These values have a max value of 0xFF_FF_FF, save for sustain rate, which can be negative. 
	//Decay and sustain rates are dependent on sustain level, so they sould be adjusted accordingly if timings of
	//these must be kept constant.
	public uint			attackRate = 0xFF_FF_FF;	///Sets how long the attack phase will last (less = longer)
	public uint			decayRate;		///Sets how long the decay phase will last (less = longer)
	public uint			sustainLevel = 0xFF_FF_FF;	///Sets the level of sustain.
	public int			sustainControl;	///Controls how the sustain level will change
	public uint			releaseRate = 0xFF_FF_FF;	///Sets how long the release phase will last (less = longer)
	
	//mostly internal status values
	protected ubyte		currStage;		///The current stage of the envelope generator
	protected bool		_keyState;		///If key is on, then it's set to true
	protected bool		_isRunning;		///If set, then the envelope is running
	public bool			isPercussive;	///If true, then the sustain stage is skipped
	protected int		counter;		///The current position of the counter + unshaped output
	public static immutable int maxOutput = 0xFF_FF_FF;///The maximum possible output of the envelope generator
	public static immutable int minOutput = 0;///The minimum possible output of the envelope generator.
	protected static immutable double outConv = 1.0 / cast(double)maxOutput;///Reciprocal for output conversion
	/**
	 * Advances the main counter by one amount.
	 *
	 * Returns the output.
	 */
	public int advance() @nogc @safe pure nothrow {
		final switch (currStage) with (Stage) {
			case Off: break;
			case Attack:
				counter +=attackRate;
				if (counter >= 0xFF_FF_FF) {
					counter = 0xFF_FF_FF;
					currStage = Stage.Decay;
				}
				break;
			case Decay:
				counter -= decayRate;
				if (counter <= sustainLevel) {
					counter = sustainLevel;
					currStage = isPercussive ? Stage.Release : Stage.Sustain;
				}
				break;
			case Sustain:
				counter -= sustainControl;
				if (counter <= 0) {
					counter = 0;
					currStage = Stage.Off;
				} else if (counter >= 0xFF_FF_FF) {
					counter = 0xFF_FF_FF;
					currStage = Stage.Off;
				}
				break;
			case Release:
				counter -= releaseRate;
				if (counter <= 0) {
					counter = 0;
					currStage = Stage.Off;
				}
				break;
		}
		return counter;
	}
	/**
	 * Sets the key position to on.
	 */
	public void keyOn() @nogc @safe pure nothrow {
		counter = 0;
		_keyState = true;
		currStage = Stage.Attack;
	}
	/**
	 * Sets the key position to off.
	 */
	public void keyOff() @nogc @safe pure nothrow {
		_keyState = false;
		currStage = Stage.Release;
	}
	///Returns the current stage
	public ubyte position() @nogc @safe pure nothrow const {
		return currStage;
	}
	///Reads the current output
	public int output() @nogc @safe pure nothrow const {
		return counter;
	}
	///Returns true if the envelope generator is running
	public bool isRunning() @nogc @safe pure nothrow const {
		return _isRunning;
	}
	///Returns true if key is on
	public bool keypos() @nogc @safe pure nothrow const {
		return _keyState;
	}
	///Calculates the gamma of the output
	///Returns the value as a floating-point number between 0.0 and 1.0
	public double gammaF(double g) @nogc @safe pure nothrow const {
		return pow(counter * outConv, g);
	}
	///Calculates the gamma of the output
	///Returns the value as an integer
	public int gamma(double g) @nogc @safe pure nothrow const {
		return cast(int)(gammaF(g) * maxOutput);
	}
}
/**
 * Calculates the rate for an envelope parameter for a given amount of time.
 *
 * time: time in seconds. Can be a fraction of a second.
 * freq: the frequency which the envelope generator is being updated at (e.g. sampling frequency)
 * high: the higher value of the envelope stage.
 * low: the lower value of the envelope stage.
 *
 * Note: The high and low values must be kept in order even in case of an ascending stage.
 */
public uint calculateRate(double time, int freq, uint high = 0xFF_FF_FF, uint low = 0) @nogc @safe pure nothrow {
	double result = cast(double)(high - low) / (freq * time);
	return cast(uint)result;
}