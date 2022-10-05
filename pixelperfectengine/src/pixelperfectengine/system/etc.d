module pixelperfectengine.system.etc;

import std.conv;
import std.algorithm.mutation;
import std.algorithm.searching;

public import bitleveld.reinterpret;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, etc module
 */


///Converts string[] to dstring[]
public dstring[] stringArrayConv(string[] s) pure @safe{
	dstring[] result;
	foreach(ss; s){
		dstring ws;
		foreach(c; ss){
			ws ~= c;
		}
		result ~= ws;
	}
	return result;
}
///Returns a hexadecimal string representation of the integer.
S intToHex(S = string)(int i, int format = 0) pure @safe{
	S result;
	do{
		switch(i & 0x000F){
			case 1: result = '1' ~ result; break;
			case 2: result = '2' ~ result; break;
			case 3: result = '3' ~ result; break;
			case 4: result = '4' ~ result; break;
			case 5: result = '5' ~ result; break;
			case 6: result = '6' ~ result; break;
			case 7: result = '7' ~ result; break;
			case 8: result = '8' ~ result; break;
			case 9: result = '9' ~ result; break;
			case 10: result = 'A' ~ result; break;
			case 11: result = 'B' ~ result; break;
			case 12: result = 'C' ~ result; break;
			case 13: result = 'D' ~ result; break;
			case 14: result = 'E' ~ result; break;
			case 15: result = 'F' ~ result; break;
			default: result = '0' ~ result; break;
		}
		i = i >>> 4;
	}while(i > 0);
	if(result.length < format){
		for(size_t j = result.length ; j < format ; j++){
			result = '0' ~ result;
		}
	}
	//result = result.dup.reverse;
	return result;
}
///Returns a octal string representation of the integer.
S intToOct(S = string)(int i, int format) pure @safe{
	string result;
	do{
		switch(i & 0x0007){
			case 1: result = '1' ~ result; break;
			case 2: result = '2' ~ result; break;
			case 3: result = '3' ~ result; break;
			case 4: result = '4' ~ result; break;
			case 5: result = '5' ~ result; break;
			case 6: result = '6' ~ result; break;
			case 7: result = '7' ~ result; break;
			default: result = '0' ~ result; break;
		}
		i = i >>> 3;
	}while(i > 0);
	if(result.length < format){
		for(size_t j = result.length ; j < format ; j++){
			result ~= '0';
		}
	}
	//result = result.dup.reverse;
	return result;
}
///Parses a hexadecimal int represented as a string.
///Ignores characters that are not hexanumeric.
int parseHex(S)(S s) pure @safe{
	int result;
	for(int i ; i < s.length; i++){
		switch(s[i]){
			case '0': result *= 16; break;
			case '1': result += 1; result *= 16; break;
			case '2': result += 2; result *= 16; break;
			case '3': result += 3; result *= 16; break;
			case '4': result += 4; result *= 16; break;
			case '5': result += 5; result *= 16; break;
			case '6': result += 6; result *= 16; break;
			case '7': result += 7; result *= 16; break;
			case '8': result += 8; result *= 16; break;
			case '9': result += 9; result *= 16; break;
			case 'a','A': result += 10; result *= 16; break;
			case 'b','B': result += 11; result *= 16; break;
			case 'c','C': result += 12; result *= 16; break;
			case 'd','D': result += 13; result *= 16; break;
			case 'e','E': result += 14; result *= 16; break;
			case 'f','F': result += 15; result *= 16; break;
			default: break;
		}
	}
	return result;
}
///Parses a octal int represented as a string.
///Ignores characters that are not octal.
int parseOct(S)(S s) pure @safe{
	int result;
	for(int i ; i < s.length; i++){
		
		switch(s[i]){
			case '0': result *= 8; break;
			case '1': result += 1; result *= 8; break;
			case '2': result += 2; result *= 8; break;
			case '3': result += 3; result *= 8; break;
			case '4': result += 4; result *= 8; break;
			case '5': result += 5; result *= 8; break;
			case '6': result += 6; result *= 8; break;
			case '7': result += 7; result *= 8; break;
			/+case '8': result += 8; break;
			case '9': result += 9; break;
			case 'a','A': result += 10; break;
			case 'b','B': result += 11; break;
			case 'c','C': result += 12; break;
			case 'd','D': result += 13; break;
			case 'e','E': result += 14; break;
			case 'f','F': result += 15; break;+/
			default: break;
		}
	}
	return result;
}
///Parses a decimal int represented as a string.
///Ignores characters that are not decimal.
int parseDec(S)(S s) pure @safe{
	int result;
	for(int i ; i < s.length; i++){
		
		switch(s[i]){
			case '0': result *= 10; break;
			case '1': result += 1; result *= 10; break;
			case '2': result += 2; result *= 10; break;
			case '3': result += 3; result *= 10; break;
			case '4': result += 4; result *= 10; break;
			case '5': result += 5; result *= 10; break;
			case '6': result += 6; result *= 10; break;
			case '7': result += 7; result *= 10; break;
			case '8': result += 8; result *= 10; break;
			case '9': result += 9; result *= 10; break;
			/+case 'a','A': result += 10; break;
			case 'b','B': result += 11; break;
			case 'c','C': result += 12; break;
			case 'd','D': result += 13; break;
			case 'e','E': result += 14; break;
			case 'f','F': result += 15; break;+/
			default: break;
		}
	}
	return result;
}
///Parses a comma separated string into a single array.
S[] csvParser(S)(S input, char separator = ',') pure @safe {
	S[] result;
	for (int i, j ; i < input.length ; i++) {
		if (input[i] == separator || i + 1 == input.length) {
			result ~= input[j..i];
			j = i + 1;
		}
	}

	return result;
}
///Parses an array of string to an array of another value.
T[] stringArrayParser(T, S)(S[] input) pure @safe {
	T[] result;
	result.length = input.length;
	foreach (S key ; input) {
		result ~= to!T(key);
	}
	return result;
}
///Joins prettyprint strings to a single string for file storage.
S stringArrayJoin(S)(S[] input) pure @safe {
	S result;
	foreach(s ; input){
		result ~= s ~ "\n";
	}
	return result;
}
///Tests if the input string is integer and returns true if it is.
bool isInteger(S)(S s) pure @safe @nogc nothrow
	if(is(S == string) || is(S == wstring) || is(S == dstring)) {
	if (!s.length)
		return false;
	if(s[0] > '9' || s[0] < '0' || (s[0] != '-' && s.length >= 2))
		return false;
	if (s.length >= 2)
		foreach(c; s[1..$])
			if(c > '9' || c < '0')
				return false;
	
	return true;
	
}

