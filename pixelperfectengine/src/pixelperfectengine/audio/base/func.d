module pixelperfectengine.audio.base.func;

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

import std.math;


public import pixelperfectengine.audio.base.types;
import pixelperfectengine.system.etc;

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
			[-32_124,-31_100,-30_076,-29_052,-28_028,-27_004,-25_980,-24_956,
			-23_932,-22_908,-21_884,-20_860,-19_836,-18_812,-17_788,-16_764,
			-15_996,-15_484,-14_972,-14_460,-13_948,-13_436,-12_924,-12_412,
			-11_900,-11_388,-10_876,-10_364, -9852, -9340, -8828, -8316,
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
			32_124, 31_100, 30_076, 29_052, 28_028, 27_004, 25_980, 24_956,
			23_932, 22_908, 21_884, 20_860, 19_836, 18_812, 17_788, 16_764,
			15_996, 15_484, 14_972, 14_460, 13_948, 13_436, 12_924, 12_412,
			11_900, 11_388, 10_876, 10_364,  9852,  9340,  8828,  8316,
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
			-22_016,-20_992,-24_064,-23_040,-17_920,-16_896,-19_968,-18_944,
			-30_208,-29_184,-32_256,-31_232,-26_112,-25_088,-28_160,-27_136,
			-11_008,-10_496,-12_032,-11_520,-8960, -8448, -9984, -9472,
			-15_104,-14_592,-16_128,-15_616,-13_056,-12_544,-14_080,-13_568,
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
			22_016, 20_992, 24_064, 23_040, 17_920, 16_896, 19_968, 18_944,
			30_208, 29_184, 32_256, 31_232, 26_112, 25_088, 28_160, 27_136,
			11_008, 10_496, 12_032, 11_520, 8960,  8448,  9984,  9472,
			15_104, 14_592, 16_128, 15_616, 13_056, 12_544, 14_080, 13_568,
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
		const __m128 amountV = __m128(amount);
		const __m128 corrV = __m128(corr);
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
	public void decode8bitPCM(const(ubyte)[] src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			const ubyte val = src[wp.pos + i];
			dest[i] = (val + val<<8) + short.min;
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an amount of 16 bit signed PCM to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode16bitPCM(const(short)[] src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = src[wp.pos + i];
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an amount of 4 bit IMA ADPCM stream to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode4bitIMAADPCM(ADPCMStream src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			const ubyte index = src[i];
			uint stepSize;
			int d_n;
			wp.pred += ADPCM_INDEX_TABLE_4BIT[index];
			clamp(wp.pred, 0, 88);
			stepSize = IMA_ADPCM_STEP_TABLE[wp.pred];
			d_n = ((stepSize) * (index & 0b0100)>>2) + ((stepSize>>1) * (index & 0b0010)>>1) + ((stepSize>>2) * index & 0b0001) 
					+ (stepSize>>3);
			if(index & 0b1000)
				d_n *= -1;
			d_n += wp.outn1;
			dest[i] = d_n;
			wp.outn1 = d_n;
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an amount of 4 bit Oki/Dialogic ADPCM stream to extended 32 bit.
	 * Amount is decided by dest.length. `src` is a full waveform. Position is stored in wp.pos.
	 */
	public void decode4bitDialogicADPCM(ADPCMStream src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			const ubyte index = src[i];
			uint stepSize;
			int d_n;
			wp.pred += ADPCM_INDEX_TABLE_4BIT[index];
			clamp(wp.pred, 0, 48);
			stepSize = DIALOGIC_ADPCM_STEP_TABLE[wp.pred];
			d_n = ((stepSize) * (index & 0b0100)>>2) + ((stepSize>>1) * (index & 0b0010)>>1) + ((stepSize>>2) * index & 0b0001) 
					+ (stepSize>>3);
			if(index & 0b1000)
				d_n *= -1;
			d_n += wp.outn1;
			dest[i] = (d_n<<4) + (d_n>>8) + short.min;
			wp.outn1 = d_n;
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes a Mu-Law encoded stream.
	 */
	public void decodeMuLawStream(const(ubyte)[]src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = MU_LAW_DECODER_TABLE[src[wp.pos + i]];
		}
		wp.pos += dest.length;
	}
	/**
	 * Decodes an A-Law encoded stream.
	 */
	public void decodeALawStream(const(ubyte)[]src, int[] dest, ref DecoderWorkpad wp) @safe {
		for (size_t i ; i < dest.length ; i++) {
			dest[i] = A_LAW_DECODER_TABLE[src[wp.pos + i]];
		}
		wp.pos += dest.length;
	}
	/**
	 * Streches a buffer to the given amount using no interpolation.
	 * Amount decided by `dest.length`.
	 * Can be used to pitch the sample.
	 */
	public void stretchAudioNoIterpol(const(int)[] src, int[] dest, ref WavemodWorkpad wp, uint modifier = 0x1_00_00_00, 
			uint clamping = 0xFF) @safe {
		//wp.lookupVal &= 0x_FF_FF_FF;
		for (size_t i ; i < dest.length /* && wp.lookupVal>>24 < src.length */ ; i++) {
			dest[i] = src[cast(size_t)(wp.lookupVal>>24) & clamping];
			wp.lookupVal += modifier;
		}
	}
	/**
	 * Converts MIDI note to frequency.
	 */
	public double midiToFreq(int note, const double baseFreq = 440.0) @safe {
		double r = note - 69;
		r /= 12;
		r = pow(2, r);
		return r * baseFreq;
	}
	/**
	 * Converts note number to frequency.
	 */
	public double noteToFreq(double note, const double baseFreq = 440.0) @safe {
		double r = note - 69;
		r /= 12;
		r = pow(2, r);
		return r * baseFreq;
	}
	/** 
	 * Bends the frequency by the given amount of seminotes.
	 * Params:
	 *   freq = The frequency to be modified.
	 *   am = The amount of seminotes. Positive means upwards, negative means downwards.
	 * Returns: The modified frequency.
	 */
	public double bendFreq(double freq, double am) @safe {
		return freq * pow(2, am / 12);
	}
	/**
	 * Calculates biquad low-pass filter coefficients from the supplied values.
	 *
	 * fs: Sampling frequency.
	 * f0: Corner frequency.
	 * q: The Q factor of the filter.
	 */
	public BiquadFilterValues createLPF(float fs, float f0, float q) @safe {
		BiquadFilterValues result;
		const float w0 = 2 * PI * f0 / fs;
		const float alpha = sin(w0) / (2 * q);
		result.b1 = 1 - cos(w0);
		result.b0 = result.b1 / 2;
		result.b2 = result.b0;
		result.a0 = 1 + alpha;
		result.a1 = -2 * cos(w0);
		result.a2 = 1 - alpha;
		return result;
	}
	/** 
	 * Calculates biquad high-pass filter coefficients from the supplied values.
	 * Params:
	 *   fs = Sampling frequency.
	 *   f0 = Corner frequency.
	 *   q = The Q factor of the filter.
	 * Returns: A struct with the coefficient values for the filter.
	 */
	public BiquadFilterValues createHPF(float fs, float f0, float q) @safe {
		BiquadFilterValues result;
		const float w0 = 2 * PI * f0 / fs;
		const float alpha = sin(w0) / (2 * q);
		result.b1 = (1 + cos(w0)) * -1;
		result.b0 = (1 + cos(w0)) / 2;
		result.b2 = result.b0;
		result.a0 = 1 + alpha;
		result.a1 = -2 * cos(w0);
		result.a2 = 1 - alpha;
		return result;
	}
	/** 
	 * Calculates biquad band pass filter (constant skirt gain, peak gain = Q) filter coefficients from the supplied values.
	 * Params:
	 *   fs = Sampling frequency.
	 *   f0 = Corner frequency.
	 *   q = Peak gain.
	 * Returns: A struct with the coefficient values for the filter.
	 */
	public BiquadFilterValues createBPF0(float fs, float f0, float q) @safe {
		BiquadFilterValues result;
		const float w0 = 2 * PI * f0 / fs;
		const float alpha = sin(w0) / (2 * q);
		result.b1 = 0;
		result.b0 = q * alpha;
		result.b2 = result.b0 * -1;
		result.a0 = 1 + alpha;
		result.a1 = -2 * cos(w0);
		result.a2 = 1 - alpha;
		return result;
	}
	/** 
	 * Calculates biquad band pass filter (constant 0 db peak gain) filter coefficients from the supplied values.
	 * Params:
	 *   fs = Sampling frequency.
	 *   f0 = Corner frequency.
	 *   q = Peak gain.
	 * Returns: A struct with the coefficient values for the filter.
	 */
	public BiquadFilterValues createBPF1(float fs, float f0, float q) @safe {
		BiquadFilterValues result;
		const float w0 = 2 * PI * f0 / fs;
		const float alpha = sin(w0) / (2 * q);
		result.b1 = 0;
		result.b0 = alpha;
		result.b2 = alpha * -1;
		result.a0 = 1 + alpha;
		result.a1 = -2 * cos(w0);
		result.a2 = 1 - alpha;
		return result;
	}
	public BiquadFilterValues createNotchFilt(float fs, float f0, float q) @safe {
		BiquadFilterValues result;
		const float w0 = 2 * PI * f0 / fs;
		const float alpha = sin(w0) / (2 * q);
		result.b1 = 0;
		result.b0 = alpha;
		result.b2 = alpha * -1;
		result.a0 = 1 + alpha;
		result.a1 = -2 * cos(w0);
		result.a2 = 1 - alpha;
		return result;
	}
	/** 
	 * Calculates the time factor for an LP6 filter.
	 * Filter formula:
	 * `y[n] = y[n-1] + (x[n] - y[n-1]) * factor`
	 * Where factor is:
	 * `1.0 - exp(-1.0 / (timeConstantInSeconds * samplerate))`
	 * Params:
	 *   fs = Sampling frequency.
	 *   f0 = Cutoff frequency.
	 * Returns: The `factor` value.
	 */
	public double calculateLP6factor(float fs, float f0) @safe {
		return 1.0 - exp(-1.0 / ((1 / f0) * fs));
	}
	/** 
	 * Creates the alpha value for a HP20 filter.
	 * Filter formula:
	 * `y[n] = (y[n-1] + x[n] - x[n-1]) * alpha`
	 * Where alpha is:
	 * `1 / (1 + 2 * pi * timeConstantInSeconds * samplerate)`
	 * Params:
	 *   fs = Sampling frequency.
	 *   f0 = Cutoff frequency.
	 * Returns: The `alpha` value.
	 */
	public double calculateHP20alpha(float fs, float f0) @safe {
		return 1 / (1 + 2 * PI * (1 / f0) * fs);
	}
	/** 
	 * Converts MIDI 1.0 14 bit control values to MIDI 2.0 32 bit. Might not work the best with certain values.
	 * Params:
	 *   msb = most significant 7 bits
	 *   lsb = least significant 7 bits
	 * Returns: The 32 bit control value.
	 */
	public uint convertM1CtrlValToM2(ubyte msb, ubyte lsb) @safe {
		const uint addedTotal = msb<<7 | lsb;
		return cast(uint)(uint.max * (cast(real)(addedTotal) / (ushort.max>>2)));
	}
	/** 
	 * Sets an array (buffer) to all zeros.
	 * Params:
	 *   targetBuffer = The buffer to be reset.
	 */
	public void resetBuffer(T)(ref T[] targetBuffer) @safe {
		static if (is(T == __m128)) {
			for (size_t i ; i < targetBuffer.length ; i++) {
				targetBuffer[i] = __m128(0);
			}
		} else {
			for (size_t i ; i < targetBuffer.length ; i++) {
				targetBuffer[i] = 0;
			}
		}
	}
	/** 
	 * Original algorithm for C++ by Martin Leitner-Ankerl (https://martin.ankerl.com/2007/10/04/optimized-pow-approximation-for-java-and-c-c/).
	 * Computes the power of `a` on the `b`th much faster than std.math.pow, at the cost of some accuracy.
	 * Good enough for envelop curve shaping.
	 */
	double fastPow(double a, double b) @safe {
	    union U {
	        double d;
	        int[2] x;
	    }
		U u;
		u.d = a;
	    u.x[1] = cast(int)(b * (u.x[1] - 1_072_632_447) + 1_072_632_447);
	    u.x[0] = 0;
	    return u.d;
	}
