module pixelperfectengine.concrete.types.inputfilter;

import pixelperfectengine.graphics.text : Text;
import pixelperfectengine.system.etc : removeUnallowedSymbols;

import std.algorithm.searching : count;

/**
 * Defines the basic layout for an input filter.
 */
public abstract class InputFilter {
	///The targeted text.
	Text	target;
	/**
	 * Uses this input filter on the provided text.
	 */
	public abstract void use(ref dstring input) @safe;
}
/**
 * Implements an integer input filter.
 */
public class IntegerFilter(bool AllowNegative = true) : InputFilter {
	///Creates an instance of this kind of filter
	public this (Text target) @safe {
		this.target = target;
	}
	public override void use(ref dstring input) @safe {
		dstring symbolList = "0123456789", curr = target.text;
		static if (AllowNegative) {
			symbolList ~= "-";
		}
		input = removeUnallowedSymbols(input, symbolList);
	}
}
/**
 * Implements an decimal input filter.
 */
public class DecimalFilter(bool AllowNegative = true) : InputFilter {
	///Creates an instance of this kind of filter
	public this (Text target) @safe {
		this.target = target;
	}
	public override void use(ref dstring input) @safe {
		dstring symbolList = "0123456789.,", curr = target.text;
		static if (AllowNegative) {
			symbolList ~= "-";
		}
		input = removeUnallowedSymbols(input, symbolList);
	}
}
public class HexadecimalFilter : InputFilter {
	///Creates an instance of this kind of filter
	public this (Text target) @safe {
		this.target = target;
	}
	public override void use(ref dstring input) @safe {
		dstring symbolList = "0123456789ABCDEFabcdef";
		input = removeUnallowedSymbols(input, symbolList);
	}
}
public class ASCIITextFilter : InputFilter {
	static immutable dstring SYMBOL_LIST;
	shared static this() {
		for (dchar c = 0x20 ; c <= 0x7F ; c++) {
			SYMBOL_LIST ~= c;
		}
	}
	public this (Text target) @safe {
		this.target = target;
	}
	public override void use(ref dstring input) @safe {
		input = removeUnallowedSymbols(input, SYMBOL_LIST);
	}
}