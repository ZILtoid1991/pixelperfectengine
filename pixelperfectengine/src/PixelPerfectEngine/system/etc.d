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
			case 1: result ~='1'; break;
			case 2: result ~='2'; break;
			case 3: result ~='3'; break;
			case 4: result ~='4'; break;
			case 5: result ~='5'; break;
			case 6: result ~='6'; break;
			case 7: result ~='7'; break;
			case 8: result ~='8'; break;
			case 9: result ~='9'; break;
			case 10: result ~='A'; break;
			case 11: result ~='B'; break;
			case 12: result ~='C'; break;
			case 13: result ~='D'; break;
			case 14: result ~='E'; break;
			case 15: result ~='F'; break;
			default: result ~='0'; break;
		}
		i = i >>> 4;
	}while(i > 0);
	if(result.length < format){
		for(size_t j = result.length ; j < format ; j++){
			result ~= '0';
		}
	}
	result = result.dup.reverse;
	return result;
}
///Returns a octal string representation of the integer.
string intToOct(int i, int format) pure @safe{
	string result;
	do{
		switch(i & 0x0007){
			case 1: result ~='1'; break;
			case 2: result ~='2'; break;
			case 3: result ~='3'; break;
			case 4: result ~='4'; break;
			case 5: result ~='5'; break;
			case 6: result ~='6'; break;
			case 7: result ~='7'; break;
			default: result ~='0'; break;
		}
		i = i / 8;
	}while(i > 0);
	if(result.length < format){
		for(size_t j = result.length ; j < format ; j++){
			result ~= '0';
		}
	}
	result = result.dup.reverse;
	return result;
}
///Parses a hexadecimal int represented as a string.
int parseHex(string s) pure @safe{

	int result;
	for(int i ; i < s.length; i++){
		result *= 16;
		switch(s[i]){
			case '0': break;
			case '1': result += 1; break;
			case '2': result += 2; break;
			case '3': result += 3; break;
			case '4': result += 4; break;
			case '5': result += 5; break;
			case '6': result += 6; break;
			case '7': result += 7; break;
			case '8': result += 8; break;
			case '9': result += 9; break;
			case 'a','A': result += 10; break;
			case 'b','B': result += 11; break;
			case 'c','C': result += 12; break;
			case 'd','D': result += 13; break;
			case 'e','E': result += 14; break;
			case 'f','F': result += 15; break;
			default: throw new Exception("String cannot be parsed!");
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
public @nogc bool isPowerOf2(T = uint)(T x) pure @safe{
	return x && ((x & (x - 1U)) == 0U);
}

/**
 * From "Hackers Delight"
 * val remains unchanged if it is already a power of 2.
 */
public @nogc T nextPow2(T)(T val) pure @safe{
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
