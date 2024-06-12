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
/**
 * Defines a filter primarily designed for certan control values (volume, etc) to stop them
 * from introducing unwanted noise to the output signal.
 * Filter formula: y_n0 = x * (1 - a) + y_n1 * (a / 3) + y_n2 * (a / 3) + y_n3 * (a / 3).
 */
public struct CtrlValFilter {
	__m128 filterLine = __m128(0);
	__m128 filterCoeff = __m128([1.0, 0.0, 0.0, 0.0]);
	/**
	 * Filters the input value `targetVal` against `filterLine`, then returns the filtered
	 */
	pragma (inline, true)
	float output(float targetVal) @nogc @safe pure nothrow {
		filterLine[0] = targetVal;
		filterLine *= filterCoeff;
		filterLine[0] = filterLine[1] + filterLine[2] + filterLine[3];
		filterLine = cast(__m128)_mm_slli_si128!(4)(cast(__m128i)filterLine);
		return filterLine[1];
	}
	__m128 calculateFilterCoeff(float amount) @nogc @safe pure nothrow {
		filterCoeff[0] = 1.0 - amount;
		filterCoeff[1] = amount / 3.0;
		filterCoeff[2] = filterCoeff[1];
		filterCoeff[3] = filterCoeff[1];
		return filterCoeff;
	}
}
/**
 * Implements a bak of linear interpolation-like filter algorithm.
 * Formula:
 *   output = target * (1.0 - (cntr / steps)) + output_n1 * (cntr / steps)
 * This is optimized for:
 *   output = target * (1.0 - cntrf) + output_n1 * cntrf
 * Where:
 *   cntrf = cntr / steps
 * Or:
 *   cntrf = cntr * factor
 * `factor` is the reciprocal of steps (1 / steps).
 */
struct LinearFilter {
	__m128i cntr;		///Downwards counter. Should be at maximum of 65_535 to get around SSE2 limitations for saturated subtracts
	__m128 out_0 = __m128(0.0);///Currently outputted value
	__m128 out_1 = __m128(0.0);///Previously outputted value
	void setNextTarget(int i, float nextT, int nextC, float factor) pure @nogc nothrow @safe {
		float cntrf = cntr[i] * factor;
		out_1[i] = (out_0[i] * (1.0 - cntrf)) + (out_1[i] * cntrf);
		out_0[i] = nextT;
		cntr[i] = nextC;
	}
	/**
	 * Sets the next target values for the filter.
	 * Params:
	 *   nextT = The next target value for the filter.
	 *   nextC = The next counter amount (should be less or equal than 65535)
	 *   factor = The filter factor for this turn.
	 */
	void setNextTarget(__m128 nextT, __m128i nextC, __m128 factor) pure @nogc nothrow @safe {
		out_1 = output(factor);
		out_0 = nextT;
		cntr = nextC;
	}
	/**
	 * Returns the output and subtracts one from the counter.
	 * Params:
	 *   factor = the filter factor for this turn.
	 */
	pragma(inline, true)
	__m128 output(__m128 factor) pure @nogc nothrow @safe {
		__m128 cntrf = _mm_cvtepi32_ps(cntr) * factor;
		__m128 result = (out_0 * (__m128(1.0) - cntrf)) + (out_1 * cntrf);
		cntr = _mm_subs_epu16(cntr, __m128i(1));
		return result;
	}
}