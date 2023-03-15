module pixelperfectengine.audio.base.osc;

import pixelperfectengine.system.etc : clamp;
import inteli.emmintrin;

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
	void reset() @nogc @safe pure nothrow {
		counter = 0;
	}
}
/**
 * An oscillator that generates multiple waveforms from 4 separate counters, and allows the mixing of them, with 4 possible
 * outputs.
 * Available waveforms:
 * * sawtooth: The basic output of the counter.
 * * triangle: Produced from the counter by using the top-bit of the counter to invert the next 16 bits.
 * * pulse: Produced from the counter with a simple logic of testing the counter against the `pulseWidth` variable.
 * * sawpulse: Sawtooth and pulse logically AND-ed together
 * The amounts can be set to minus, this way the output will be inverted.
 */
public struct QuadMultitapOsc {
	__m128i		rate;
	__m128i		counter;
	__m128i		pulseWidth;
	__m128i		syncReset;		///Used for sync resets
	short8		levelCtrl01;	///Even number elements set the saw, odd number elements set the triangle amount
	short8		levelCtrl23;	///Even number elements set the pulse, odd number elements set the sawpulse amount
	static immutable __m128i triTest = __m128i(int.max);
	static immutable short8 wordOffset = short8(short.min);
	///Returns the output and forwards the oscillator by a single step.
	__m128i output() @nogc @safe pure nothrow {
		__m128i result;
		const __m128i pulseOut = _mm_cmpgt_epi32(counter, pulseWidth);
		const __m128i triOut = _mm_slli_epi32(_mm_cmpgt_epi32(counter, triTest) ^ counter, 1);
		const __m128i spOut = pulseOut & counter;
		const __m128i out01 = _mm_sub_epi16(_mm_packs_epi32(_mm_srai_epi32(counter, 16), _mm_srai_epi32(triOut, 16)), 
				cast(__m128i)wordOffset);
		const __m128i out23 = _mm_sub_epi16(_mm_packs_epi32(_mm_srai_epi32(pulseOut, 16), _mm_srai_epi32(spOut, 16)), 
				cast(__m128i)wordOffset);
		result = _mm_madd_epi16(out01, cast(__m128i)levelCtrl01) + _mm_madd_epi16(out23, cast(__m128i)levelCtrl23);
		counter += rate;
		return result;
	}
	/**
	 * Implements hard synchronization between the first and any other oscillators.
	 * Template params:
	 *   osc = the oscillator selection.
	 * Note: Hardsync causes noticeable aliasing artifacts on the output.
	 */
	__m128i outputHSync0(int[] osc)() @nogc @safe pure nothrow {
		const int prevState = counter[0];
		__m128i result = output();
		if (prevState > counter[0]) {
			static foreach (i ; osc) {
				counter[i] = 0;
			}
		}
		return result;
	}
	/**
	 * Implements soft synchronization between the first and any other oscillators.
	 * Template params:
	 *   osc = the oscillator selection.
	 */
	__m128i outputSSync0(int[] osc)() @nogc @safe pure nothrow {
		const int prevState = counter[0];
		__m128i result = output();
		if (prevState > counter[0]) {
			static foreach (i ; osc) {
				counter[i] = syncReset[i] * counter[0];
			}
		}
		return result;
	}
	/**
	 * Sets the rate of a given oscillator.
	 * Params:
	 *   sampleRate = Sampling frequency.
	 *   freq = The desired output frequency.
	 *   osc = Number of the oscillator to be set.
	 */
	void setRate(int sampleRate, double freq, int osc) @nogc @safe pure nothrow {
		double cycLen = freq / (sampleRate / cast(double)(1<<16));
		rate[osc] = cast(uint)(cast(double)(1<<16) * cycLen);
		syncReset[osc] = cast(uint)(cast(double)rate[0] / (cast(double)(1<<16) * cycLen));
	}
}