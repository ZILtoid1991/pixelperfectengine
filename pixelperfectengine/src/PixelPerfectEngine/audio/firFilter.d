module PixelPerfectEngine.audio.firFilter;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, FIR filter module
 */

public struct FiniteImpulseResponse(int L){
	//static assert(L % 2 == 0);
	public float[L] vals;
}

public struct FiniteImpulseResponseFilter(int L){
	FiniteImpulseResponse!L* impulseResponse;
	private float[L + 3] delayLine;
	private uint stepping;
	private uint truncating;
	this(FiniteImpulseResponse!L* impulseResponse){
		this.impulseResponse = impulseResponse;
		version(X86){
			truncating = (L * 4) - 1;
		}else version(X86_64){
			truncating = (L * 4) - 1;
		}else{
			truncating = L - 1;
		}
	}
	public @nogc float filter(float input){
		if(stepping < 3){
			delayLine[L + (L - stepping)] = input;
		}
		delayLine[L - stepping] = input;
		version(X86){
			float[4] result;
			asm @nogc{
				mov		ESI, impulseResponse[EBP];
				mov		EDI, delayLine[EBP];
				mov		EDX, stepping;
				mov		EAX, truncating;
				mov		ECX, L;

			filterloop:
				xor		EBX, EBX;
				add		EBX, EDX;
				and		EBX, EAX;
				add		EBX, EDI;
				movups	XMM0, [EBX];
				movups	XMM1, [ESI];
				mulps	XMM1, XMM0;
				addps	XMM2, XMM1;
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
			float[4] result;
			asm @nogc{
				mov		RSI, impulseResponse[RBP];
				mov		RDI, delayLine[RBP];
				mov		EDX, stepping;
				mov		EAX, truncating;
				mov		ECX, L;

			filterloop:
				xor		RBX, RBX;
				add		RBX, RDX;
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
			float result;
			for(int i; i < L; i++){
				result += delayLine[(i + stepping) & truncating] * impulseResponse.vals[i];
			}
			stepping++;
			stepping &= truncating;
		}
		
	}
}