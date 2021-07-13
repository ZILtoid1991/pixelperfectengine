module PixelPerfectEngine.audio.base.envgen;

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
 * Uses integer arithmetics for speed. In the future, it'll have support for shaping the envelope.
 * Output is between 0 and 65 535.
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
	//protected int		currVal;		///The current value + shaped output
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
		return counter >> 8;
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
		return counter >> 8;
	}
	///Returns true if the envelope generator is running
	public bool isRunning() @nogc @safe pure nothrow const {
		return _isRunning;
	}
	///Returns true if key is on
	public bool keypos() @nogc @safe pure nothrow const {
		return _keyState;
	}
}