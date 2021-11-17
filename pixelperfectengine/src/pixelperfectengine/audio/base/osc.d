module pixelperfectengine.audio.base.osc;

import pixelperfectengine.system.etc : clamp;
/** 
 * Implements an oscillator base.
 */
public abstract class Oscillator {
	protected float		_frequency;		///The current frequency of the oscillator
	protected int		_slmpFreq;		///Sampling frequency of the output
	/** 
	 * Returns the sampling frequency set in this oscillator.
	 */
	public int slmpFreq() @nogc @safe pure nothrow const {
		return _slmpFreq;
	}
	/** 
	 * Sets the sampling frequency of the oscillator.
	 * In devived classes, this might also change the internal state of the oscillator.
	 */
	public int slmpFreq(int val) @nogc @safe pure nothrow {
		return _slmpFreq = val;
	}
	/** 
	 * Returns the current output frequency of the oscillator.
	 */
	public float frequency() @nogc @safe pure nothrow const {
		return _frequency;
	}
	/**
	 * Sets the new frequency of the oscillator.
	 * In devived classes, this might also change the internal state of the oscillator.
	 */
	public float frequency(float val) @nogc @safe pure nothrow {
		return _frequency = val;
	}

	/**
	 * Generates an output based on the oscillator's internal states.
	 */
	public abstract void generate(float[] output) @nogc pure nothrow;
}
/** 
 * Generates a pulse signal. If set to 0.5, the output will be a perfect square wave.
 */
public class PulseGen : Oscillator {
	protected float			stepRate = 1;
	protected float			position = 0;
	public float			pulseWidth = 0.5;
	public this(int _slmpFreq, float _frequency, float pulseWidth) {
		this._slmpFreq = _slmpFreq;
		frequency = _frequency;
		this.pulseWidth = pulseWidth;
	}
	public override float frequency(float val) {
		_frequency = val;
		stepRate = (1 / _frequency) / _slmpFreq;
		return _frequency;
	}
	public override int slmpFreq(int val) @nogc @safe pure nothrow {
		_slmpFreq = val;
		stepRate = (1 / _frequency) / _slmpFreq;
		return _slmpFreq;
	}
	/**
	 * Generates an output based on the oscillator's internal states.
	 */
	public override void generate(float[] output) @nogc pure nothrow {
		for (size_t i ; i < output.length ; i++) {
			output[i] = position > pulseWidth ? -1 : 1;
			position += stepRate;
			position = position >= 1 ? 0 : position;
		}
	}
}
/** 
 * Generates a variable triangle signal. If shape is set to 0.5, a regular triangle wave will be generated. 0 and 1 
 * will generate regular saw waves. Any inbetween values generate asymmetric triangle waves.
 */
public class TriangleGen : Oscillator {
	protected float			stepRate = 1;
	protected float			position = 0;
	protected float			slopeUp = 2;
	protected float			slopeDown = -2;
	protected float			state = 0;
	public float			shape = 0.5;
	public this(int _slmpFreq, float _frequency, float shape) {
		this._slmpFreq = _slmpFreq;
		frequency = _frequency;
		this.shape = shape;
		recalc();
	}
	protected final void recalc() @nogc @safe pure nothrow {
		stepRate = (1 / _frequency) / _slmpFreq;
		slopeUp = stepRate * 2 * shape;
		slopeDown = stepRate * -2 * (1 - shape);
	}
	public override float frequency(float val) {
		_frequency = val;
		stepRate = (1 / val) / _slmpFreq;
		recalc();
		return _frequency;
	}
	public override void generate(float[] output) @nogc pure nothrow {
		for (size_t i ; i < output.length ; i++) {
			state += position > shape ? slopeDown : slopeUp;
			clamp(state, -1, 1);
			output[i] = state;
			position += stepRate;
			position = position >= 1 ? 0 : position;
		}
	}
}