module PixelPerfectEngine.audio.firFilter;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, FIR filter module
 */

import PixelPerfectEngine.system.etc;

version(LDC){
	import inteli.emmintrin;
	import core.stdc.stdlib;
	import core.stdc.string;
}
/**
 * Defines a finite impulse response.
 */
public struct FiniteImpulseResponse(int L){
	//static assert(L % 2 == 0);
	public short[L] vals;	///Holds the values.
}
/**
 * Implements a finite impulse response filter.
 */
public struct FiniteImpulseResponseFilter(int L)
		if(isPowerOf2(L)){
	FiniteImpulseResponse!L* impulseResponse;	///Pointer to the impulse response
	private short[L + 8] delayLine;				///Contains the delay line
	private uint stepping;
	private const uint truncating = L - 1;
	this(FiniteImpulseResponse!L* impulseResponse){
		this.impulseResponse = impulseResponse;

	}
	version(LDC){
		public @nogc int calculate(short input){
			int4 result;
			memcpy(delayLine.ptr + L, delayLine.ptr, 16);
			delayLine[L - stepping] = input;

			for(int i ; i < L ; i+=8){
				short8* src = cast(short8*)cast(void*)impulseResponse.vals.ptr;
				short8* dlPtr = cast(short8*)cast(void*)(delayLine.ptr + (stepping + i & truncating));
				result += _mm_madd_epi16(*src, *dlPtr);
			}
			stepping++;
			stepping &= truncating;
			return result[0] + result[1] + result[2] + result[3];
		}
	}else{
		public @nogc int calculate(short input){
			if(stepping < 3){
				delayLine[L + (L - stepping)] = input;
			}
			delayLine[L - stepping] = input;
			version(X86){
				int[4] result;
				asm @nogc{
					mov		ESI, impulseResponse[EBP];
					mov		EDI, delayLine[EBP];
					mov		EDX, stepping;
					mov		EAX, truncating;
					mov		ECX, L;

				filterloop:
					mov		EBX, EDX;
					and		EBX, EAX;
					add		EBX, EDI;
					movups	XMM0, [EBX];
					movups	XMM1, [ESI];
					pmaddwd	XMM1, XMM0;
					paddd	XMM2, XMM1;
					add		ESI, 16;
					add		EDX, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		filterloop;
					movups	result, XMM2;
				}
				stepping++;
				stepping &= truncating;
				return result[0] + result[1] + result[2] + result[3];
			}else version(X86_64){
				int[4] result;
				asm @nogc{
					mov		RSI, impulseResponse[RBP];
					mov		RDI, delayLine[RBP];
					mov		EDX, stepping;
					mov		EAX, truncating;
					mov		ECX, L;

				filterloop:
					mov		RBX, RDX;
					and		RBX, RAX;
					add		RBX, RDI;
					movups	XMM0, [RBX];
					movups	XMM1, [RSI];
					mulps	XMM1, XMM0;
					addps	XMM2, XMM1;
					add		RSI, 16;
					add		RDX, 16;
					dec		ECX;
					cmp		ECX, 0;
					jnz		filterloop;
					movups	result, XMM2;
				}
				stepping++;
				stepping &= truncating;
				return result[0] + result[1] + result[2] + result[3];
			}else{
				int result;
				for(int i; i < L; i++){
					result += delayLine[(i + stepping) & truncating] * impulseResponse.vals[i];
				}
				stepping++;
				stepping &= truncating;
				return result;
			}

		}
	}
}
