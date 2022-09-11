module pixelperfectengine.audio.base.envgen;

import std.math : sqrt, pow;

import pixelperfectengine.system.etc : clamp;
import pixelperfectengine.audio.base.func : fastPow;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.envgen module.
 *
 * Contains ADSR envelop generation algorithms.
 */

/**
 * ADSR Envelop generator struct.
 *
 * Uses floating-point arithmetics, since most targets will use that.
 * Shaping is done through the shpF() and shp() functions. A 0.5 value should return a mostly linear output, and a
 * 0.25 an "audio-grade logarithmic" for volume, but since the calculation is optimized for speed rather than accuracy, 
 * there will be imperfections.
 */
public struct ADSREnvelopGenerator {
	/**
	 * Indicates the current stage of the envelop.
	 */
	public enum Stage : ubyte {
		Off,
		Attack,
		Decay,
		Sustain,
		Release,
	}
	//Note: These values have a max value of 1.0, save for sustain rate, which can be negative. 
	//Decay and sustain rates are dependent on sustain level, so they sould be adjusted accordingly if timings of
	//these must be kept constant.
	public double		attackRate = 1.0;	///Sets how long the attack phase will last (less = longer)
	public double		decayRate = 0.0;	///Sets how long the decay phase will last (less = longer)
	public double		sustainLevel = 1.0;	///Sets the level of sustain.
	public double		sustainControl = 0.0;///Controls how the sustain level will change (between -1.0 and 1.0)
	public double		releaseRate = 1.0;	///Sets how long the release phase will last (less = longer)
	
	//mostly internal status values
	protected double	counter	=	0;	///The current position of the counter + unshaped output
	protected ubyte		currStage;		///The current stage of the envelop generator
	protected bool		_keyState;		///If key is on, then it's set to true
	protected bool		_isRunning;		///If set, then the envelop is running
	public bool			isPercussive;	///If true, then the sustain stage is skipped
	public static immutable double maxOutput = 1.0;///The maximum possible output of the envelop generator
	public static immutable double minOutput = 0.0;///The minimum possible output of the envelop generator.
	/**
	 * Advances the main counter by one amount.
	 *
	 * Returns the output.
	 */
	public double advance() @nogc @safe pure nothrow {
		final switch (currStage) with (Stage) {
			case Off: break;
			case Attack:
				counter +=attackRate;
				if (counter >= maxOutput) {
					counter = maxOutput;
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
				if (counter <= minOutput) {
					counter = minOutput;
					currStage = Stage.Off;
				} else if (counter >= maxOutput) {
					counter = maxOutput;
					currStage = Stage.Off;
				}
				break;
			case Release:
				counter -= releaseRate;
				if (counter <= minOutput) {
					counter = minOutput;
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
	 * Sets the key position to on (no reset of counter).
	 */
	public void keyOnNoReset() @nogc @safe pure nothrow {
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
	///Returns the current output as a floating-point value, between 0.0 and 1.0
	public double output() @nogc @safe pure nothrow const {
		return counter;
	}
	///Returns true if the envelop generator is running
	public bool isRunning() @nogc @safe pure nothrow const {
		return _isRunning;
	}
	///Returns true if key is on
	public bool keypos() @nogc @safe pure nothrow const {
		return _keyState;
	}
	///Changes the shape of the output using a fast and very crude power of function.
	///Output is returned as a floating-point value between 0.0 and 1.0
	public double shp(double g) @nogc @safe pure nothrow const {
		//return g + (1 - counter) * (1 - counter) * (0 - g) + counter * counter * (1 - g);
		/+const double c_2 = counter * counter;
		return -2 * c_2 * g + c_2 + 2 * counter * g;+/
		double res = fastPow(counter, 2 + (g - 0.5) * 1.5);
		return clamp(res, 0.0, 1.0);
	}
	
}
/**
 * Calculates the rate for an envelop parameter for a given amount of time.
 *
 * time: time in seconds. Can be a fraction of a second.
 * freq: the frequency which the envelope generator is being updated at (e.g. sampling frequency)
 * high: the higher value of the envelope stage.
 * low: the lower value of the envelope stage.
 *
 * Note: The high and low values must be kept in order even in case of an ascending stage.
 */
public double calculateRate(double time, int freq, double high = ADSREnvelopGenerator.maxOutput, 
		double low = ADSREnvelopGenerator.minOutput) @nogc @safe pure nothrow {
	return (high - low) / (freq * time);
	
}