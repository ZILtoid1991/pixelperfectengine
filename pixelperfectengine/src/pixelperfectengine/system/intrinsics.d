/*
 * PixelPerfectEngine - Helper intrinsics module
 *
 * Copyright 2015 - 2025
 * Licensed under the Boost Software License
 * Authors:
 *   László Szerémi
 */

module pixelperfectengine.system.intrinsics;
import inteli;

immutable __m128i MM_NULLVEC = __m128i([0, 0, 0, 0]);
///Stores 2 of the lower single precision floats in the specified memory location.
pragma(inline, true)
void _store2s(float* memAddr, __m128 a) @nogc @system pure nothrow {
	memAddr[0] = a[0];
	memAddr[1] = a[1];
}
///Stores 2 of the higher single precision floats in the specified memory location.
pragma(inline, true)
void _store2sH(float* memAddr, __m128 a) @nogc @system pure nothrow {
	memAddr[0] = a[2];
	memAddr[1] = a[3];
}
///Used as a way to get around the issue of vector ctors requiring values known at compile time.
pragma(inline, true)
__m128d _vect(double[2] arg) @nogc @trusted pure nothrow {
	return _mm_load_pd(arg.ptr);
}
pragma(inline, true)
__m128 _vect(float[4] arg) @nogc @trusted pure nothrow {
	return _mm_load_ps(arg.ptr);
}
pragma(inline, true)
__m128i _vect(int[4] arg) @nogc @trusted pure nothrow {
	return _mm_loadu_si128(cast(const(__m128i)*)arg.ptr);
}
pragma(inline, true)
__m128d _conv2ints(int arg0, int arg1) @nogc @trusted pure nothrow {
	long val = arg0 | (cast(long)arg1<<32L);
	return _mm_cvtpi32_pd(cast(__m64)val);
}
pragma(inline, true)
__m128d _conv2shorts(short* memAddr) @nogc @trusted pure nothrow {
	__m128i workpad;
	workpad[0] = memAddr[0];
	workpad[1] = memAddr[1];
	return _mm_cvtepi32_pd(workpad);
}
pragma(inline, true)
__m128 _conv4shorts(short* memAddr) @nogc @trusted pure nothrow {
	__m128i workpad;
	workpad[0] = memAddr[0];
	workpad[1] = memAddr[1];
	workpad[2] = memAddr[2];
	workpad[3] = memAddr[3];
	return _mm_cvtepi32_ps(workpad);
}
pragma(inline, true)
__m128 _conv4ubytes(ubyte* memAddr) @nogc @trusted pure nothrow {
	__m128i b = _mm_loadu_si32(memAddr);
	// Zero extend to 32-bit
    b = _mm_unpacklo_epi8(b, MM_NULLVEC);
    b = _mm_unpacklo_epi16(b, MM_NULLVEC);

    return _mm_cvtepi32_ps(b);
}
/**
 * Custom intrinsic that implements matrix multiplication.
 * Params:
 *   a = Left hand side of the multiplication.
 *   b = Right hand side of the multiplication.
 * Returns: a float4 containing the result.
 */
pragma(inline, true)
__m128 matrix22Mult(__m128 a, __m128 b) @nogc @trusted pure nothrow {
	__m128 c;
	c[0] = a[0] * b[0] + a[1] * b[2];
	c[1] = a[0] * b[1] + a[1] * b[3];
	c[2] = a[2] * b[0] + a[3] * b[2];
	c[3] = a[2] * b[1] + a[3] * b[3];
	return c;
}
