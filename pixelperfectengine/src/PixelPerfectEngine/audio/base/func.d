module PixelPerfectEngine.audio.base.func;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.func module.
 *
 * Contains common audio functions for mixing, codecs, etc.
 */

import inteli.emmintrin;

@nogc nothrow pure:
	///Constant for fast integer to floating point conversion
	package immutable __m128 CONV_RATIO_RECIPROCAL = __m128(-1.0 / ushort.min);
	/**
	 * Mixes an audio stream to the destination.
	 */
	public void mixIntoStream(size_t length, float* src, float* dest, float amount = 1.0, float corr = 0.5) {
		const __m128 amountV = __m128([amount, amount, amount, amount]);
		const __m128 corrV = __m128([corr, corr, corr, corr]);
		while (length) {
			const __m128 srcV = _mm_load_ps(src);
			__m128 destV = _mm_load_ps(dest);
			destV += srcV * amountV;
			destV *= corrV;
			_mm_store_ps(dest, destV);
			length -= 4;
			src += 4;
			dest += 4;
		}
	}
	/**
	 * Interleaves two channels.
	 * `dest` must be as big as the length of `srcL` and `srcR`.
	 */
	public void interleave(size_t length, float* srcL, float* srcR, float* dest) {
		while (length) {
			dest[0] = *srcL;
			dest[1] = *srcR;
			dest += 2;
			srcL++;
			srcR++;
			length--;
		}
	}
	/**
	 * Converts a 32 bit extended integer stream to 32 bit floating point.
	 */
	public void convExIntToFlt(size_t length, int* src, float* dest) {
		while (length) {
			_mm_store_ps(dest, _mm_cvtepi32_ps(_mm_load_si128(cast(__m128i*)src)) * CONV_RATIO_RECIPROCAL);
			length -= 4;
			src += 4;
			dest += 4;
		}
	}