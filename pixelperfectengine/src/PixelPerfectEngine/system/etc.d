module PixelPerfectEngine.system.etc;

import std.conv;
import std.algorithm.mutation;
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
S[] csvParser(S)(S input, char separator = ',') pure @safe{
	S[] result;
	int j;
	for(int i ; i < input.length ; i++){
		if(input[i] == separator){
			result ~= input[j..i];
			j = i + 1;
		}
	}

	return result;
}
///Joins prettyprint strings to a single string for file storage.
S stringArrayJoin(S)(S[] input) pure @safe{
	S result;
	foreach(s ; input){
		result ~= s ~ "\n";
	}
	return result;
}
///Tests if the input string is integer and returns true if it is.
bool isInteger(S)(S s) pure @safe{
	static if(S.mangleof == string.mangleof || S.mangleof == wstring.mangleof || S.mangleof == dstring.mangleof){
		foreach(c; s){
			if(c > '9' || c < '0')
				return false;
		}
		return true;
	}else static assert(false, "Template patameter " ~ S.stringof ~ " not supported in function 'bool isInteger(S)(S s)'
			of module 'PixelPerfectEngine.system.etc'");
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
}
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
}
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
}
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
public bool cmpObjPtr(Object a, Object b) @nogc @trusted pure nothrow {
	bool _cmp() @nogc @system pure nothrow {
		return cast(void*)a == cast(void*)b;
	}
	return _cmp();
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