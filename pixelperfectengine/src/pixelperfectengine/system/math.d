module pixelperfectengine.system.math;

int padToNext(int pad, int val) @nogc @safe pure nothrow {
	int modulo = val%pad;
	if (modulo) return val + (pad - modulo);
	return val;
}