/**
 * Returns true if x is power of two.
 */
public bool isPowerOf2(T = uint)(T x) pure @safe @nogc nothrow{
	return x && ((x & (x - 1U)) == 0U);
}

/**
 * From "Hackers Delight"
 * val remains unchanged if it is already a power of 2.
 */
public T nextPow2(T)(T val) pure @safe @nogc nothrow{
	val--;
	val |= val >> 16;
	val |= val >> 8;
	val |= val >> 4;
	val |= val >> 2;
	val |= val >> 1;
	return val + 1;
}
/+
/**
 * Safely converts an array to a type.
 * NOTE: by 0.10.0, an external library will replace this.
 */
public T reinterpretGet(T, S)(S[] source) pure @trusted {
	T _reinterpretGet() pure @system {
		return (cast(T[])(cast(void[])source))[0];
	}
	if(S.sizeof * source.length == T.sizeof)
		return _reinterpretGet();
	else
		throw new Exception("Reinterpretation error!");
}+/
/+
/**
 * Safely converts the type of an array.
 * NOTE: by 0.10.0, an external library will replace this.
 */
public T[] reinterpretCast(T, S)(S[] source) pure @trusted {
	T[] _reinterpretCast() pure @system {
		return cast(T[])(cast(void[])source);
	}
	if((S.sizeof * source.length) % T.sizeof == 0)
		return _reinterpretCast();
	else
		throw new Exception("Reinterpretation error!");
}+/
/+
/**
 * Safely converts a single instance into a bytestream.
 * NOTE: by 0.10.0, an external library will replace this.
 */
