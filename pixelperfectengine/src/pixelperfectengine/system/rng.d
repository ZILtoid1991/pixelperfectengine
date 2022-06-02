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
		for (int i ; i < 64 ; i++)
			seed();
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
}