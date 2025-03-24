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
public import numem : nogc_new, nogc_delete, nogc_move, nogc_copy;

/// UDA to get around certain issues regarding of structs with refcounting dtors.
struct PPECFG_Memfix {}
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
void fatal_trusted(const(char)[] errMsg) @trusted @nogc nothrow {
	nu_fatal(errMsg);
}
/**
 * Does a binary searcn on an ordered array. Behavior and/or used functions can be adjusted with `less` and `equal`.
 * Params:
 *   haysack = The array on which the search is done. Must be sorted before the search.
 *   needle = The value to be found, can be the exact same as the array's type, or a type that is compatible with the
 *  specified functions
 * Returns: The value, or T.init if not found.
 */
T searchBy(T, Q, alias less = "a > b", alias equal = "a == b")(T[] haysack, Q needle) @nogc @safe nothrow {
	if (haysack.length) {
		size_t l, r = haysack.length, m;
		while (l < r) {
			m = (l+r)>>1;
			if (binaryFun!equal(haysack[m], needle)) return haysack[m];
			else if (binaryFun!less(haysack[m], needle)) r = m - 1;
			else l = m + 1;
		}
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
sizediff_t searchByI(T, Q, alias less = "a > b", alias equal = "a == b")(T[] haysack, Q needle) @nogc @safe nothrow {
	if (haysack.length) {
		size_t l, r = haysack.length, m;
		while (l < r) {
			m = (l+r)>>1;
			if (binaryFun!equal(haysack[m], needle)) return m;
			else if (binaryFun!less(haysack[m], needle)) r = m - 1;
			else l = m + 1;
		}
	}
	return -1;
}
/**
 * Does a binary searcn on an ordered array. Behavior and/or used functions can be adjusted with `less` and `equal`.
 * Params:
 *   haysack = The array on which the search is done. Must be sorted before the search.
 *   needle = The value to be found, can be the exact same as the array's type, or a type that is compatible with the
 *  specified functions
 * Returns: The pointer to the value, or null otherwise.
 */
T* searchByRef(T, Q, alias less = "a > b", alias equal = "a == b")(T[] haysack, Q needle) @nogc @safe nothrow {
	if (haysack.length) {
		size_t l, r = haysack.length, m;
		while (l < r) {
			m = (l+r)>>1;
			if (binaryFun!equal(haysack[m], needle)) return &haysack[m];
			else if (binaryFun!less(haysack[m], needle)) r = m - 1;
			else l = m + 1;
		}
	}
	return null;
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
	// if(pos + 1 != arr.length) arr[pos+1..$] = arr[pos..$-1];
	if (pos + 1 != arr.length) shiftElements(arr, 1, pos);
	static if (hasUDA!(T, PPECFG_Memfix)) setToNull(arr[pos..pos+1]);
	arr[pos] = val;
	return arr;
}
///Sets all of `dest` to null, useful for certain refcounted types.
package void setToNull(T)(T[] dest) @nogc @system nothrow {
	nu_memset(dest.ptr, 0, dest.length * T.sizeof);
}
///Does a memory direct memory copy while also circumventing copy constructors.
package void dirtyCopy(T)(T[] src, T[] dest) @nogc @system nothrow {
	assert(src.length == dest.length);
	nu_memcpy(dest.ptr, src.ptr, src.length * T.sizeof);
}
/// Shifts elements by the given amount.
package void shiftElements(T)(ref T[] arr, sizediff_t amount, size_t position) @nogc @system nothrow {
	if (amount > 0) dirtyCopy(arr[position..$-amount], arr[position+amount..$]);
	else if (amount < 0) dirtyCopy(arr[position-amount..$], arr[position..$+amount]);
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
	// if (pos + 1 != arr.length) {
	// 	arr[pos..$-1] = arr[pos+1..$];
	// }
	if (pos + 1 != arr.length) dirtyCopy(arr[pos+1..$], arr[pos..$-1]); //arr[pos..$-1] = arr[pos+1..$];
	arr.nogc_resize(arr.length-1);
	return arr;
}

T[] nogc_resize(T)(ref T[] arr, size_t length) @nogc @trusted {
	//Code copied from numem with modifications to use alignment data from types
	static if (!isObjectiveC!T && hasElaborateDestructor!T && !isHeapAllocated!T) {
		import numem.lifetime : nogc_delete;
		if (length < arr.length) {
			// Handle destructor invocation.
			nogc_delete!(T, hasUDA!(T, PPECFG_Memfix))(arr[length..arr.length]);
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
/// Initializes a new array with the supplied data.
T[] nogc_initNewArray(T)(size_t length, T initData = T.init) @nogc @trusted {
	T[] result = nogc_newArray!T(length);
	for (size_t i ; i < length ; i++) {
		result[i] = initData;
	}
	return result;
}
/// Frees the array then sets it to null.
T[] nogc_free(T)(ref T[] arr) @nogc @trusted {
	if (arr.length) {
		static if (!isObjectiveC!T && hasElaborateDestructor!T && !isHeapAllocated!T) {
			import numem.lifetime : nogc_delete;
			nogc_delete!(T, hasUDA!(T, PPECFG_Memfix))(arr[0..arr.length]);
		}
		nu_aligned_free(arr.ptr, T.alignof);
	}
	arr = null;
	return arr;
}
/// Sets the growth strategy for the dynamic array.
enum LTrimStrategy {
	None,		/// Left hand trim is disabled, front deletion will result in copy.
	UseForAny,	/// Left hand trim can be used for any growth.
	Reserve,	/// Reserve left hand trim for the future, keep on growth.
	KeepUntilGrowth,/// Left hand trim kept until growth on right hand, then it's discarded if not used.
}
package immutable string[] attrList =
		["@system ", "@system @nogc", "@system @nogc nothrow", "@system nothrow",
		"@safe", "@safe @nogc", "@safe @nogc nothrow", "@safe nothrow"];
/**
 * Implements a non-garbage collected dynamic array with automatic growth.
 * `growthStrategy` sets the growth function of the array.
 * `lts` sets the left hand trim strategy of the array, see enumerator `LTrimStrategy` 
 * for more info
 */
public struct DynArray(T, string growthStrategy = "a += a;", LTrimStrategy lts = LTrimStrategy.None) {
	package static string opApplyGen() {
		import pixelperfectengine.system.etc : interpolateStr;
		immutable string opApplyCode = q"{
			int opApply(int delegate(T) %attr% dg) %attr% {
				for (sizediff_t i ; i < length ; i++) {
					if (dg(backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApply(int delegate(ref T) %attr% dg) %attr% {
				for (sizediff_t i ; i < length ; i++) {
					if (dg(backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApplyReverse(int delegate(T) %attr% dg) %attr% {
				for (sizediff_t i = length - 1 ; i >= 0 ; i--) {
					if (dg(backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApplyReverse(int delegate(ref T) %attr% dg) %attr% {
				for (sizediff_t i = length - 1 ; i >= 0 ; i--) {
					if (dg(backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApply(int delegate(size_t, T) %attr% dg) %attr% {
				for (sizediff_t i ; i < length ; i++) {
					if (dg(i, backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApply(int delegate(size_t, ref T) %attr% dg) %attr% {
				for (sizediff_t i ; i < length ; i++) {
					if (dg(i, backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApplyReverse(int delegate(size_t, T) %attr% dg) %attr% {
				for (sizediff_t i = length - 1 ; i >= 0 ; i--) {
					if (dg(i, backend[lTrim + i])) return 1;
				}
				return 0;
			}
			int opApplyReverse(int delegate(size_t, ref T) %attr% dg) %attr% {
				for (sizediff_t i = length - 1 ; i >= 0 ; i--) {
					if (dg(i, backend[lTrim + i])) return 1;
				}
				return 0;
			}
		}";
		string result;
		foreach (string attr ; attrList) {
			string[string] attrInterpolation = ["attr" : attr];
			result ~= interpolateStr(opApplyCode, attrInterpolation);
		}
		return result;
	}
	package T[] backend;	/// The underlying memory slice and its current capadity
	package size_t lTrim; /// Left hand trim, used when it's easier to trim the array at the left side.
	package size_t rTrim; /// Right hand trim, used when it's easier to trim the array at the right side.
	/**
	 * Creates a dynamic array from the given slice.
	 * Params:
	 *   data = the data to be used as a starting point.
	 * NOTE: the data must be managed by numem.
	 */
	this(T[] data) @nogc @safe nothrow {
		backend = data;
	}
	/**
	 * Creates an array with the given amount of reserve.
	 */
	this(size_t amount) @nogc @safe {
		backend = nogc_newArray!T(amount);
		rTrim = amount;
	}
	/// Creates an array with the given amount of initial values.
	this(size_t amount, T initVal) @nogc @safe {
		backend = nogc_initNewArray!T(amount, initVal);
	}
	/// Frees up the memory used by the array.
	void free() @nogc @safe {
		backend.nogc_free();
		lTrim = 0;
		rTrim = 0;
	}
	/// Returns the maximum elements that can be stored by this array.
	size_t capacity() @nogc @safe pure nothrow const {
		return backend.length;
	}
	/// Returns the number of the elements currently held by this array.
	size_t length() @nogc @safe pure nothrow const {
		return backend.length - lTrim - rTrim;
	}
	size_t length(size_t val) @nogc @trusted {
		if (!length) {
			lTrim = 0;
			rTrim = backend.length;
		} else if (val >= remain) {
			// reserve(val);
			grow();
		} else {
			sizediff_t newrTrim = capacity - lTrim - val;
			if (newrTrim < -1) {
				rTrim = 0;
				backend.shiftElements(newrTrim, lTrim);
				lTrim = 0;
			} else {
				rTrim = newrTrim;
			}
		}
		return val;
	}
	/// Returns the number of elements that can be stored by this array.
	/// Does not factor into left hand trim with certain strategies.
	size_t remain() @nogc @safe pure nothrow const {
		static if (lts == LTrimStrategy.KeepUntilGrowth || lts == LTrimStrategy.Reserve) return capacity - length - lTrim;
		else return capacity - length;
	}
	/// Reserves the set amount of memory, then returns the new capacity.
	size_t reserve(size_t amount) @nogc @safe {
		amount = amount > length ? amount : length;
		const oldLength = length;
		backend.nogc_resize(amount);
		rTrim = capacity - oldLength - lTrim;
		return capacity;
	}
	/// Executes the growth strategy set for the current instance (default is a *= 2).
	package void grow() @nogc @trusted {
		size_t a = backend.length;
		const b = a;
		mixin(growthStrategy);
		static if (lts == LTrimStrategy.KeepUntilGrowth) {
			T[] newbackend = nogc_newArray(a);
			dirtyCopy(backend[lTrim..$], newbackend[0..backend.length-lTrim]);
			backend.nogc_free();
			backend = newbackend;
		} else {
			backend.nogc_resize(a);
		}
		rTrim = a - b;
	}
	alias opDollar = length;
	///Returns the element held on `index`.
	ref T opIndex(size_t index) @nogc @safe pure nothrow {
		assert(index < length);
		return backend[lTrim + index];
	}
	/// Returns a slice from the array.
	T[] opSlice(size_t i, size_t j) @nogc @safe pure nothrow {
		assert(i <= j);
		assert(i < length);
		assert(j <= length);
		return backend[lTrim+i..lTrim+j];
	}
	/// Removes the element held on the index and returns the element.
	T remove(size_t index) @nogc @safe {
		assert(index < length);
		T result = backend[lTrim + index];
		static if (lts == LTrimStrategy.None) {
			rTrim++;
			static if (hasUDA!(T, PPECFG_Memfix)) {
				backend.shiftElements(-1, index);
				setToNull(backend[length - 1..length]);
			} else {
				backend[index..length - 1] = backend[index + 1..length];
			}
		} else {
			const midpoint = length>>1;
			if (index < midpoint) {
				lTrim++;
				static if (hasUDA!(T, PPECFG_Memfix)) {
					dirtyCopy(backend[lTrim - 1..lTrim + index - 1], backend[lTrim..lTrim + index]);
					setToNull(backend[lTrim - 1..lTrim]);
				} else {
					backend[lTrim..lTrim + index] = backend[lTrim - 1..lTrim + index - 1];
				}
			} else {
				rTrim++;
				static if (hasUDA!(T, PPECFG_Memfix)) {
					backend.shiftElements(-1, lTrim + index);
					setToNull(backend[lTrim + index..lTrim + index + 1]);
				} else {
					backend[lTrim + index..lTrim + length - 1] = backend[lTrim + index + 1..lTrim + length];
				}
			}
		}
		return result;
	}
	///Inserts a new element at index, then returns is.
	ref T insert(size_t index, T elem) @nogc @safe {
		assert(index <= length);
		if (!remain()) grow();
		static if (lts == LTrimStrategy.None) {
			static if (hasUDA!(T, PPECFG_Memfix)) {
				if (index != length) backend.shiftElements(1, index);
				setToNull(backend[index..index + 1]);
			} else {
				backend[index + 1..length + 1] = backend[index..length];
			}
			backend[index] = elem;
			rTrim--;
		} else {
			const midpoint = length>>1;
			if ((index < midpoint || (lts == LTrimStrategy.UseForAny && !rTrim)) && lTrim) {
				static if (hasUDA!(T, PPECFG_Memfix)) {
					dirtyCopy(backend[lTrim..lTrim + index], backend[lTrim - 1..lTrim + index - 1]);
					setToNull(backend[lTrim + index..lTrim + index + 1]);
				} else {
					backend[lTrim - 1..lTrim + index - 1] = backend[lTrim..lTrim + index];
				}
				backend[index] = elem;
				lTrim--;
				return backend[index];
			}
			static if (hasUDA!(T, PPECFG_Memfix)) {
				if (index + lTrim != length) backend.shiftElements(1, lTrim + index);
				setToNull(backend[lTrim + index..lTrim + index + 1]);
			} else {
				backend[lTrim + index + 1..lTrim + length + 1] = backend[lTrim + index..lTrim + length];
			}
			backend[index] = elem;
			rTrim--;
		}
		return backend[index];
	}
	ref T opOpAssign(string op : "~")(T elem) @nogc @safe {
		insert(length, elem);
		return opIndex(length - 1);
	}
	T[] opOpAssign(string op : "~")(T[] slice) @nogc @safe {
		if (remain < slice.length) reserve(length + slice.length);
		
		backend[lTrim + length..lTrim + length + slice.length] = slice[0..$];
		rTrim -= slice.length;
		return backend[lTrim..lTrim + length];
	}
	/// Returns the pointer to the first element.
	T* ptr() @system @nogc nothrow pure {
		return backend.ptr + lTrim;
	}
	mixin(opApplyGen());
}
public struct OrderedArraySet(T, alias less = "a > b", alias equal = "a == b", string growthStrategy = "a += a;",
		LTrimStrategy lts = LTrimStrategy.None) {
	alias BET = DynArray!(T, growthStrategy, lts);
	public BET backend;
	this(size_t amount) @nogc @safe {
		backend = BET(amount);
	}
	// alias free = backend.free;
	void free() @nogc @safe {
		backend.free;
	}
	// alias capacity = backend.capacity;
	size_t capacity() @nogc @safe pure nothrow const {
		return backend.capacity();
	}
	// alias length = backend.length;
	size_t length() @nogc @safe pure nothrow const {
		return backend.length();
	}
	size_t length(size_t val) @nogc @safe {
		return backend.length(val);
	}
	// alias remain = backend.remain;
	size_t remain() @nogc @safe pure nothrow const {
		return backend.remain;
	}
	// alias reserve = backend.reserve;
	size_t reserve(size_t amount) @nogc @safe {
		return backend.reserve(amount);
	}
	alias opDollar = length;
	alias opSlice = backend.opSlice;
	alias remove = backend.remove;
	alias ptr = backend.ptr;
	ref T insert(T elem) @nogc @safe {
		if (!remain()) backend.grow();
		for (sizediff_t i = length - 1 ; i >= 0 ; i--) {
			if (binaryFun!equal(backend[i], elem)) {
				backend[i] = elem;
				return backend[i];
			} else if (binaryFun!less(backend[i], elem)) {
				backend.insert(i, elem);
				return backend[i];
			}
		}
		backend.insert(0, elem);
		return backend[0];
	}
	T searchBy(Q)(Q needle) @nogc @safe nothrow {
		if (length) {
			size_t l, r = length, m;
			while (l < r) {
				m = (l+r)>>1;
				if (binaryFun!equal(backend[m], needle)) return backend[m];
				else if (binaryFun!less(backend[m], needle)) r = m - 1;
				else l = m + 1;
			}
		}
		return T.init;
	}
	sizediff_t searchIndexBy(Q)(Q needle) @nogc @safe nothrow {
		if (length) {
			size_t l, r = length, m;
			while (l < r) {
				m = (l+r)>>1;
				if (binaryFun!equal(backend[m], needle)) return m;
				else if (binaryFun!less(backend[m], needle)) r = m - 1;
				else l = m + 1;
			}
		}
		return -1;
	}
	alias opIndex = backend.opIndex;
	alias opApply = backend.opApply;
	alias opApplyReverse = backend.opApplyReverse;
}
