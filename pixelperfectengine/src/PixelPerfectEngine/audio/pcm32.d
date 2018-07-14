/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.pcm32 module
 */

module PixelPerfectEngine.audio.pcm32;

import PixelPerfectEngine.audio.common;
import PixelPerfectEngine.audio.firFilter;
import PixelPerfectEngine.audio.envGen;
import PixelPerfectEngine.audio.lfo;

import libPCM.codecs;
import libPCM.common;

import std.bitmanip;

/**
 * Sampling synthesizer implementation. Has per channel FIR (1024 stage) and IIR (low-pass) filters, and four stereo outputs.
 */
public class PCM32 : AbstractPPEFX{
	/**
	 * Defines the source of certain modifier values
	 */
	public enum ControlSource : ubyte{
		NULL			=	0,
		Pitch			=	1,
		Velocity		=	2,
		ExpressiveVal	=	3,
	}
	/**
	 * Per-octave dampening
	 */
	public enum Dampening : ubyte{
		DB00			=	0,
		DB15			=	1,
		DB30			=	2,
		DB60			=	3,
	}
	protected struct Channel{
		short delegate(ubyte* inputStream, DecoderWorkpad* workpad) codec;
		uint loopfrom, loopto;	///describe a loop cycle between the two values
		uint stepping;			///describes how much the sample should go forward, 65536 equals a whole step
		ulong forward;			///current position
		short[] intBuff;		///buffer for FIR-filters
		CodecType codecType;
		DecoderWorkpad workpad, secWorkpad;
		EnvelopeGenerator envGenA;
		EnvelopeGenerator envGenB;
		FiniteImpulseResponseFilter!(1024)[2] firFilter;
		LowFreqOsc!(256) lfo;
	}
	float sampleRate;
	int frameLength, bufferLength;
	version(X86){
		/**
		 * Contains IIR related registers in order for use in SSE2 applications
		 */
		protected struct IIRFilterBuff{
			float[4] b0a0;
			//float[4] x_n;
			float[4] b1a0;
			float[4] x_n_minus1;
			float[4] b2a0;
			float[4] x_n_minus2;
			float[4] a1a0;
			float[4] y_n_minus1;
			float[4] a2a0;
			float[4] y_n_minus2;
			//float[4] y_n;
		}
		IIRFilterBuff[8] iirFilters;
		void* iirFiltersPtr;
	}else{
		float[32] x_n_minus1, x_n_minus2, y_n_minus1, y_n_minus2, b0a0, b1a0, b2a0, a1a0, a2a0;
	}
	float[32][] y_n, x_n;
	

	protected @nogc void calculateIIR(){
		version(X86){
			float* y_nptr = cast(float*)y_n.ptr;
			float* x_nptr = cast(float*)x_n.ptr;
			for(int i = frameLength * bufferLength ; i >= 0 ; i--){
				asm @nogc{
					mov		ECX, 8;
					//mov		ESI, iirFiltersPtr[EBP];
					mov		EDI, y_nptr;
					mov		EBX, x_nptr;
				iirLoop:
					movaps	XMM0, [ESI];//load b0/a0
					movaps	XMM1, [EBX];//load x_n
					mulps	XMM0, XMM1;	//(b0/a0) * x_n
					add		ESI, 16;	//offset ESI to b1a0
					movaps	XMM2, [ESI];//load b1a0
					add		ESI, 16;	//offset ESI to x_n_minus1
					movaps	XMM3, [ESI];//load x_n_minus1
					movaps	[ESI], XMM1;//store current x_n as x_n_minus1
					mulps	XMM2, XMM3;	//(b1/a0) * x_n_minus1
					addps	XMM0, XMM2;	//(b0/a0) * x_n + (b1/a0) * x_n_minus1
					add		ESI, 16;	//offset ESI to b2a0
					movaps	XMM2, [ESI];//load b2a0
					add		ESI, 16;	//offset ESI to x_n_minus2
					movaps	XMM4, [ESI];//load x_n_minus2
					movaps	[ESI], XMM3;//store current x_n_minus1 as x_n_minus2
					mulps	XMM2, XMM4;	//(b2/a0) * x_n_minus2
					addps	XMM0, XMM2;	//(b0/a0) * x_n + (b1/a0) * x_n_minus1 + (b2/a0) * x_n_minus2
					add		ESI, 16;	//offset ESI to a1a0
					movaps	XMM1, [ESI];//load a1a0
					add		ESI, 16;	//offset ESI to y_n_minus1
					movaps	XMM2, [ESI];//load y_n_minus1
					mulps	XMM1, XMM2;	//(a1/a0) * y_n_minus1
					subps	XMM0, XMM1;	//(b0/a0) * x_n + (b1/a0) * x_n_minus1 + (b2/a0) * x_n_minus2 - (a1/a0) * y_n_minus1
					add		ESI, 16;	//offset ESI to a2a0
					movaps	XMM1, [ESI];//load a2a0
					add		ESI, 16;	//offset ESI to y_n_minus2
					movaps	XMM3, [ESI];//load y_n_minus2
					movaps	[ESI], XMM2;//store y_n_minus1 as new y_n_minus2
					mulps	XMM1, XMM3;	//(a2/a0) * y_n_minus2
					subps	XMM0, XMM1;	//(b0/a0) * x_n + (b1/a0) * x_n_minus1 + (b2/a0) * x_n_minus2 - (a1/a0) * y_n_minus1 - (a2/a0) * y_n_minus2
					sub		ESI, 48;	//set back pointer to  y_n_minus1
					movaps	[ESI], XMM0;//store y_n as y_n_minus1
					movaps	[EDI], XMM0;//store y_n as output
					add		EDI, 16;
					add		ESI, 48;
					dec		ECX;
					cmp		ECX, 0;
					jne		iirLoop;
				}
				x_nptr += 32;
				y_nptr += 32;
			}
		}
	}
}

