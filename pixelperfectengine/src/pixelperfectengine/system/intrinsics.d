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

///Stores 2 of the lower single precision floats in the specified memory location.
pragma(inline, true)
void _store2s (float* memAddr, __m128 a) @nogc @system pure nothrow {
	memAddr[0] = a[0];
	memAddr[1] = a[1];
}
///Used as a way to get around the issue of vector ctors requiring values known at compile time.
pragma(inline, true)
__m128d _vect(double[2] arg) @nogc @trusted pure nothrow {
	return _mm_load_pd(arg.ptr);
}
