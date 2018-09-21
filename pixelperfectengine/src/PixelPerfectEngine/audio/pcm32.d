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

import PixelPerfectEngine.system.platform;

static if(USE_INTEL_INTRINSICS)
	import inteli.emmintrin;

import libPCM.codecs;
import libPCM.common;

import std.bitmanip;
import std.math;

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
	 * Control data.
	 * Bitfield:
	 * <ul>
	 * <li>cSource: Enables input for controlling parameters with key command parameters</li>
	 * <li>damping: Sets per-octave dampening of the value</li>
	 * <li>invertCS: Inverts Velocity and ExpressiveVal control sources</li>
	 * <li>modifyEG: Modifies the output levels of the envelope generators by the control source</li>
	 * <li>envGenA: Enables envelope generator A to modify this parameter</li>
	 * <li>invertEGA: Inverts the output of the envelope generator A</li>
	 * <li>envGenB: Enables envelope generator A to modify this parameter</li>
	 * <li>invertEGB: Inverts the output of the envelope generator A</li>
	 * <li>fixValue: Toggles the role of the fix value: sets a fix value if true, sets the ratio of the modifiers if false</li>
	 * <li>lfo: Toggles the LFO</li>
	 * <li>reserved: Unused, might have some role in the future</li>
	 * </ul>
	 */
	public struct ControlData{
		mixin(bitfields!(
			ubyte, "cSource", 2,
			ubyte, "damping", 2,
			bool, "invertCS", 1,
			bool, "modifyEG", 1,
			bool, "envGenA", 1,
			bool, "invertEGA", 1,
			bool, "envGenB", 1,
			bool, "invertEGB", 1,
			bool, "fixValue", 1,
			bool, "lfo", 1,
			ubyte, "reserved", 4,
		));
	}
	/**
	 * Defines the type of IIR filter
	 */
	public enum IIRFilterType : ubyte{
		Bypass			=	0,
		LPF				=	1,
		HPF				=	2,
		BPF				=	3,
	}
	/**
	 * Per-octave dampening
	 */
	public enum Dampening : ubyte{
		DB00			=	0,	///No dampening
		DB15			=	1,	///1.5db dampening
		DB30			=	2,	///3.0db dampening
		DB60			=	3,	///6.0db dampening
	}
	/**
	 * Preset data.
	 * Does not store the data regarding instrument samples.
	 */
	public struct ChannelPresetMain{
		ushort firType;		///Selects the FIR filter type
		ubyte iirType;		///Selects the IIR filter type
		ubyte lfoWave;		///Selects the LFO Waveform

		short firLevel;		///Sets the output level of the FIR filter, negative values invert the signal
		short firFeedback;	///Sets the feedback level of the FIR filter, negative values invert the signal

		float _Q;			///Mostly Q
		float f0;			///Frequency center of the filtering
		float iirDryLevel;	///Sets the level of the dry signal
		float iirWetLevel;	///Sets the level of the wet signal
		float lfoFreq;		///Sets the LFO frequency

		float4 sendLevels;	///1: Main left; 2: Main right; 3: Aux left; 4: Aux right

		ControlData firLevelCtrl;		///Sets the modifiers for the firLevel (fixValue controls don't work)
		ControlData firFeedbackCtrl;	///Sets the modifiers for the firFeedback (fixValue controls don't work)

		ControlData sendLevelLCtrl;
		ControlData sendLevelRCtrl;

		ControlData _QCtrl;
		ControlData f0Ctrl;
		ControlData iirDryLevelCtrl;
		ControlData iirWetLevelCtrl;
		ControlData lfoFreqCtrl;
		/*
		 * Routing policies:
		 * enableIIR: Enables IIR filter
		 * enableFIR: Enables FIR filter
		 * routeFIRintoIIR: Reverses the routing of the two filters
		 *
		 * Legato:
		 * retrigSample: Enables sample retriggering if keyOn command received without keyoff
		 * retrigEGA: Enables retriggering of envelope generator A
		 * retrigEGB: Enables retriggering of envelope generator B
		 */
		mixin(bitfields!(
			bool,"enableIIR",1,
			bool,"enableFIR",1,
			bool,"routeFIRintoIIR",1,
			bool,"retrigSample",1
			bool,"retrigEGA",1
			bool,"retrigEGB",1
			/*bool,"loop",1
			bool,"pingpong",1*/
			ushort,"reserved",8+2,
		));
	}
	/**
	 * Preset data.
	 * Stores data on how to handle instrument samples.
	 */
	/**
	 * Stores data for a single channel.
	 */
	protected struct Channel{
		CommonDecoderFuncPtr codec;
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
		static if(USE_INTEL_INTRINSICS){
			/**
			 * Contains IIR related registers in order for use in SSE2 applications
			 */
			protected struct IIRFilterBuff{
				__m128 b0a0;
				//__m128 x_n;
				__m128 b1a0;
				__m128 x_n_minus1;
				__m128 b2a0;
				__m128 x_n_minus2;
				__m128 a1a0;
				__m128 y_n_minus1;
				__m128 a2a0;
				__m128 y_n_minus2;
				//__m128 y_n;
			}
		}else{
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
		}
		IIRFilterBuff[8] iirFilters;
		void* iirFiltersPtr;
	}else{
		float[32] x_n_minus1, x_n_minus2, y_n_minus1, y_n_minus2, b0a0, b1a0, b2a0, a1a0, a2a0;
	}
	float[32][] y_n, x_n;
	float[32] iirDryLevel, iirWetLevel;
	protected float sampleRate;
	protected size_t frameLength, nOfFrames;

	protected @nogc void calculateIIR(){
		static if(USE_INTEL_INTRINSICS){
			float* y_nptr = cast(float*)y_n.ptr;
			float* x_nptr = cast(float*)x_n.ptr;
			float* vals = cast(float*)iirFiltersPtr;
			float* iirDryLevelPtr = iirDryLevel.ptr;
			float* iirWetLevelPtr = iirWetLevel.ptr;
			for(int i = frameLength * bufferLength ; i >= 0 ; i--){
				for(int j ; j < 8 ; j++){
					__m128 workVal = _mm_load_ps(vals);//b0a0
					__m128 x_n0 = _mm_load_ps(x_nptr);//x_n0
					__m128 y_n0;//output
					y_n0 = workVal * x_n0;//(b0/a0)*x_n0
					vals += 4;
					workVal = _mm_load_ps(vals);//b1a0
					vals += 4;
					__m128 x_n1 = _mm_load_ps(vals);//x_n1
					_mm_store_ps(vals,x_n0);//store current x_n0 as x_n1
					y_n0 += x_n1 * workVal;//(b0/a0)*x_n0 + (b1/a0)*x_n1
					vals += 4;
					workVal = _mm_load_ps(vals);//b2a0
					vals += 4;
					const __m128 x_n2 = _mm_load_ps(vals);//x_n2
					_mm_store_ps(vals,x_n1);//store current x_n1 as x_n2
					y_n0 += x_n2 * workVal;//(b0/a0)*x_n0 + (b1/a0)*x_n1 + (b2/a0)*x_n2
					vals += 4;
					workVal = _mm_load_ps(vals);//a1a0
					vals += 4;
					__m128 y_n1 = _mm_load_ps(vals);//y_n1
					float* vals_y_n0 = vals;//store current position for storing the new output
					y_n0 -= y_n1 * workVal;//(b0/a0)*x_n0 + (b1/a0)*x_n1 + (b2/a0)*x_n2 - (a1/a0)*x_n2
					vals += 4;
					workVal = _mm_load_ps(vals);//a2a0
					vals += 4;
					const __m128 y_n2 = _mm_load_ps(vals);//y_n2 (I know, the variable has a different name)
					_mm_store_ps(vals,y_n1);//store current y_n1 as y_n2
					y_n0 -= y_n2 * workVal;//(b0/a0)*x_n0 + (b1/a0)*x_n1 + (b2/a0)*x_n2 - (a1/a0)*x_n2
					_mm_store_ps(vals_y_n0,y_n0);//store current y_n0 as y_n1
					//calculate mixing
					y_n0 = y_n0 * _mm_load_ps(iirWetLevelPtr) + x_n0 * _mm_load_ps(iirDryLevelPtr);
					_mm_store_ps(y_nptr,y_n0);//store output in buffer
					vals += 4;
					x_nptr += 4;
					y_nptr += 4;
				}
				vals = cast(float*)iirFiltersPtr;
			}
		}else{
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
	public @nogc void refreshFilter(int ch, IIRFilterType type, float freq, float Q){

	}
	public @nogc void receiveMICPCommand(MICPCommand cmd){
		switch(cmd.command){
			case MICPCommandList.KeyOn:
				break;
			case MICPCommandList.KeyOff:
				break;
			case MICPCommandList.ParamEdit:
				break;
			case MICPCommandList.ParamEditFP:
				break;
		}
	}
	public @nogc int setRenderParams(float samplerate, size_t framelength, size_t nOfFrames){
		this.sampleRate = samplerate;
		this.frameLength = framelength;
		this.nOfFrames = nOfFrames;
	}
}

