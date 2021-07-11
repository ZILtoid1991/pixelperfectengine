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
	/**
	 * Mixes an audio stream to the destination.
	 */
	public void mixIntoStream(size_t length, float* src, float* dest, float amount = 1.0) {
		const __m128 amountV = __m128([amount, amount, amount, amount]);
		while (length) {
			const __m128 srcV = _mm_load_ps(src);
			__m128 destV = _mm_load_ps(dest);
			destV += srcV;
			destV *= amountV;
			_mm_store_ps(dest, destV);
			length -= 4;
			src += 4;
			dest += 4;
		}
	}