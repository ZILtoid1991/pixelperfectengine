module pixelperfectengine.system.rng;

/** 
 * Implements a pseudo-random number generator using a 64 bit Fibonacci LFSR.
 *
 * Example uses:
 * * `rng.seed() % maxAmount`
 * * `(rng.seed() % 100) < probabilityOfEvent`
 */
public struct RandomNumberGenerator {
	protected ulong     reg;
	/** 
	 * Creates the LFSR, and initializes it by calling its seed function 64 times.
	 */
	public this (ulong reg) @nogc @safe pure nothrow {
		this.reg = reg;
		for (int i ; i < 64 ; i++) seed();
	}
	public static RandomNumberGenerator defaultSeed() @nogc @safe nothrow {
		import core.time;
		RandomNumberGenerator result;
		result.reg = MonoTime.currTime.ticks;
		result.reg *= 0xDE4DB3A7;
		for (int i ; i < 64 ; i++) result.seed();
		return result;
	}
	/** 
	 * Shuffles the register's content, then returns it.
	 */
	public ulong seed() @nogc @safe pure nothrow {
		const ulong bit = 
				~(reg ^ (reg >> 51) ^ (reg >> 53) ^ (reg >> 54) ^ (reg >> 55) ^ (reg >> 59) ^ (reg >> 62) ^ (reg >> 63));
		reg = (reg>>1) | (bit<<63);
		return reg;
	}
	/** 
	 * Calls seed, then returns the remainder of the seed divided by s.
	 * Intended to simplify the use of `rng.seed() % s` style of use of this 
	 */
	public ulong dice(const uint s) @nogc @safe pure nothrow {
		return seed % s;
	}
	public ulong opCall() @nogc @safe pure nothrow {
		return seed();
	}
}
