module PixelPerfectEngine.audio.base.func;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.func module.
 *
 * Contains common audio functions for mixing, codecs, etc.
 */

import inteli.emmintrin;
import bitleveld.reinterpret;
import bitleveld.datatypes;

import PixelPerfectEngine.audio.base.types;
import PixelPerfectEngine.system.etc;

///Constant for fast integer to floating point conversion
package immutable __m128 CONV_RATIO_RECIPROCAL = __m128(-1.0 / ushort.min);
///For IMA ADPCM
///Needs less storage at the cost of worse quality
package static immutable byte[4] ADPCM_INDEX_TABLE_2BIT = 
			[-1, 2,
			 -1, 2];
///For IMA ADPCM
///Needs less storage at the cost of worse quality
package static immutable byte[8] ADPCM_INDEX_TABLE_3BIT = 
			[-1, -1, 2, 4,
			 -1, -1, 2, 4,];
///For IMA and Dialogic ADPCM
///Standard quality and size
package static immutable byte[16] ADPCM_INDEX_TABLE_4BIT = 
			[-1, -1, -1, -1, 2, 4, 6, 8, 
			 -1, -1, -1, -1, 2, 4, 6, 8];	
///For IMA ADPCM
///Better quality, but needs more storage
package static immutable byte[32] ADPCM_INDEX_TABLE_5BIT = 
			[-1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 4, 6, 8, 10, 13, 16
			 -1, -1, -1, -1, -1, -1, -1, -1, 1, 2, 4, 6, 8, 10, 13, 16];
///For the Yamaha ADPCM A found in YM2610 and probably other chips
package static immutable byte[16] Y_ADPCM_INDEX_TABLE =
			[-1, -1, -1, -1, 2, 5, 7, 9, 
			 -1, -1, -1, -1, 2, 5, 7, 9];
///Most OKI and Yamaha chips seems to use this step-table
package static immutable ushort[49] DIALOGIC_ADPCM_STEP_TABLE = 
			[16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55,
			60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190,	
			209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598,
			658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552];		
/** 
 * Used by IMA ADPCM and its derivatives.
 */
package static immutable ushort[89] IMA_ADPCM_STEP_TABLE = 
			[7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 
			19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 
			50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 
			130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
			337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
			876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 
			2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
			5894, 6484, 7132, 7845, 8630, 9493, 10_442, 11_487, 12_635, 13_899, 
			15_289, 16_818, 18_500, 20_350, 22_385, 24_623, 27_086, 29_794, 32_767];
alias ADPCMStream = NibbleArray;


@nogc nothrow pure:
	
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
	/**
	 * Decodes an amount of 8 bit unsigned PCM to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode8bitPCM(const(ubyte)[] src, int[] dest, ref Workpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			const ubyte val = src[wp.pos + i];
			dest[i] = (val + val<<8) + ushort.min;
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an amount of 16 bit signed PCM to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode16bitPCM(const(short)[] src, int[] dest, ref Workpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = src[wp.pos + i];
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an amount of 4 bit IMA ADPCM stream to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode4bitIMAADPCM(ADPCMStream src, int[] dest, ref Workpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			ubyte index = src[i];
			uint stepSize;
			int d_n;
			wp.pred += ADPCM_INDEX_TABLE_4BIT[index];
			clamp(wp.pred, 0, 88);
			stepSize = IMA_ADPCM_STEP_TABLE[wp.pred];
			d_n = ((stepSize) * (index & 0b0100)>>2) + ((stepSize>>1) * (index & 0b0010)>>1) + ((stepSize>>2) * index & 0b0001) + (stepSize>>3);
			if(index & 0b1000)
				d_n *= -1;
			d_n += wp.outn1;
			dest = d_n;
			wp.outn1 = d_n;
		}
		wp.pos += dest.length;
	}
	/**
	 * Streches a buffer to the given amount using no interpolation.
	 * Can be used to pitch the sample.
	 */
	public void stretchAudioNoIterpol(const(int)[] src, int[] dest, ref WavemodWorkpad wp, uint modifier = 0x10_00_00) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = src[cast(size_t)(wp.lookupVal>>20)];
			wp.lookupVal += modifier;
		}
	}