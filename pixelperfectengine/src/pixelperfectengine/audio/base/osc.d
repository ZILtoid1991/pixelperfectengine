module pixelperfectengine.audio.base.osc;

import pixelperfectengine.system.etc : clamp;

/** 
 * An oscillator that generates multiple waveform outputs from a single counter, and allows the mixing of them.
 * Available waveforms:
 * * sawtooth: The basic output of the counter.
 * * triangle: Produced from the counter by using the top-bit of the counter to invert the next 16 bits.
 * * pulse: Produced from the counter with a simple logic of testing the counter against the `pulseWidth` variable.
 * * sawpulse: Sawtooth and pulse logically AND-ed together
 * The amounts can be set to minus, this way the output will be inverted.
 */
public struct MultiTapOsc {
	///The rate of which the oscillator operates at
	protected uint		rate;
	///Current state of the oscillator
	protected uint		counter;
	///Controls the pulse width of the oscillator
	public uint			pulseWidth;
	///Controls the amount of the sawtooth wave (minus means inverting)
	public short		sawAm;
	///Controls the amount of the triangle wave (minus means inverting)
	public short		triAm;
	///Controls the amount of the pulse wave (minus means inverting)
	public short		pulseAm;
	///Controls the amount of the sawpulse wave (minus means inverting)
	public short		sawPulseAm;
	/** 
	 * Returns the integer output of the oscillator.
	 */
	int outputI() @nogc @safe pure nothrow {
		const int pulseOut = (counter >= pulseWidth ? ushort.max : ushort.min);
		const int sawOut = (counter >> 16);
		const int triOut = (counter >> 15 ^ (sawOut & 0x80_00 ? ushort.max : ushort.min) & ushort.max);
		counter += rate;
		return (((pulseOut + short.min) * pulseAm)>>15) + (((sawOut + short.min) * pulseAm)>>15) + 
				(((triOut + short.min) * triAm)>>15) + ((((sawOut & pulseOut) + short.min) * sawPulseAm)>>15);
	}
	/** 
	 * Returns the floating point output of the oscillator
	 * Params:
	 *   bias = Offset of the output.
	 *   invDiv = Inverse divident to convert to a floating-point scale. Equals with 1/divident.
	 */
	double outputF(double bias, double invDiv) @nogc @safe pure nothrow {
		return (outputI() * invDiv) + bias;
	}
	/** 
	 * Sets the rate of the oscillator
	 * Params:
	 *   sampleRate = The current sampling frequency.
	 *   freq = The frequency to set the oscillator.
	 */
	void setRate(int sampleRate, double freq) @nogc @safe pure nothrow {
		double rateD = freq / (sampleRate / cast(double)(1<<16));
		rate = cast(uint)(cast(double)(1<<16) * rateD);
	}
}