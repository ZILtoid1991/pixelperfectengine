module pixelperfectengine.system.math;

int padToNext(int pad, int val) @nogc @safe pure nothrow {
	int modulo = val%pad;
	if (modulo) return val + (pad - modulo);
	return val;
}

T max(T)(T[] vals ...) @nogc @safe pure nothrow {
	T result = vals[0];
	for (sizediff_t i = 1 ; i < vals.length ; i++) {
		if (vals[i] > result) result = vals[i];
	}
	return result;
}

T min(T)(T[] vals ...) @nogc @safe pure nothrow {
	T result = vals[0];
	for (sizediff_t i = 1 ; i < vals.length ; i++) {
		if (vals[i] < result) result = vals[i];
	}
	return result;
}
