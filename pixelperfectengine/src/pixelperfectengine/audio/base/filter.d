module pixelperfectengine.audio.base.filter;

import inteli.emmintrin;
import pixelperfectengine.audio.base.func;
import std.math;

/**
 * Defines a biquad infinite response filter bank for various uses.
 */
public struct IIRBank {
   	///All initial values + some precalculated ones.
   	__m128		x1, x2, y1, y2, b0a0, b1a0, b2a0, a1a0, a2a0;
	
   	///Calculates the output of the filter, then stores the input and output values.
	pragma (inline, true)
	__m128 output(__m128 x0) @nogc @safe pure nothrow {
		const __m128 y0 = (b0a0 * x0) + (b1a0 * x1) + (b2a0 * x2) - (a1a0 * y1) - (a2a0 * y2);
		x2 = x1;
		x1 = x0;
		y2 = y1;
		y1 = y0;
		return y0;
	}
	/** 
	 * Sets the filter to the given values.
	 * Params:
	 *   vals = Biquad values.
	 *   n = Filter selector (0 <= n <= 3).
	 */
	void setFilter(BiquadFilterValues vals, int n) @nogc @safe pure nothrow {
		b0a0[n] = vals.b0 / vals.a0;
		b1a0[n] = vals.b1 / vals.a0;
		b2a0[n] = vals.b2 / vals.a0;
		a1a0[n] = vals.a1 / vals.a0;
		a2a0[n] = vals.a2 / vals.a0;
	}
	/// Resets all filter statuses.
	void reset() @nogc @safe pure nothrow {
		x1 = __m128(0);
		x2 = __m128(0);
		y1 = __m128(0);
		y2 = __m128(0);
		b0a0 = __m128(0);
		b1a0 = __m128(0);
		b2a0 = __m128(0);
		a1a0 = __m128(0);
		a2a0 = __m128(0);
	}
	/// Resets filter values, if NaN or infinity has been hit.
	void fixFilter() @nogc @safe pure nothrow {
		for (int i = 0 ; i < 4 ; i++) {
			if (isNaN(x1[i]) || isNaN(x2[i]) || isNaN(y1[i]) || isNaN(y2[i]) || isInfinity(x1[i]) || isInfinity(x2[i]) || 
					isInfinity(y1[i]) || isInfinity(y2[i])) {
				x1[i] = 0.0;
				x2[i] = 0.0;
				y1[i] = 0.0;
				y2[i] = 0.0;
			}
		}
	}
}