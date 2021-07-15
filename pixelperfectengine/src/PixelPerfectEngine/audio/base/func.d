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
/**
 * Used for decoding Mu-Law encoded PCM samples
 */
package static immutable short[256] MU_LAW_DECODER_TABLE =
			[-32124,-31100,-30076,-29052,-28028,-27004,-25980,-24956,
			-23932,-22908,-21884,-20860,-19836,-18812,-17788,-16764,
			-15996,-15484,-14972,-14460,-13948,-13436,-12924,-12412,
			-11900,-11388,-10876,-10364, -9852, -9340, -8828, -8316,
			-7932, -7676, -7420, -7164, -6908, -6652, -6396, -6140,
			-5884, -5628, -5372, -5116, -4860, -4604, -4348, -4092,
			-3900, -3772, -3644, -3516, -3388, -3260, -3132, -3004,
			-2876, -2748, -2620, -2492, -2364, -2236, -2108, -1980,
			-1884, -1820, -1756, -1692, -1628, -1564, -1500, -1436,
			-1372, -1308, -1244, -1180, -1116, -1052,  -988,  -924,
			-876,  -844,  -812,  -780,  -748,  -716,  -684,  -652,
			-620,  -588,  -556,  -524,  -492,  -460,  -428,  -396,
			-372,  -356,  -340,  -324,  -308,  -292,  -276,  -260,
			-244,  -228,  -212,  -196,  -180,  -164,  -148,  -132,
			-120,  -112,  -104,   -96,   -88,   -80,   -72,   -64,
			-56,   -48,   -40,   -32,   -24,   -16,    -8,     -1,
			32124, 31100, 30076, 29052, 28028, 27004, 25980, 24956,
			23932, 22908, 21884, 20860, 19836, 18812, 17788, 16764,
			15996, 15484, 14972, 14460, 13948, 13436, 12924, 12412,
			11900, 11388, 10876, 10364,  9852,  9340,  8828,  8316,
			7932,  7676,  7420,  7164,  6908,  6652,  6396,  6140,
			5884,  5628,  5372,  5116,  4860,  4604,  4348,  4092,
			3900,  3772,  3644,  3516,  3388,  3260,  3132,  3004,
			2876,  2748,  2620,  2492,  2364,  2236,  2108,  1980,
			1884,  1820,  1756,  1692,  1628,  1564,  1500,  1436,
			1372,  1308,  1244,  1180,  1116,  1052,   988,   924,
			876,   844,   812,   780,   748,   716,   684,   652,
			620,   588,   556,   524,   492,   460,   428,   396,
			372,   356,   340,   324,   308,   292,   276,   260,
			244,   228,   212,   196,   180,   164,   148,   132,
			120,   112,   104,    96,    88,    80,    72,    64,
			56,    48,    40,    32,    24,    16,     8,     0];
/**
 * Used for decoding A-Law encoded PCM streams.
 */
package static immutable short[256] A_LAW_DECODER_TABLE = 
			[-5504, -5248, -6016, -5760, -4480, -4224, -4992, -4736,
			-7552, -7296, -8064, -7808, -6528, -6272, -7040, -6784,
			-2752, -2624, -3008, -2880, -2240, -2112, -2496, -2368,
			-3776, -3648, -4032, -3904, -3264, -3136, -3520, -3392,
			-22016,-20992,-24064,-23040,-17920,-16896,-19968,-18944,
			-30208,-29184,-32256,-31232,-26112,-25088,-28160,-27136,
			-11008,-10496,-12032,-11520,-8960, -8448, -9984, -9472,
			-15104,-14592,-16128,-15616,-13056,-12544,-14080,-13568,
			-344,  -328,  -376,  -360,  -280,  -264,  -312,  -296,
			-472,  -456,  -504,  -488,  -408,  -392,  -440,  -424,
			-88,   -72,   -120,  -104,  -24,   -8,    -56,   -40,
			-216,  -200,  -248,  -232,  -152,  -136,  -184,  -168,
			-1376, -1312, -1504, -1440, -1120, -1056, -1248, -1184,
			-1888, -1824, -2016, -1952, -1632, -1568, -1760, -1696,
			-688,  -656,  -752,  -720,  -560,  -528,  -624,  -592,
			-944,  -912,  -1008, -976,  -816,  -784,  -880,  -848,
			5504,  5248,  6016,  5760,  4480,  4224,  4992,  4736,
			7552,  7296,  8064,  7808,  6528,  6272,  7040,  6784,
			2752,  2624,  3008,  2880,  2240,  2112,  2496,  2368,
			3776,  3648,  4032,  3904,  3264,  3136,  3520,  3392,
			22016, 20992, 24064, 23040, 17920, 16896, 19968, 18944,
			30208, 29184, 32256, 31232, 26112, 25088, 28160, 27136,
			11008, 10496, 12032, 11520, 8960,  8448,  9984,  9472,
			15104, 14592, 16128, 15616, 13056, 12544, 14080, 13568,
			344,   328,   376,   360,   280,   264,   312,   296,
			472,   456,   504,   488,   408,   392,   440,   424,
			88,    72,   120,   104,    24,     8,    56,    40,
			216,   200,   248,   232,   152,   136,   184,   168,
			1376,  1312,  1504,  1440,  1120,  1056,  1248,  1184,
			1888,  1824,  2016,  1952,  1632,  1568,  1760,  1696,
			688,   656,   752,   720,   560,   528,   624,   592,
			944,   912,  1008,   976,   816,   784,   880,   848];

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
	 * Decodes a Mu-Law encoded stream.
	 */
	public void decodeMuLawStream(const(ubyte)[]src, int dest, ref Workpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = MU_LAW_DECODER_TABLE[src[wp.pos + i]];
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an A-Law encoded stream.
	 */
	public void decodeALawStream(const(ubyte)[]src, int dest, ref Workpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = A_LAW_DECODER_TABLE[src[wp.pos + i]];
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