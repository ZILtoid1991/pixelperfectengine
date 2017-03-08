/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, AdvancedBitArray module
 */

module PixelPerfectEngine.system.advBitArray;
import std.stdio;
/**
* Mainly intended for collision detection, can be used for other purposes too.
*/
public class AdvancedBitArray{
	private static const ubyte[8] maskData = [0b11111110,0b11111101,0b11111011,0b11110111,0b11101111,0b11011111,0b10111111,0b01111111];
	protected void[] rawData;
	protected int length;


	this(int length){
		setLength(length);

	}
	this(void[] data, int l){
		rawData = data;
		rawData.length += 4;
		if(rawData.length % 4){
			rawData.length += 4 - (rawData.length % 4);
		}
		length = l;
	}
	//this(bool[] data){}

	public int getLenght(){
		return length;
	}

	public void setLength(int l){
		//test if resizing needed
		if(length == l) return;
		else if(length < l){
			if((l + 32) / 8 > rawData.length){
				rawData.length = (l + 32 + (32 - l%32)) / 8;
			}
		}else{
			for(int i = l ; i < length ; i++){
				this[i] = false;
			}
			rawData.length = (l + 32 + (32 - l%32)) / 8;
		}
		this.length = l;
	}
	bool opEquals()(auto ref const AdvancedBitArray o) {  
		for(int i ; i < rawData.length ; i += 4){
			if(cast(uint)rawData[i] != cast(uint)o.rawData[i]) return false;
		}
		return true;
	}
	AdvancedBitArray opBinary(string op)(int rhs){
		static if(op == ">>"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			AdvancedBitArray result = new AdvancedBitArray(this.length);
			//result.length = rawData.length;
			if(bitShift == 0){
				for(int i ; i < rawData.length - byteShift ; i+=4){
					*cast(uint*)(result.rawData.ptr + i + byteShift) = *cast(uint*)(rawData.ptr + i);
				}
			}else{
				for(int i ; i < rawData.length - byteShift ; i+=4){
					uint dA = *cast(uint*)(rawData.ptr + i), dB = i == 0 ? 0 : *cast(uint*)(rawData.ptr + i - 1);
					dA >>= bitShift;
					dB <<= (32-bitShift);
					*cast(uint*)(result.rawData.ptr + i + byteShift) = dA || dB;
				}
			}
			return result;
		}else static if(op == "<<"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			AdvancedBitArray result = new AdvancedBitArray(this.length);
			//result.length = rawData.length;
			if(bitShift == 0){
				for(int i ; i < rawData.length - byteShift ; i+=4){
					*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i + byteShift);
				}
			}else{
				for(int i ; i < rawData.length - byteShift ; i+=4){
					uint dA = *cast(uint*)(rawData.ptr + i + byteShift), dB = *cast(uint*)(rawData.ptr + i + byteShift + 1);
					dA<<=bitShift;
					dB>>=(32-bitShift);
					*cast(uint*)(result.rawData.ptr + i + byteShift) = dA || dB;
				}
			}
			return result;
		}else static assert(0, "Operator "~op~" not implemented");
	}
	AdvancedBitArray opBinary(string op)(AdvancedBitArray rhs){
		static if(op == "&"){
			AdvancedBitArray result = new AdvancedBitArray(length);
			for(int i ; i < rawData.length ; i+=4){
				*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i) & *cast(uint*)(rhs.rawData.ptr + i);
			}
			return result;
		}else static if(op == "|"){
			AdvancedBitArray result = new AdvancedBitArray(length);
			for(int i ; i < rawData.length ; i+=4){
				*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i) | *cast(uint*)(rhs.rawData.ptr + i);
			}
			return result;
		}else static if(op == "^"){
			AdvancedBitArray result = new AdvancedBitArray(length);
			for(int i ; i < rawData.length ; i+=4){
				*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i) ^ *cast(uint*)(rhs.rawData.ptr + i);
			}
			return result;
		}else static assert(0, "Operator "~op~" not implemented");
	}

	public override string toString(){
		string result = "[";
		for(int i ; i < length ; i++){
			if(this[i]){
				result ~= "1";
			}else{
				result ~= "0";
			}
		}
		result ~= "]";
		return result;
	}

	ref AdvancedBitArray opOPAssign(string op)(AdvancedBitArray rhs){
		static if(op == "&"){
			for(int i ; i < rawData.length ; i+=4){
				cast(uint)rawData[i] &= cast(uint)rhs.rawData[i];
			}
		}else static if(op == "|"){
			for(int i ; i < rawData.length ; i+=4){
				cast(uint)rawData[i] |= cast(uint)rhs.rawData[i];
			}
		}else static if(op == "^"){
			for(int i ; i < rawData.length ; i+=4){
				cast(uint)rawData[i] ^= cast(uint)rhs.rawData[i];
			}
		}else static if(op == "~"){
			/*int oldlength = length;
			this.setLength(length+rhs.length);*/
			if(length%8 == 0){
				rawData.length=length/8;
				rawData ~= rhs.rawData;
				this.setLength(length+rhs.length);
			}else{

			}
		}else static assert(0, "Operator "~op~" not implemented");
	}

	ref AdvancedBitArray opOPAssign(string op)(bool rhs){
		static if(op == "~"){
			this[length] = rhs;
			length++;
			if(length % 128 == 0){
				rawData.length += 16;
			}
		}else static assert(0, "Operator "~op~" not implemented");
	}

	bool opIndexAssign(bool value, size_t i){
		int bytepos = i / 8, bitpos = i % 8;
		if(value){
			*cast(ubyte*)(rawData.ptr + bytepos) |= 0xFF - maskData[bitpos];
		}else{
			*cast(ubyte*)(rawData.ptr + bytepos) &= maskData[bitpos];
		}
		return value;
	}

	bool opIndex(size_t i){
		int bytepos = i / 8, bitpos = i % 8;
		return (*cast(ubyte*)(rawData.ptr + bytepos) & (0xFF - maskData[bitpos])) != 0;
	}
	AdvancedBitArray opSlice(size_t i1, size_t i2){
		int bitShift = i1 % 8, bitShift2 = i2 % 8, byteShift = i1 / 8, byteShift2 = i2 / 8, l = i2 - i1, l2 = byteShift2 - byteShift;
		AdvancedBitArray result = new AdvancedBitArray(l);
		if(bitShift == 0){
			for(int i ; i < l2 ; i+=4){
				*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i + byteShift);
			}
			if(l % 32 == 0){
				return result;
			}
		}else{
			for(int i ; i < l2 ; i+=4){
				*cast(uint*)(result.rawData.ptr + i) = *cast(uint*)(rawData.ptr + i + byteShift);
			}
		}
		return result;
	}
	/**
	* Tests multiple values at once. The intended algorithm didn't work as intended, replacement is coming in 0.9.2, in the meanwhile I'm using a slower but safer one.
	*/
	public bool test(int from, int length, AdvancedBitArray target, int tfrom){
		for(int i ; i < length ; i++){
			if(opIndex(from + i) && target[tfrom + i]){
				return true;
			}
		}
		/*int bitShiftA = from%8, bitShiftB = tfrom%8, bitlength = length%8, bitlength2 = length%32, byteShiftA = from/8, byteShiftB = tfrom/8, wordlength = length / 8;
		int i = -3;
		/*
		if(bitShiftA && bitShiftB){
			for(; i < wordlength; i++){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA))<<bitShiftA | (*cast(ubyte*)(rawData.ptr + byteShiftA + 1))>>(8 - bitShiftA) & 0xff,
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB))<<bitShiftB | (*cast(ubyte*)(target.rawData.ptr + byteShiftB + 1))>>(8 - bitShiftB) & 0xff;
				if(a & b){
					return true;
				}
			}
			if(bitlength){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA))<<bitShiftA | (*cast(ubyte*)(rawData.ptr + byteShiftA + 1))>>(8 - bitShiftA) & 0xff,
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB))<<bitShiftB | (*cast(ubyte*)(target.rawData.ptr + byteShiftB + 1))>>(8 - bitShiftB) & 0xff;
				a >>= bitlength;
				b >>= bitlength;
				if(a & b  & 0xff){
					return true;
				}
			}
		}else if(bitShiftB){
			for(; i < wordlength; i++){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA)),
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB))<<bitShiftB | (*cast(ubyte*)(target.rawData.ptr + byteShiftB + 1))>>(8 - bitShiftB) & 0xff;
				if(a & b){
					return true;
				}
			}
			if(bitlength){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA)),
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB))<<bitShiftB | (*cast(ubyte*)(target.rawData.ptr + byteShiftB + 1))>>(8 - bitShiftB) & 0xff;
				a >>= bitlength;
				b >>= bitlength;
				if(a & b  & 0xff){
					return true;
				}
			}
		}else if(bitShiftA){
			for(; i < wordlength; i++){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA))<<bitShiftA | (*cast(ubyte*)(rawData.ptr + byteShiftA + 1))>>(8 - bitShiftA) & 0xff,
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB));
				if(a & b){
					return true;
				}
			}
			if(bitlength){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA))<<bitShiftA | (*cast(ubyte*)(rawData.ptr + byteShiftA + 1))>>(8 - bitShiftA) & 0xff,
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB));
				a >>= bitlength;
				b >>= bitlength;
				if(a & b & 0xff){
					return true;
				}
			}
		}else{
			for(; i < wordlength; i++){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA)),
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB));
				if(a & b){
					return true;
				}
			}
			if(bitlength){
				int a = (*cast(ubyte*)(rawData.ptr + byteShiftA)),
					b = (*cast(ubyte*)(target.rawData.ptr + byteShiftB));
				a >>= bitlength;
				b >>= bitlength;
				if(a & b & 0xff){
					return true;
				}
			}
		}*/

		/*if(bitShiftA && bitShiftB){
			for( ; i < wordlength - 7 ; i+=4){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i))<<bitShiftA | (*cast(uint*)(rawData.ptr + (byteShiftA)+1+i))>>(32-bitShiftA), 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i))<<bitShiftB | (*cast(uint*)(target.rawData.ptr + (byteShiftB)+1+i))>>(32-bitShiftB);
				//writeln(a,',',b);
				if((a & b)){
					return true;
				}
			}
			if(i < wordlength - 3 || bitlength){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i))<<bitShiftA | (*cast(uint*)(rawData.ptr + (byteShiftA)+3+i))>>(32-bitShiftA), 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i))<<bitShiftB | (*cast(uint*)(target.rawData.ptr + (byteShiftB)+1+i))>>(32-bitShiftB);
				a >>= 32 - bitlength2;
				b >>= 32 - bitlength2;
				//writeln(a,',',b);
			if((a & b)){
				return true;
			}
		}
		}else if(bitShiftB){
			for( ; i < wordlength - 7 ; i+=4){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i)<<bitShiftA) , 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i))<<bitShiftB | (*cast(uint*)(target.rawData.ptr + (byteShiftB)+3+i))>>(32-bitShiftB);
				//writeln(a,',',b);
				if(!(a & b)){
					return true;
				}
			}
			if(i < wordlength - 3 || bitlength){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i)<<bitShiftA) , 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i))<<bitShiftB | (*cast(uint*)(target.rawData.ptr + (byteShiftB)+3+i))>>(32-bitShiftB);
				a >>= 32 - bitlength2;
				b >>= 32 - bitlength2;
				//writeln(a,',',b);
				if((a & b)){
					return true;
				}
			}
		}else if(bitShiftA){
			for( ; i < wordlength - 7 ; i+=4){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i))<<bitShiftA | (*cast(uint*)(rawData.ptr + (byteShiftA)+4+i))>>(32-bitShiftA), 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i)<<bitShiftB) ;
				//writeln(a,',',b);
				if((a & b)){
					return true;
				}
			}
			if(i < wordlength - 3 || bitlength){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i))<<bitShiftA | (*cast(uint*)(rawData.ptr + (byteShiftA)+4+i))>>(32-bitShiftA), 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i)) ;
				a >>= 32 - bitlength2;
				b >>= 32 - bitlength2;
				//writeln(a,',',b);
				if((a & b)){
					return true;
				}
			}
		}else{
			for( ; i < wordlength - 7 ; i+=4){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i)) , 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i)) ;
				//writeln(a,',',b);
				if((a & b)){
					return true;
				}
			}
			if(i < wordlength - 3 || bitlength){
				uint a = (*cast(uint*)(rawData.ptr + (byteShiftA)+i)) , 
					b = (*cast(uint*)(target.rawData.ptr + (byteShiftB)+i)) ;
				//writeln(a,',',b);
				a >>= 32 - bitlength2;
				b >>= 32 - bitlength2;
				if((a & b)){
					return true;
				}
			}
		}/**/
		return false;
	}
	/*unittest{
		AdvancedBitArray a = new AdvancedBitArray([0b0,0b0,0b11111111,0b11111111,0b11111111,0b11111111,0b0,0b0],64);
		AdvancedBitArray b = new AdvancedBitArray([0b0,0b0,0b11111111,0b11111111,0b11111111,0b11111111,0b0,0b0],64);

		assert(a.test(0,8,b,0) == false);
		assert(a.test(8,8,b,0) == false);
		assert(a.test(0,8,b,8) == false);
		assert(a.test(8,8,b,8) == false);

		assert(a.test(0,16,b,0) == false);

		assert(a.test(0,8,b,48) == false);
		assert(a.test(0,8,b,56) == false);
		assert(a.test(8,8,b,48) == false);
		assert(a.test(8,8,b,56) == false);
	}*/
}