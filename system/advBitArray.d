module system.advBitArray;
import std.stdio;

public class AdvancedBitArray{
	protected void[] rawData;
	protected int length;


	this(int length){
		setLength(length);

	}
	this(void[] data, int l){
		rawData = data;
		rawData.length += 16;
		if(rawData.length % 16){
			rawData.length += 16 - (rawData.length % 16);
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
		if(length > l){

			rawData.length = l%8 == 0 ? l/8 : (l/8)+1;


			//set end bits to zero
			void* b = rawData.ptr + rawData.length - 1;
			for(int i = l % 8 ; i < 8 ; i++){
				asm{
					xor EAX, EAX;
					mov	EBX, b[EBP];
					mov EDX, i;
					mov AL, [EBX];
					btr	AX, DX;
					mov	[EBX], AL;

				}
			}

			//add extra 128 bit to the end to avoid accidents related to bit-shifting
			rawData.length += 16;

			if(rawData.length%16==0){
				rawData.length += 16-rawData.length%16;
			}
		}else if(l - length < (128 - length % 128)){
			//if array don't need to be resized and just a few extra bits needed at the end
		}else{
			rawData.length = l%8 == 0 ? l/8 : (l/8)+1;
			rawData.length += 16;
			if(rawData.length%16==0){
				rawData.length += 16-rawData.length%16;
			}
		}
		this.length = l;
	}
	bool opEquals()(auto ref const AdvancedBitArray o) {  
		/*ulong *a = cast(ulong*)rawData.ptr; 
		ulong *b = cast(ulong*)o.rawData.ptr;
		for(int i; i < lenght / 8; i++){
			if(*(a+i)!=*(b+i)) return false;
		}*/
		void* a = rawData.ptr, b = o.rawData.ptr;
		for(int i; i < length / 128; i+=16){
			void[16]* a0 = cast(void[16]*)a, b0 = cast(void[16]*)b;
			ushort[8] res;
			asm{
				movups	XMM0, [a0];
				movups	XMM1, [b0];
				pcmpeqw	XMM0, XMM1;
				movups	res, XMM0;
			}
			if(res[0] + res[1] + res[2] + res[3] + res[4] + res[5] + res[6] + res[7] != 0x7FFF8){
				return false;
			}
			a += 16;
			b += 16;
		}
		return true;
	}
	AdvancedBitArray opBinary(string op)(int rhs){
		static if(op == ">>"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			void[] result;
			result.length = rawData.length;
			/*if(bitShift == 0){
				for(int i ; i < (length / 8) - byteShift ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);

					*ps = *pd;
				}
			}else{
				int o = 64 - bitShift;
				for(int i ; i < (length / 8) - byteShift ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);

					asm{
						pxor	XMM4, XMM4;
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						movq	XMM4, bitShift;
						psllq	XMM0, 6;
						movq	XMM4, o;
						psrlq	XMM1, 58;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}
			}*/
			switch(bitShift){
				case(1):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 1;
							psrlq	XMM1, 63;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}
					break;
				case(2):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 2;
							psrlq	XMM1, 62;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(3):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 3;
							psrlq	XMM1, 61;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(4):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 4;
							psrlq	XMM1, 60;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(5):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 5;
							psrlq	XMM1, 59;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(6):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 6;
							psrlq	XMM1, 58;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(7):
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psllq	XMM0, 7;
							psrlq	XMM1, 57;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				default: 
					for(int i ; i < (length / 8) - byteShift ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + byteShift + i), pd = cast(void[16]*)(result.ptr + i);

						asm{
							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}
					break;
			}
			AdvancedBitArray x = new AdvancedBitArray(result, length);
			
			return x;
		}else static if(op == "<<"){
			int byteShift = rhs / 8, bitShift = rhs % 8;
			void[] result;
			result.length = rawData.length;
			/*if(bitShift == 0){
				for(int i ; i + byteShift < (length / 8) ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);

					*ps = *pd;
				}
			}else{
				int o = 64 - bitShift;
				for(int i ; i + byteShift < (length / 8) ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						pxor	XMM4, XMM4;
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						movq	XMM4, bitShift;
						psrlq	XMM0, 6;
						movq	XMM4, o;
						psllq	XMM1, 58;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}
			}*/
			switch(bitShift){
				case(1):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 1;
							psllq	XMM1, 63;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(2):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 2;
							psllq	XMM1, 62;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(3):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 3;
							psllq	XMM1, 61;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(4):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 4;
							psllq	XMM1, 60;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(5):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 5;
							psllq	XMM1, 59;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(6):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 6;
							psllq	XMM1, 58;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				case(7):
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{

							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							add		EBX, 8;
							movups	XMM1, [EBX];
							psrlq	XMM0, 7;
							psllq	XMM1, 57;
							por		XMM0, XMM1;
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}break;
				default: 
					for(int i ; i + byteShift < (length / 8) ; i+=16){
						void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
						
						asm{
							mov		EBX, ps[EBP];
							movups	XMM0, [EBX];
							mov		EBX, pd[EBP];
							movups	[EBX], XMM0;
						}
					}
					break;
			}
			AdvancedBitArray x = new AdvancedBitArray(result, length);
			
			return x;
		}else static assert(0, "Operator "~op~" not implemented");
	}
	AdvancedBitArray opBinary(string op)(AdvancedBitArray rhs){
		static if(op == "&"){
			void *a = rawData.ptr;
			void *b = rhs.rawData.ptr;
			void[] result; 
			result.length = rawData.length;
			for(int i; i < length / 128; i+=16){
				//*cast(ulong*)(result.ptr + i) = *(a + i) & *(b + i);
				void[16] a0 = *cast(void[16]*)a, b0 = *cast(void[16]*)b;
				void[16]* r = cast(void[16]*)(result.ptr + i);
				asm{
					movups	XMM0, a0;
					movups	XMM1, b0;
					pand	XMM0, XMM1;
					mov		EBX, r[EBP];
					movups	[EBX], XMM0;
				}
				a += 16;
				b += 16;
			}
			return new AdvancedBitArray(result, length);
		}else static if(op == "|"){
			void *a = rawData.ptr;
			void *b = rhs.rawData.ptr;
			void[] result; 
			result.length = rawData.length;
			for(int i; i < length / 128; i+=16){
				//*cast(ulong*)(result.ptr + i) = *(a + i) & *(b + i);
				void[16] a0 = *cast(void[16]*)a, b0 = *cast(void[16]*)b;
				void[16]* r = cast(void[16]*)(result.ptr + i);
				asm{
					movups	XMM0, [a];
					movups	XMM1, [b];
					por		XMM0, XMM1;
					mov		EBX, r[EBP];
					movups	[EBX], XMM0;
				}
				a += 16;
				b += 16;
			}
			return new AdvancedBitArray(result, length);
		}else static if(op == "^"){
			void *a = rawData.ptr;
			void *b = rhs.rawData.ptr;
			void[] result; 
			result.length = rawData.length;
			for(int i; i < length / 128; i+=16){
				//*cast(ulong*)(result.ptr + i) = *(a + i) & *(b + i);
				void[16] a0 = *cast(void[16]*)a, b0 = *cast(void[16]*)b;
				void[16]* r = cast(void[16]*)(result.ptr + i);
				asm{
					movups	XMM0, [a];
					movups	XMM1, [b];
					pxor	XMM0, XMM1;
					mov		EBX, r[EBP];
					movups	[EBX], XMM0;
				}
				a += 16;
				b += 16;
			}
			return new AdvancedBitArray(result, length);
		}else static assert(0, "Operator "~op~" not implemented");
	}

