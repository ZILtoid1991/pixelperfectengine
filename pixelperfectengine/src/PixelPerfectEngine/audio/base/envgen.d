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
 * Uses floating-point arithmetic internally, but output can be converted to integer if needed. Shaping is supported through internal filtering.
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
	//Note: All `rate` values should be between 0.0 and 1.0
	//All `control` values should be between 1.0 and - 1.0
	public float		attackRate;		///Sets how long the attack phase will last (less = longer)
	public float		attackShape;	///Controls the shape of the attack curve
	public float		decayRate;		///Sets how long the decay phase will last (less = longer)
	public float		decayShape;		///Controls the shape of the decay curve
	public float		sustainLevel;	///Sets the level of sustain.
	public float		sustainControl;	///Controls how the sustain level will change
	public float		releaseRate;	///Sets how long the release phase will last (less = longer)
	public float		releaseShape;	///Controls the shape of the release curve
	//status values
	protected ubyte		currStage;		///The current stage of the envelope generator
	protected bool		keyState;		///If key is on, then it's set to true
	public bool			isPercussive;	///If true, then the sustain stage is skipped
	protected float		counter;		///The current position of the counter
	protected float		currValue;		///The current output value of the envelope generator
	
	/**
	 * Advances the main counter by one amount.
	 * Returns the unfiltered output.
	 */
	public float advanceCounter() @nogc @safe pure nothrow {
		final switch (currStage) with stage {
			case Off: break;
			case Attack:
				counter +=attackRate;
				if (counter >= 1.0) {
					counter = 1.0;
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
				if (counter <= 0.0) {
					counter = 0.0;
					currStage = Stage.Off;
				}
				break;
			case Release:
				counter -= releaseRate;
				if (vounter <= 0.0) {
					counter = 0.0;
					currStage = Stage.Off;
				}
				break;
		}
		return counter;
	}
}