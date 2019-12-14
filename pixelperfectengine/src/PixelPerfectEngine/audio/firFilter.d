module PixelPerfectEngine.audio.firFilter;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, FIR filter module
 */

import PixelPerfectEngine.system.etc;

version(LDC){
	import inteli.emmintrin;
	import core.stdc.stdlib;
	import core.stdc.string;
}
/**
 * Defines a finite impulse response.
 */
public struct FiniteImpulseResponse(int L)
		if(isPowerOf2(L)){
	//static assert(L % 2 == 0);
	public short[L] vals;	///Holds the values.
}
/**
 * Implements a finite impulse response filter.
 */
public struct FiniteImpulseResponseFilter(int L)
		if(isPowerOf2(L)){
	FiniteImpulseResponse!L* impulseResponse;	///Pointer to the impulse response
	private short[L + 8] delayLine;				///Contains the delay line
	private uint stepping;
	private const uint truncating = L - 1;
	this(FiniteImpulseResponse!L* impulseResponse){
		this.impulseResponse = impulseResponse;

	}
	version(LDC){
		public @nogc int calculate(short input){
			int4 result;
			memcpy(delayLine.ptr + L, delayLine.ptr, 16);
			delayLine[L - stepping] = input;

			for(int i ; i < L ; i+=8){
				short8* src = cast(short8*)cast(void*)impulseResponse.vals.ptr;
				short8* dlPtr = cast(short8*)cast(void*)(delayLine.ptr + (stepping + i & truncating));
				result += _mm_madd_epi16(*src, *dlPtr);
			}
			stepping++;
			stepping &= truncating;
			return result[0] + result[1] + result[2] + result[3];
		}
	}else{
		/+int result;
		for (int i ; i < L ; i++) {
			result += delayLine[(i + stepping) & truncating] * impulseResponse.vals[i];
		}
		stepping++;
		stepping &= truncating;
		return result;+/
	}
}