public T[] toStream(T = ubyte, S)(S source) pure @trusted {
	T[] _toStream() pure @system {
		return cast(T[])(cast(void[])[source]);
	}
	if(S.sizeof % T.sizeof == 0)
		return _toStream();
	else
		throw new Exception("Reinterpretation error!");
}+/
alias toStream = reinterpretAsArray;
/**
 * Checks whether object `o` have implemented the given interface.
 * Checks are done on the basis of name strings.
 */
public bool isInterface(string I)(Object o) pure @safe nothrow {
	foreach(Interface i; o.classinfo.interfaces) {
		if(i.classinfo.name == I) return true;
	}
	return false;
}
/**
 * Compares object pointers to detect duplicates.
 */
public bool cmpObjPtr(O)(O a, O b) @nogc @trusted pure nothrow {
	bool _cmp() @nogc @system pure nothrow {
		return cast(void*)a == cast(void*)b;
	}
	return _cmp();
}
/**
 * Calculates the MurMurHashV3/32 value of a string.
 * CTFE friendly.
 */
uint hashCalc(string src, const uint seed = 0) @nogc @safe pure nothrow {
	uint scramble(uint k) @nogc @safe pure nothrow {
		k *= 0xcc9e2d51;
		k = (k << 15) | (k >> 17);
		k *= 0x1b873593;
		return k;
	}
	size_t pos;
	uint h = seed, k;
	const int remainder = cast(int)(src.length % 4);
	const size_t length = src.length - remainder;
	for ( ; pos < length ; pos+=4) {
		k = (cast(uint)src[pos+3] << 24) | (cast(uint)src[pos+2] << 16) | (cast(uint)src[pos+1] << 8) | (cast(uint)src[pos+0]);
		h ^= scramble(k);
		h = (h << 13) | (h >> 19);
		h = h * 5 + 0xe6546b64;
	}
	//Read the rest
	k = 0;
	for (int i = remainder ; i ; i--) {
		k <<= 8;
		k |= cast(uint)src[pos+i-1];
	}
	// A swap is *not* necessary here because the preceding loop already
	// places the low bytes in the low places according to whatever endianness
	// we use. Swaps only apply when the memory is copied in a chunk.
	h ^= scramble(k);
    
	//Finalize
	h ^= cast(uint)src.length;
	h ^= h >> 16;
	h *= 0x85ebca6b;
	h ^= h >> 13;
	h *= 0xc2b2ae35;
	h ^= h >> 16;
	return h;
}
/**
 * Removes all symbols from the string that is not in the symbol pool.
 */
S removeUnallowedSymbols(S)(S input, S symbolList) @safe pure nothrow {
	S result;
	foreach (c ; input) {
		if (count(symbolList, c))
			result ~= c;
	}
	return result;
}
/**
 * Clamps a value between of two.
 */
pragma(inline, true)
T clamp(T)(ref T input, const T min, const T max) @nogc @safe pure nothrow {
	if (input >= max) input = max;
	else if (input <= min) input = min;
	return input;
}
/**
 * Returns the lesser of two values.
 */
pragma(inline, true)
T min(T)(T a, T b) @nogc @safe pure nothrow {
	return a < b ? a : b;
}
/**
 * Returns the greater of two values.
 */
pragma(inline, true)
T max(T)(T a, T b) @nogc @safe pure nothrow {
	return a > b ? a : b;
}