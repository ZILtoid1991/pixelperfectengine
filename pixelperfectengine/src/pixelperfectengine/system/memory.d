/*
 * PixelPerfectEngine - Memory management module
 *
 * Copyright 2015 - 2025
 * Licensed under the Boost Software License
 * Authors:
 *   László Szerémi
 *   Luna Nielsen (code borrowed from numem)
 */

module pixelperfectengine.system.memory;

import std.functional : binaryFun;
import numem.core.memory;
import numem.core.hooks;
import numem.core.traits;
import numem.core.atomic;
public import numem : nogc_new, nogc_delete;
/**
 * Inserts a new value in an ordered array. If two values equal, it'll be overwritten by the new one.
 * Params:
 *   arr = The array on which the operation is executed on.
 *   val = The value to be inserted.
 * Returns:
 */
T[] orderedInsert(T, alias less = "a > b", alias equal = "a == b")(ref T[] arr, T val) @nogc @safe {
	for (sizediff_t i = arr.length - 1 ; i >= 0 ; i--) {
		if (binaryFun!equal(arr[i], val)) {
			arr[i] = val;
			return arr;
		} else if (binaryFun!less(arr[i], val)) {
			arr.nogc_insertAt(val, i);
			return arr;
		}
	}
	arr.nogc_insertAt(val, 0);
	return arr;
}
/**
 * Does a binary searcn on an ordered array. Behavior and/or used functions can be adjusted with `less` and `equal`.
 * Params:
 *   haysack = The array on which the search is done. Must be sorted before the search.
 *   needle = The value to be found, can be the exact same as the array's type, or a type that is compatible with the
 *  specified functions
 * Returns: The value, or T.init if not found.
 */
T searchBy(T, Q, alias less = "a > b", alias equal = "a == b")(T[] haysack, Q needle) @nogc @safe {
	size_t l, r = haysack.length, m;
	while (l < r) {
		m = (l+r)>>>1;
		if (binaryFun!equal(haysack[m], needle)) return haysack[m];
		else if (binaryFun!less(haysack[m], needle)) r = m;
		else l = m;
	}
	return T.init;
}
/**
 * Does a binary searcn on an ordered array. Behavior and/or used functions can be adjusted with `less` and `equal`.
 * Params:
 *   haysack = The array on which the search is done. Must be sorted before the search.
 *   needle = The value to be found, can be the exact same as the array's type, or a type that is compatible with the
 *  specified functions
 * Returns: The position of the value, or -1 if not found.
 */
sizediff_t searchByI(T, Q, alias less = "a > b", alias equal = "a == b")(T[] haysack, Q needle) @nogc @safe {
	size_t l, r = haysack.length, m;
	while (l < r) {
		m = (l+r)>>>1;
		if (binaryFun!equal(haysack[m], needle)) return m;
		else if (binaryFun!less(haysack[m], needle)) r = m;
		else l = m;
	}
	return -1;
}
T[] nogc_append(T)(ref T[] arr, T val) @nogc @trusted {
	return nogc_insertAt(arr, val, arr.length);
}
/**
 * Inserts an element at the given index.
 * Params:
 *   arr = The array on which the operation is to be done.
 *   val = The value to be inserted.
 *   pos = The position were to the value to be inserted.
 * Returns: The modified array.
 */
T[] nogc_insertAt(T)(ref T[] arr, T val, size_t pos) @nogc @trusted {
	assert(pos <= arr.length, "Out of index operation");
	arr.nogc_resize(arr.length + 1);
	if(pos + 1 != arr.length) arr[pos+1..$] = arr[pos..$-1];
	arr[pos] = val;
	return arr;
}
/**
 * Removes an element at the given position while preserving the rest of the array's order.
 * Params:
 *   arr = The array on which the operation is to be done.
 *   pos = The index of the element to be removed.
 * Returns: The modified array.
 */
T[] nogc_remove(T)(ref T[] arr, size_t pos) @nogc @trusted {
	assert(pos < arr.length, "Out of index operation");
	if (pos + 1 != arr.length) {
		arr[pos..$-1] = arr[pos+1..$];
	}
	arr.nogc_resize(arr.length-1);
	return arr;
}

T[] nogc_resize(T)(ref T[] arr, size_t length) @nogc @trusted {
	//Code copied from numem with modifications to use alignment data from types
	static if (!isObjectiveC!T && hasElaborateDestructor!T && !isHeapAllocated!T) {
		import numem.lifetime : nogc_delete;
		if (length < arr.length) {
			// Handle destructor invocation.
			nogc_delete!(T, false)(buffer[length..arr.length]);
			// Handle buffer deletion.
			if (length == 0) {
				if (arr.length > 0) nu_aligned_free(cast(void*)arr.ptr, T.alignof);
				arr = null;
				return arr;
			}
		}
	} else {
		if (length == 0) {
			if (arr.length > 0) nu_aligned_free(arr.ptr, T.alignof);
			arr = null;
			return arr;
		}
	}
	return arr = (cast(T*)nu_aligned_realloc(arr.ptr, T.sizeof * length, T.alignof))[0..length];
}
/// Creates a new array with the given length
T[] nogc_newArray(T)(size_t length) @nogc @trusted {
	return (cast(T*)nu_aligned_alloc(T.sizeof * length, T.alignof))[0..length];
}
T[] nogc_initNewArray(T)(size_t length, T initData = T.init) @nogc @trusted {
	T[] result = nogc_newArray!T(length);
	for (size_t i ; i < length ; i++) {
		result[i] = initData;
	}
	return result;
}
/// Frees the array then sets it to null
T[] nogc_free(T)(ref T[] arr) @nogc @trusted {
	if (arr.length) {
		static if (!isObjectiveC!T && hasElaborateDestructor!T && !isHeapAllocated!T) {
			import numem.lifetime : nogc_delete;
			nogc_delete!(T, false)(buffer[length..arr.length]);
		}
		nu_aligned_free(arr.ptr, T.alignof);
	}
	arr = null;
	return arr;
}