	public string toString(){
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

		}else static if(op == "|"){

		}else static if(op == "^"){

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
		int a = i / 8, b = i % 8;
		if(value){
			asm{
				xor		EAX, EAX;
				mov		AL, rawData[a];
				mov		EDX, b;
				bts		AX, DX;
				mov 	rawData[a], AL;
			}
		}else{
			asm{
				xor		EAX, EAX;
				mov		AL, rawData[a];
				mov		EDX, b;
				btc		AX, DX;
				mov 	rawData[a], AL;
			}
		}
		return value;
	}

	bool opIndex(size_t i){
		ubyte x = *cast(ubyte*)(rawData.ptr + i / 8);
		ubyte bit = i % 8;
		asm{
			xor 	EAX, EAX;
			xor 	EDX, EDX;
			mov 	AL, x;
			mov		DL, bit;
			bt		AX, DX;
			setc	DL;
			mov		x, DL;
		}
		return x != 0;
	}
	AdvancedBitArray opSlice(size_t i1, size_t i2){
		int bitShift = i1 % 8, bitShift2 = i2 % 8, byteShift = i1 / 8, byteShift2 = i2 / 8, l = i2 - i1, l2 = byteShift2 - byteShift;
		void[] result;// = rawData[byteShift1..byteShift2];

		result.length = l2;

		switch(bitShift){
			case(1):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					//writeln(result.ptr + byteShift + i);
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 1;
						psllq	XMM1, 63;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(2):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 2;
						psllq	XMM1, 62;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(3):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 3;
						psllq	XMM1, 61;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(4):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 4;
						psllq	XMM1, 60;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(5):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 5;
						psllq	XMM1, 59;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(6):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 6;
						psllq	XMM1, 58;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			case(7):
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						add		EBX, 8;
						movups	XMM1, [EBX];
						psrlq	XMM0, 7;
						psllq	XMM1, 57;
						por		XMM0, XMM1;
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}break;
			default: 
				for(int i ; i + byteShift < l2 ; i+=16){
					void[16]* ps = cast(void[16]*)(rawData.ptr + i), pd = cast(void[16]*)(result.ptr + byteShift + i);
					
					asm{
						mov		EBX, ps[EBP];
						movups	XMM0, [EBX];
						mov		EBX, pd[EBP];
						movups	[EBX], XMM0;
					}
				}
				break;
		}
		AdvancedBitArray x = new AdvancedBitArray(result, l);
		
		return x;

	}

}