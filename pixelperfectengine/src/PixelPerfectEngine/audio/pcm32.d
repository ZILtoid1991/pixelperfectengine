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
import PixelPerfectEngine.system.binarySearchTree;

static if(USE_INTEL_INTRINSICS)
	import inteli.emmintrin;

import libPCM.codecs;
import libPCM.common;
import libPCM.file;
import libPCM.types;

import std.bitmanip;
import std.math;
import std.container.array;

import core.stdc.stdlib;
import core.stdc.string;

/**
 * Sampling synthesizer implementation. Has per channel FIR (1024 stage) and IIR (low-pass) filters, and four stereo outputs.
 */
public class PCM32 : AbstractPPEFX{
	enum LFO_TABLE_LENGTH = 256;
	enum FIR_TABLE_LENGTH = 1024;
	enum WHOLE_STEP_FORWARD = 1_048_576;
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
		ubyte firTypeL;		///Selects the FIR filter type for the left channel
		ubyte firTypeR;		///Selects the FIR filter type for the right channel
		ubyte iirType;		///Selects the IIR filter type
		ubyte lfoWave;		///Selects the LFO Waveform

		short firLevel;		///Sets the output level of the FIR filter, negative values invert the signal
		short firFeedback;	///Sets the feedback level of the FIR filter, negative values invert the signal

		float _Q;			///Mostly Q
		float f0;			///Frequency center of the filtering
		float iirDryLevel;	///Sets the level of the dry signal
		float iirWetLevel;	///Sets the level of the wet signal
		float lfoFreq;		///Sets the LFO frequency

		float[4] sendLevels;	///1: Main left; 2: Main right; 3: Aux left; 4: Aux right

		ControlData firLevelCtrl;		///Sets the modifiers for the firLevel (fixValue controls don't work)
		ControlData firFeedbackCtrl;	///Sets the modifiers for the firFeedback (fixValue controls don't work)

		ControlData sendLevelLCtrl;		///Modifies all left channel outputs
		ControlData sendLevelRCtrl;		///Modifies all right channel outputs

		ControlData _QCtrl;
		ControlData f0Ctrl;
		ControlData iirDryLevelCtrl;
		ControlData iirWetLevelCtrl;
		ControlData lfoFreqCtrl;
		/*
		 * Routing policies:
		 * enableIIR: Enables IIR filter
		 * enableFIR: Enables FIR filter
		 * serialFIR: If true, it runs the two FIR filters in serial [L -> R]
		 * monoFIR: If true, only the left channel will be used, and serialFIR is ignored
		 * routeFIRintoIIR: Reverses the routing of the two filters
		 *
		 * Legato:
		 * resetSample: Disables sample resetting if keyOn command received without keyoff
		 * resetEGA: Disables resetting of envelope generator A
		 * resetEGB: Disables resetting of envelope generator B
		 * resetLFO: Disables resetting of LFO
		 *
		 * Other:
		 * loopOnKeyOff: Enables the use of release stages of the LFO to control the runtime after key off commands.
		 * Recommended for wavetables.
		 */
		mixin(bitfields!(
			bool,"enableIIR",1,
			bool,"enableFIR",1,
			bool,"serialFIR",1,
			bool,"monoFIR",1,
			bool,"routeFIRintoIIR",1,

			bool,"resetSample",1,
			bool,"resetEGA",1,
			bool,"resetEGB",1,
			bool,"resetLFO",1,
			bool,"loopOnKeyOff",1,

			ushort,"reserved",6,
		));
	}
	/**
	 * Preset data.
	 * Stores data on how to handle instrument samples.
	 * Important: fromX are always the lower values. Overlapping values are not supported.
	 */
	public struct ChannelPresetSamples{
		///Sets certain properties of the sample
		enum Flags : ushort{
			///Enables sample looping
			enableLoop = 0b0000_0000_0000_0001,
			///Changes looping from one-way to ping-pong (doesn't work with most differental codecs)
			pingPongLoop = 0b0000_0000_0000_0010,
			///Disables pitch changes on different notes.
			isPercussive = 0b0000_0000_0000_0100,
			///Plays only a slice from the sample (doesn't work with most differental codecs)
			slice = 0b0000_0000_0000_1000,
		}
		uint sampleSelect;	///Selects the sample that will be used
		uint loopFrom;
		uint loopTo;
		float midFreq;
		ushort loopFlags;	///See enum Flags for options
		ushort midNote;
		ushort fromNote = 0x0FFF;
		ushort toNote = 0x0FFF + 0x7F;
		/+ushort fromVelocity;
		ushort toVelocity = ushort.max;
		ushort fromExpressiveVal;
		ushort toExpressiveVal = ushort.max;+/
		@nogc @property bool isPercussive(){
			return (loopFlags & Flags.isPercussive) != 0;
		}
		@nogc @property bool isLooping(){
			return (loopFlags & Flags.isPercussive) != 0;
		}
		@nogc @property bool pingPongLoop(){
			return (loopFlags & Flags.isPercussive) != 0;
		}
		/**
		 * Used mainly for ordering them in a BSTree.
		 */
		@nogc int opCmp(ChannelPresetSamples rhs){
			if(this.toNote < rhs.fromNote)
				return -1;
			else if(this.fromNote > rhs.toNote)
				return 1;
			else
				return 0;
		}
		/**
		 * Range lookup.
		 */
		@nogc int opCmp(ushort rhs){
			if(this.fromNote > rhs){//hit from lower range
				if(this.toNote < rhs){//hit from upper range
					return 0;
				}else{//overshoot
					return 1;
				}
			}else{//undershoot
				return -1;
			}
		}
		/**
		 * Equals function for other ChannelPresetSamples.
		 */
		@nogc bool opEquals(ChannelPresetSamples b) {
			return opCmp(b) == 0;
		}
		/**
		 * Equals function for ushort by note.
		 */
		@nogc bool opEquals(ushort b) {
			return opCmp(b) == 0;
		}
	}
	/**
	 * Stores information regarding to samples.
	 * IMPORTANT: Always call unloadSample for unloading samples from the memory.
	 */
	public struct Sample{
		size_t length;		///Length of sample
		ubyte* dataPtr;		///Points to the first sample of the stream
		CodecType codec;	///Selects the codec type
		ushort flags;		///Mainly for 32bit alignment, placeholder for future flags (stereo sample support?)
		float sampleFreq;	///Overrides the *.pcm file's sampling frequency
		this(size_t length, ubyte* dataPtr, CodecType codec){
			this.length = length;
			this.dataPtr = dataPtr;
			this.codec = codec;
		}
		/**
		 * Unloads the sample from memory.
		 */
		@nogc void unloadSample(){
			length = 0;
			free(dataPtr);
		}
	}
	/**
	 * Stores sample preset data for editing and storing purposes.
	 */
	public struct SamplePreset{
		char[32] name;		///Must match file source name without the .pcm extension in the sample pool(s) being used
		float freq;
		uint id;
	}
	/**
	 * Stores data on LFO or FIR for editing and storing purposes.
	 */
	public struct FXSamplePreset{
		char[32] name;		///Must match file source name without the .pcm extension in the sample pool(s) being used
		ubyte id;
		ubyte[3] unused;
	}
	/**
	 * Stores instrument preset data for editing and storing purposes.
	 */
	public struct InstrumentPreset{
		char[32] name;
		ushort id;
		ushort egaStages;
		ushort egbStages;
		ushort sampleLayers;
	}
	/**
	 * Stores global settings of the instrument.
	 */
	public struct GlobalSettings{
		float tuning = 440.0;		///base tuning
		///Used for channel masking. The channel indicated by this value is used as the first channel that won't be ignored.
		///Last channel not to be ignored is baseChannel + 31
		ushort baseChannel;
		/*
		 * Bitfields:
		 * enablePassthruCH29 - 32: Enables the channels to be used for external effecting purposes.
		 * Note commands can be used to control the filters if needed.
		 * Input for CH29 is PPEFXinput 0
		 * Input for CH30 is PPEFXinput 1
		 * Input for CH31 is PPEFXinput 2
		 * Input for CH32 is PPEFXinput 3
		 */
		mixin(bitfields!(
			bool,"enablePassthruCH29",1,
			bool,"enablePassthruCH30",1,
			bool,"enablePassthruCH31",1,
			bool,"enablePassthruCH32",1,
			ushort,"unused",12,
		));
	}
	/**
	 * RIFF header to identify preset data in banks.
	 */
	enum RIFFID : char[4]{
		riffInitial = "RIFF",		///to initialize the RIFF format
		bankInitial = "BANK",		///currently unused
		globalSettings = "GLOB",	///global settings (eg. tunings, routing, channel masking)
		instrumentPreset = "INSP",	///indicates that the next chunk is an instrument preset. length = InstrumentPreset.sizeof + ChannelPresetMain.sizeof
		envGenA = "ENVA",			///indicates that there's envelope generator data for the current preset. length = EnvelopeStage.sizeof * egaStages
		envGenB = "ENVB",			///indicates that there's envelope generator data for the current preset. length = EnvelopeStage.sizeof * egbStages
		instrumentData = "INSD",	///indicates that the next chunk contains sample layer data for the current preset. length = ChannelPresetSamples.sizeof * sampleLayers
		samplePreset = "SLMP",		///indicates that the next chunk is a sample preset. length = SamplePreset * sizeof
		lfoPreset = "LFOP",			///indicates that the next chunk is an LFO preset. length = FXSamplePreset * sizeof
		fiResponse = "FIRS",		///indicates that the next chunk is an FIR preset. length = FXSamplePreset * sizeof
	}
	/**
	 * Stores data for a single channel.
	 */
	protected struct Channel{
		ChannelPresetMain preset;
		@nogc short function(ubyte*, DecoderWorkpad*) codec;
		uint loopfrom, loopto;	///describe a loop cycle between the two values for the current sample
		uint stepping;			///describes how much the sample should go forward, 1_048_576 equals a whole step
		ulong forward;			///current position
		Sample* sample;
		short*[3] intBuff;		///buffer for FIR-filters [0,1], output [2], IIR-filter output converted to int [3]
		CodecType codecType;
		DecoderWorkpad workpad, secWorkpad;
		ushort presetID;
		ushort note;
		ushort vel;
		ushort exprVal;
		float freq;
		float baseFreq;
		float pitchbend = 0f;
		float iirF0;
		float iir_q;
		float[4] sendLevels;
		EnvelopeGenerator envGenA;
		EnvelopeGenerator envGenB;
		FiniteImpulseResponseFilter!(FIR_TABLE_LENGTH)[2] firFilter;
		LowFreqOsc!(LFO_TABLE_LENGTH) lfo;
		//bool keyON;
		//bool isRunning;
		ushort arpeggiatorSpeed;	///ms between notes

		enum ArpMode : ubyte{
			off,
			ascending,
			descending,
			ascThenDesc,
		}
		mixin(bitfields!(
			bool,"keyON",1,
			bool,"isRunning",1,
			bool,"enableLooping",1,
			bool,"pingPongLoop",1,
			bool,"slice",1,
			ubyte,"arpMode",3,
			ubyte,"octaves",4,
			bool,"arpWay",1,
			ubyte,"nOfNotes",3,
		));
		ushort[4] arpeggiatorNotes;	///notes to arpeggiate
		ushort arpPos;
		ubyte curOctave, curNote;
		short output, firBuf0, firBuf1;				///Previous outputs
		short firLevel0, firLevel1, firFbk0, firFbk1;
	}

	static if(ARCH_INTEL_X86){
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
		protected float[32] x_n_minus1, x_n_minus2, y_n_minus1, y_n_minus2, b0a0, b1a0, b2a0, a1a0, a2a0;
	}
	protected BinarySearchTree!(ushort,EnvelopeStageList) envGenA;
	protected BinarySearchTree!(ushort,EnvelopeStageList) envGenB;
	protected BinarySearchTree!(ushort,ChannelPresetMain) presets;
	protected BinarySearchTree!(ushort,BinarySearchTree2!(ChannelPresetSamples)) sampleLayers;

	protected float*[32] y_n; ///Output
	protected float*[32] x_n; ///Input
	protected float[32] iirDryLevel, iirWetLevel;
	protected Channel[32] channels;
	protected float sampleRate;
	protected size_t frameLength, nOfFrames;
	protected BinarySearchTree!(ubyte, FiniteImpulseResponse!(1024)) finiteImpulseResponses;
	protected BinarySearchTree!(uint, Sample) samples;
	protected BinarySearchTree!(ubyte, ubyte[256]) lfoTables;

	//global parameters
	protected GlobalSettings globals;

	protected string samplePoolPath;	///Specifies the path for the sample pool
	/**
	 * Make sure that the string describes a valid path.
	 */
	public this(string samplePoolPath = "./audio/samples/"){
		this.samplePoolPath = samplePoolPath;
		this.globals.tuning = 440.0f;
	}
	public @nogc @property BinarySearchTree!(ushort,ChannelPresetMain)* presetPtr(){
		return &presets;
	}
	public @nogc @property BinarySearchTree!(ushort,EnvelopeStageList)* envGenAPtr(){
		return &envGenA;
	}
	public @nogc @property BinarySearchTree!(ushort,EnvelopeStageList)* envGenBPtr(){
		return &envGenB;
	}
	public @nogc @property BinarySearchTree!(ushort,BinarySearchTree2!(ChannelPresetSamples))* sampleLayersPtr(){
		return &sampleLayers;
	}
	protected @nogc void calculateIIR(){
		static if(USE_INTEL_INTRINSICS){
			//float* y_nptr = cast(float*)y_n.ptr;
			//float* x_nptr = cast(float*)x_n.ptr;
			float* vals = cast(float*)iirFiltersPtr;
			float* iirDryLevelPtr = iirDryLevel.ptr;
			float* iirWetLevelPtr = iirWetLevel.ptr;
			for(size_t i = frameLength ; i >= 0 ; i--){
				for(int j ; j < 8 ; j++){
					const int k = j << 2;
					__m128 workVal = _mm_load_ps(vals);//b0a0
					__m128 x_n0;// = [x_n[k][i],x_n[k+1][i],x_n[k+2][i],x_n[k+3][i]];
					x_n0[0] = x_n[k][i];
					x_n0[1] = x_n[k+1][i];
					x_n0[2] = x_n[k+2][i];
					x_n0[3] = x_n[k+3][i];
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
					//_mm_store_ps(y_nptr,y_n0);//store output in buffer
					y_n[k][i] = y_n0[0];
					y_n[k+1][i] = y_n0[1];
					y_n[k+2][i] = y_n0[2];
					y_n[k+3][i] = y_n0[3];
					vals += 4;
					//x_nptr += 4;
					//y_nptr += 4;
				}
				vals = cast(float*)iirFiltersPtr;
			}
		}else{
			float* y_nptr = cast(float*)y_n.ptr;
			float* x_nptr = cast(float*)x_n.ptr;
			for(int i = cast(int)frameLength ; i >= 0 ; i--){
				/+asm @nogc{
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
				y_nptr += 32;+/
			}
		}
	}
	public @nogc void refreshFilter(int ch, IIRFilterType type, float freq, float Q){

	}
	override public @nogc void render(float** inputBuffers, float** outputBuffers) { }
	/+override public @nogc void render(float** inputBuffers, float** outputBuffers) {
		float* mainL = outputBuffers[0], mainR = outputBuffers[1], auxL = outputBuffers[2], auxR = outputBuffers[3];
		float* ch29 = inputBuffers[0], ch30 = inputBuffers[1], ch31 = inputBuffers[2], ch32 = inputBuffers[3];
		for(int fr; fr < nOfFrames; fr++){
			int ch;
			for(; ch < 28; ch++){
				if(channels[ch].isRunning){
					for(int s; s < frameLength; s++){
						ulong prevForvard = channels[ch].forward;
						channels[ch].forward += channels[ch].stepping;
						while(prevForvard>>10 < channels[ch].forward>>10){
							channels[ch].output = channels[ch].codec(channels[ch].sample.dataPtr, &channels[ch].workpad);
							prevForvard += WHOLE_STEP_FORWARD;
							if(channels[ch].enableLooping){
								if(channels[ch].workpad.position == channels[ch].loopfrom){
									channels[ch].secWorkpad = channels[ch].workpad;
								}else if(channels[ch].workpad.position == channels[ch].loopto){
									channels[ch].workpad = channels[ch].secWorkpad;
								}
							}
						}
						if(channels[ch].sample.length <= channels[ch].workpad.position){
							channels[ch].isRunning = false;
							break;
						}
						channels[ch].intBuff[2][s] = channels[ch].output;
					}

					if(channels[ch].preset.enableFIR){
						if(channels[ch].preset.routeFIRintoIIR){
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
								}else{//parralel mixing due to channel limit
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
								}
							}else{
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
							mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
							mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
							mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
							mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
						}else{
							int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
							floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}else{
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}
							}else{
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}


					}else{
						int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}
					channels[ch].envGenA.step;
					channels[ch].envGenB.step;
					channels[ch].lfo.step;
				}
			}
			if(globals.enablePassthruCH29){
				if(channels[ch].preset.enableFIR){
					if(channels[ch].preset.routeFIRintoIIR){
						floatToInt16(ch29, channels[ch].intBuff[2], frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
							}else{//parralel mixing due to channel limit
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
						}else{
							int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
						}
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}else{
						//int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						memcpy(x_n[ch], ch29, frameLength * float.sizeof);
						floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}

								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}else{
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}else{
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
						}
					}
				}else{
					memcpy(x_n[ch], ch29, frameLength * float.sizeof);
					mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
					mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
					mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
					mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
				}
				channels[ch].envGenA.step;
				channels[ch].envGenB.step;
				channels[ch].lfo.step;
			}else{
				if(channels[ch].isRunning){
					for(int s; s < frameLength; s++){
						ulong prevForvard = channels[ch].forward;
						channels[ch].forward += channels[ch].stepping;
						while(prevForvard>>10 < channels[ch].forward>>10){
							channels[ch].output = channels[ch].codec(channels[ch].sample.dataPtr, &channels[ch].workpad);
							prevForvard += WHOLE_STEP_FORWARD;
							if(channels[ch].enableLooping){
								if(channels[ch].workpad.position == channels[ch].loopfrom){
									channels[ch].secWorkpad = channels[ch].workpad;
								}else if(channels[ch].workpad.position == channels[ch].loopto){
									channels[ch].workpad = channels[ch].secWorkpad;
								}
							}
						}
						if(channels[ch].sample.length <= channels[ch].workpad.position){
							channels[ch].isRunning = false;
							break;
						}
						channels[ch].intBuff[2][s] = channels[ch].output;
					}

					if(channels[ch].preset.enableFIR){
						if(channels[ch].preset.routeFIRintoIIR){
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
								}else{//parralel mixing due to channel limit
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
								}
							}else{
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
							mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
							mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
							mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
							mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
						}else{
							int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
							floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}else{
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}
							}else{
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}


					}else{
						int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}
					channels[ch].envGenA.step;
					channels[ch].envGenB.step;
					channels[ch].lfo.step;
				}
			}
			ch++;
			if(globals.enablePassthruCH30){
				if(channels[ch].preset.enableFIR){
					if(channels[ch].preset.routeFIRintoIIR){
						floatToInt16(ch29, channels[ch].intBuff[2], frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
							}else{//parralel mixing due to channel limit
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
						}else{
							int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
						}
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}else{
						//int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						memcpy(x_n[ch], ch29, frameLength * float.sizeof);
						floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}

								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}else{
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}else{
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
						}
					}
				}else{
					memcpy(x_n[ch], ch29, frameLength * float.sizeof);
					mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
					mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
					mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
					mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
				}
				channels[ch].envGenA.step;
				channels[ch].envGenB.step;
				channels[ch].lfo.step;
			}else{
				if(channels[ch].isRunning){
					for(int s; s < frameLength; s++){
						ulong prevForvard = channels[ch].forward;
						channels[ch].forward += channels[ch].stepping;
						while(prevForvard>>10 < channels[ch].forward>>10){
							channels[ch].output = channels[ch].codec(channels[ch].sample.dataPtr, &channels[ch].workpad);
							prevForvard += WHOLE_STEP_FORWARD;
							if(channels[ch].enableLooping){
								if(channels[ch].workpad.position == channels[ch].loopfrom){
									channels[ch].secWorkpad = channels[ch].workpad;
								}else if(channels[ch].workpad.position == channels[ch].loopto){
									channels[ch].workpad = channels[ch].secWorkpad;
								}
							}
						}
						if(channels[ch].sample.length <= channels[ch].workpad.position){
							channels[ch].isRunning = false;
							break;
						}
						channels[ch].intBuff[2][s] = channels[ch].output;
					}

					if(channels[ch].preset.enableFIR){
						if(channels[ch].preset.routeFIRintoIIR){
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
								}else{//parralel mixing due to channel limit
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
								}
							}else{
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
							mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
							mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
							mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
							mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
						}else{
							int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
							floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}else{
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}
							}else{
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}


					}else{
						int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}
					channels[ch].envGenA.step;
					channels[ch].envGenB.step;
					channels[ch].lfo.step;
				}
			}
			ch++;
			if(globals.enablePassthruCH31){
				if(channels[ch].preset.enableFIR){
					if(channels[ch].preset.routeFIRintoIIR){
						floatToInt16(ch29, channels[ch].intBuff[2], frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
							}else{//parralel mixing due to channel limit
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
						}else{
							int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
						}
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}else{
						//int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						memcpy(x_n[ch], ch29, frameLength * float.sizeof);
						floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}

								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}else{
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}else{
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
						}
					}
				}else{
					memcpy(x_n[ch], ch29, frameLength * float.sizeof);
					mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
					mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
					mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
					mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
				}
				channels[ch].envGenA.step;
				channels[ch].envGenB.step;
				channels[ch].lfo.step;
			}else{
				if(channels[ch].isRunning){
					for(int s; s < frameLength; s++){
						ulong prevForvard = channels[ch].forward;
						channels[ch].forward += channels[ch].stepping;
						while(prevForvard>>10 < channels[ch].forward>>10){
							channels[ch].output = channels[ch].codec(channels[ch].sample.dataPtr, &channels[ch].workpad);
							prevForvard += WHOLE_STEP_FORWARD;
							if(channels[ch].enableLooping){
								if(channels[ch].workpad.position == channels[ch].loopfrom){
									channels[ch].secWorkpad = channels[ch].workpad;
								}else if(channels[ch].workpad.position == channels[ch].loopto){
									channels[ch].workpad = channels[ch].secWorkpad;
								}
							}
						}
						if(channels[ch].sample.length <= channels[ch].workpad.position){
							channels[ch].isRunning = false;
							break;
						}
						channels[ch].intBuff[2][s] = channels[ch].output;
					}

					if(channels[ch].preset.enableFIR){
						if(channels[ch].preset.routeFIRintoIIR){
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
								}else{//parralel mixing due to channel limit
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
								}
							}else{
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
							mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
							mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
							mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
							mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
						}else{
							int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
							floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}else{
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}
							}else{
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}


					}else{
						int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}
					channels[ch].envGenA.step;
					channels[ch].envGenB.step;
					channels[ch].lfo.step;
				}
			}
			ch++;
			if(globals.enablePassthruCH32){
				if(channels[ch].preset.enableFIR){
					if(channels[ch].preset.routeFIRintoIIR){
						floatToInt16(ch29, channels[ch].intBuff[2], frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
							}else{//parralel mixing due to channel limit
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
						}else{
							int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
						}
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}else{
						//int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						memcpy(x_n[ch], ch29, frameLength * float.sizeof);
						floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
						for(int s; s < frameLength; s++){
							channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
									(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
							channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
						}
						if(!channels[ch].preset.monoFIR){
							if(channels[ch].preset.serialFIR){
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}

								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}else{
								for(int s; s < frameLength; s++){
									channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
											(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
									channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
								}
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}else{
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
							convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
						}
					}
				}else{
					memcpy(x_n[ch], ch29, frameLength * float.sizeof);
					mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
					mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
					mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
					mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
				}
				channels[ch].envGenA.step;
				channels[ch].envGenB.step;
				channels[ch].lfo.step;
			}else{
				if(channels[ch].isRunning){
					for(int s; s < frameLength; s++){
						ulong prevForvard = channels[ch].forward;
						channels[ch].forward += channels[ch].stepping;
						while(prevForvard>>10 < channels[ch].forward>>10){
							channels[ch].output = channels[ch].codec(channels[ch].sample.dataPtr, &channels[ch].workpad);
							prevForvard += WHOLE_STEP_FORWARD;
							if(channels[ch].enableLooping){
								if(channels[ch].workpad.position == channels[ch].loopfrom){
									channels[ch].secWorkpad = channels[ch].workpad;
								}else if(channels[ch].workpad.position == channels[ch].loopto){
									channels[ch].workpad = channels[ch].secWorkpad;
								}
							}
						}
						if(channels[ch].sample.length <= channels[ch].workpad.position){
							channels[ch].isRunning = false;
							break;
						}
						channels[ch].intBuff[2][s] = channels[ch].output;
					}

					if(channels[ch].preset.enableFIR){
						if(channels[ch].preset.routeFIRintoIIR){
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[1],x_n[ch],frameLength);
								}else{//parralel mixing due to channel limit
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[0][s] += cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
								}
							}else{
								int16ToFloat(channels[ch].intBuff[0],x_n[ch],frameLength);
							}
							mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
							mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
							mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
							mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
						}else{
							int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
							floatToInt16(y_n[ch],channels[ch].intBuff[2],frameLength);
							for(int s; s < frameLength; s++){
								channels[ch].firBuf0 = cast(short)channels[ch].firFilter[0].calculate(cast(short)(channels[ch].intBuff[2][s] +
										(channels[ch].firBuf0 * channels[ch].firFbk0)>>16));
								channels[ch].intBuff[0][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel0);
							}
							if(!channels[ch].preset.monoFIR){
								if(channels[ch].preset.serialFIR){
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[0][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf0 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}else{
									for(int s; s < frameLength; s++){
										channels[ch].firBuf1 = cast(short)channels[ch].firFilter[1].calculate(cast(short)(channels[ch].intBuff[2][s] +
												(channels[ch].firBuf1 * channels[ch].firFbk1)>>16));
										channels[ch].intBuff[1][s] = cast(short)(channels[ch].firBuf1 * channels[ch].firLevel1);
									}
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], mainR, frameLength, channels[ch].sendLevels[1]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
									convAndMixStreamIntoTarget(channels[ch].intBuff[1], auxR, frameLength, channels[ch].sendLevels[3]);
								}
							}else{
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainL, frameLength, channels[ch].sendLevels[0]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], mainR, frameLength, channels[ch].sendLevels[1]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxL, frameLength, channels[ch].sendLevels[2]);
								convAndMixStreamIntoTarget(channels[ch].intBuff[0], auxR, frameLength, channels[ch].sendLevels[3]);
							}
						}


					}else{
						int16ToFloat(channels[ch].intBuff[2],x_n[ch],frameLength);
						mixStreamIntoTarget(y_n[ch], mainL, frameLength, channels[ch].sendLevels[0]);
						mixStreamIntoTarget(y_n[ch], mainR, frameLength, channels[ch].sendLevels[1]);
						mixStreamIntoTarget(y_n[ch], auxL, frameLength, channels[ch].sendLevels[2]);
						mixStreamIntoTarget(y_n[ch], auxR, frameLength, channels[ch].sendLevels[3]);
					}
					channels[ch].envGenA.step;
					channels[ch].envGenB.step;
					channels[ch].lfo.step;
				}
			}
			//update arpeggiators on all channels
			updateArppegiators();
			calculateIIR();
		}

	}+/
	protected @nogc void updateArppegiators(){
		for(int ch; ch < 32; ch++){
			if(channels[ch].arpMode != Channel.ArpMode.off){
				if(channels[ch].arpPos++ >= channels[ch].arpeggiatorSpeed){
					channels[ch].arpPos = 0;
					final switch(channels[ch].arpMode){
						case Channel.ArpMode.ascending:
							if(channels[ch].arpPos++ == channels[ch].nOfNotes){
								channels[ch].arpPos = 0;
								if(channels[ch].curOctave++ == channels[ch].octaves){
									channels[ch].curOctave = 0;
								}
							}
							break;
						case Channel.ArpMode.descending:
							if(channels[ch].arpPos-- == 0){
								channels[ch].arpPos = channels[ch].nOfNotes;
								if(channels[ch].curOctave-- == 0){
									channels[ch].curOctave = channels[ch].octaves;
								}
							}
							break;
						case Channel.ArpMode.ascThenDesc:
							if(channels[ch].arpWay){
								if(channels[ch].arpPos++ == channels[ch].nOfNotes){
									channels[ch].arpPos = 0;
									if(channels[ch].curOctave++ == channels[ch].octaves){
										channels[ch].curOctave = 0;
										channels[ch].arpWay = false;
									}
								}
							}else{
								if(channels[ch].arpPos-- == 0){
									channels[ch].arpPos = channels[ch].nOfNotes;
									if(channels[ch].curOctave-- == 0){
										channels[ch].curOctave = channels[ch].octaves;
										channels[ch].arpWay = true;
									}
								}
							}
							break;
					}
					keyOn(cast(ubyte)ch, cast(ushort)(channels[ch].arpeggiatorNotes[channels[ch].arpPos] + channels[ch].curOctave * 12),
							channels[ch].vel, channels[ch].exprVal);
				}
			}
		}
	}
	override public @nogc void receiveMICPCommand(MICPCommand cmd){
		cmd.channel = cast(ushort)(cmd.channel - globals.baseChannel);
		switch(cmd.command){
			case MICPCommandList.KeyOn:
				keyOn(cast(ubyte)cmd.channel, cmd.val0, cmd.vals[0], cmd.vals[1]);
				break;
			case MICPCommandList.KeyOff:
				keyOff(cast(ubyte)cmd.channel, cmd.val0, cmd.vals[0], cmd.vals[1]);
				break;
			case MICPCommandList.ParamEdit:
				break;
			case MICPCommandList.ParamEditFP:
				break;
			default:
				break;
		}
	}
	/**
	 * Changes the preset of a given channel.
	 * ch must be between 0 and 31.
	 */
	public @nogc void changePreset(ubyte ch, ushort preset){
		channels[ch].presetID = preset;
		channels[ch].envGenA.reset;
		channels[ch].envGenA.stages = envGenA.getPtr(preset);
		channels[ch].envGenB.reset;
		channels[ch].envGenB.stages = envGenB.getPtr(preset);
		channels[ch].preset = presets[preset];
		channels[ch].lfo.reset;
		channels[ch].lfo.table = lfoTables.getPtr(channels[ch].preset.lfoWave);
		channels[ch].presetID = preset;
		channels[ch].firFilter[0].impulseResponse = finiteImpulseResponses.getPtr(channels[ch].preset.firTypeL);
		channels[ch].firFilter[1].impulseResponse = finiteImpulseResponses.getPtr(channels[ch].preset.firTypeR);

	}
	/**
	 * Sets a key-on command on the selected channel with the given note, velocity, and expressive value.
	 */
	public @nogc void keyOn(ubyte ch, ushort note, ushort vel, ushort exprVal){
		channels[ch].keyON = true;
		channels[ch].isRunning = true;
		channels[ch].note = note;
		channels[ch].vel = vel;
		channels[ch].exprVal = exprVal;
		channels[ch].forward = 0;
		//get sample to play
		ChannelPresetSamples cps = sampleLayers[channels[ch].presetID].lookup(note);
		channels[ch].sample = samples.getPtr(cps.sampleSelect);
		//calculate stepping
		if(cps.isPercussive){//if percussive, ignore pitch change except for the pitch bend commands
			channels[ch].baseFreq = cps.midFreq;
			channels[ch].freq = bendFreqByPitch(channels[ch].pitchbend, channels[ch].baseFreq);
			channels[ch].stepping = calculateStepping(channels[ch].freq);
		}else{//calculate note frequency with pitchbend
			const float delta_note = cast(float)note - cast(float)cps.midNote;
			channels[ch].baseFreq = bendFreqByPitch(delta_note, cps.midFreq);
			channels[ch].freq = bendFreqByPitch(channels[ch].pitchbend, channels[ch].baseFreq);
			channels[ch].stepping = calculateStepping(channels[ch].freq);
		}
		channels[ch].enableLooping = cps.isLooping;
		channels[ch].pingPongLoop = cps.pingPongLoop;
		if(channels[ch].preset.resetEGA){
			channels[ch].envGenA.setKeyOn;
		}
		if(channels[ch].preset.resetEGB){
			channels[ch].envGenB.setKeyOn;
		}
		if(channels[ch].preset.resetLFO){
			channels[ch].lfo.reset;
		}

	}
	/**
	 * Sets a key-off command on the selected channel with the given note, velocity, and expressive value.
	 */
	public @nogc void keyOff(ubyte ch, ushort note, ushort vel, ushort exprVal){
		channels[ch].keyON = false;
		channels[ch].note = note;
		channels[ch].vel = vel;
		channels[ch].exprVal = exprVal;
		channels[ch].envGenA.setKeyOff;
		channels[ch].envGenB.setKeyOff;
	}
	/**
	 * Programs a note into the channel's sequencer.
	 * If exprVal not 0, it sets which note has to be rewritten, otherwise it adds a new note to the sequencer.
	 */
	public @nogc void prgKeyOn(ubyte ch, ushort note, ushort vel, ushort exprVal){
		if(exprVal){
			exprVal--;
			exprVal &= 3;
			channels[ch].arpeggiatorNotes[exprVal] = note;
		}else{
			if(channels[ch].nOfNotes < 3){
				channels[ch].arpeggiatorNotes[channels[ch].nOfNotes] = note;
				channels[ch].nOfNotes = cast(ubyte)(channels[ch].nOfNotes + 1);
			}
		}
	}
	/**
	 * Removes a note from the channel's sequencer.
	 * If note not 0, it removes the note from the list if there's an equal of it.
	 * If exprVal not 0, it removes the given note.
	 */
	public @nogc void prgKeyOff(ubyte ch, ushort note, ushort vel, ushort exprVal){
		if(note){
			for(int i; i < 4; i++)
				if(channels[ch].arpeggiatorNotes[exprVal] == note)
					exprVal = cast(ushort)(i+1);
		}
		if(exprVal){
			exprVal--;
			exprVal &= 3;
			channels[ch].arpeggiatorNotes[exprVal] = 0;
			for(; exprVal < 3; exprVal++)
				channels[ch].arpeggiatorNotes[exprVal] = channels[ch].arpeggiatorNotes[exprVal + 1];

			if(channels[ch].nOfNotes)
				channels[ch].nOfNotes = cast(ubyte)(channels[ch].nOfNotes - 1);
		}else{
			if(channels[ch].nOfNotes > 0){
				channels[ch].arpeggiatorNotes[channels[ch].nOfNotes] = 0;
				channels[ch].nOfNotes = cast(ubyte)(channels[ch].nOfNotes - 1);
			}
		}

	}
	/**
	 * Calculates the length of the stepping for each sample.
	 * Uses double precision to ensure precision.
	 */
	protected @nogc uint calculateStepping(float freq){
		return cast(uint)((cast(double)freq / cast(double)sampleRate) * cast(double)WHOLE_STEP_FORWARD);
	}
	override public @nogc int setRenderParams(float samplerate, size_t framelength, size_t nOfFrames){
		this.sampleRate = samplerate;
		this.frameLength = framelength;
		this.nOfFrames = nOfFrames;
		return 0;
	}
	/**
	 * Loads a bank into the synthesizer, also loads samples on the way from the selected sample pool.
	 * For the latter, it'll be able to use compression through lzbacon's datapak file format (default path for
	 * that is ./audio/samplepool.dpk), otherwise a folder with uncompressed data is used (default path for that
	 * is ./audio/samplepool/).
	 */
	override public void loadConfig(ref void[] data){
		import PixelPerfectEngine.system.file : RIFFHeader;
		import std.string : toStringz;
		size_t pos;
		bool riffHeaderFound, envGenAFound, envGenBFound, cpsFound;
		InstrumentPreset currentInstr;
		while(data.length < pos){
			RIFFHeader header = *cast(RIFFHeader*)(data.ptr + pos);
			pos += RIFFHeader.sizeof;
			switch(header.data){
				case RIFFID.riffInitial:
					riffHeaderFound = true;
					break;
				case RIFFID.instrumentPreset:
					envGenAFound = false;
					envGenBFound = false;
					cpsFound = false;
					currentInstr = *cast(InstrumentPreset*)(data.ptr + pos);
					pos += InstrumentPreset.sizeof;
					presets[currentInstr.id] = *cast(ChannelPresetMain*)(data.ptr + pos);
					pos += ChannelPresetMain.sizeof;
					break;
				case RIFFID.envGenA:
					if(!envGenAFound){
						envGenAFound = true;
						EnvelopeStageList ega;
						ega.reserve(currentInstr.egaStages);
						for(int i ; i < currentInstr.egaStages ; i++){
							ega.insertBack(*cast(EnvelopeStage*)(data.ptr + pos));
							pos += EnvelopeStage.sizeof;
						}
						envGenA[currentInstr.id] = ega;
					}
					break;
				case RIFFID.envGenB:
					if(!envGenBFound){
						envGenBFound = true;
						EnvelopeStageList egb;
						egb.reserve(currentInstr.egbStages);
						for(int i ; i < currentInstr.egbStages ; i++){
							egb.insertBack(*cast(EnvelopeStage*)(data.ptr + pos));
							pos += EnvelopeStage.sizeof;
						}
						envGenB[currentInstr.id] = egb;
					}
					break;
				case RIFFID.instrumentData:
					if(!envGenBFound){
						cpsFound = true;
						for(int i ; i < currentInstr.sampleLayers ; i++){
							sampleLayers[currentInstr.id].add(*cast(ChannelPresetSamples*)(data.ptr + pos));
							pos += ChannelPresetSamples.sizeof;
						}
					}
					break;
				/*case RIFFID.instrumentPreset:
					presets[currentInstr.id] = *cast(ChannelPresetMain*)(data.ptr + pos);
					pos += ChannelPresetMain.sizeof;
					break;*/
				case RIFFID.samplePreset:
					SamplePreset slmp = *cast(SamplePreset*)(data.ptr + pos);
					pos += SamplePreset.sizeof;
					string filename = samplePoolPath;
					foreach(c ; slmp.name){
						if(c){
							filename ~= c;
						}else{
							break;
						}
					}
					filename ~= ".pcm";
					PCMFile file = loadPCMFile(toStringz(filename));
					//sampleSrc ~= file.data;
					Sample s;
					s.codec = file.data.codecType;
					s.sampleFreq = slmp.freq;
					s.length = file.header.length;
					s.dataPtr = cast(ubyte*)malloc(file.data.data.length);
					memcpy(s.dataPtr, file.data.data.ptr, file.data.data.length);
					file.destroy;
					samples[slmp.id] = s;
					break;
				case RIFFID.fiResponse:
					FXSamplePreset slmp = *cast(FXSamplePreset*)(data.ptr + pos);
					pos += FXSamplePreset.sizeof;
					string filename = samplePoolPath;
					foreach(c ; slmp.name){
						if(c){
							filename ~= c;
						}else{
							break;
						}
					}
					filename ~= ".pcm";
					PCMFile file = loadPCMFile(toStringz(filename));
					FiniteImpulseResponse!(FIR_TABLE_LENGTH) fir;
					memcpy(fir.vals.ptr, file.data.data.ptr, FIR_TABLE_LENGTH);
					file.destroy;
					finiteImpulseResponses[slmp.id] = fir;
					break;
				case RIFFID.lfoPreset:
					FXSamplePreset slmp = *cast(FXSamplePreset*)(data.ptr + pos);
					pos += FXSamplePreset.sizeof;
					string filename = samplePoolPath;
					foreach(c ; slmp.name){
						if(c){
							filename ~= c;
						}else{
							break;
						}
					}
					filename ~= ".pcm";
					PCMFile file = loadPCMFile(toStringz(filename));
					ubyte[LFO_TABLE_LENGTH] table;
					memcpy(table.ptr, file.data.data.ptr, FIR_TABLE_LENGTH);
					file.destroy;
					lfoTables[slmp.id] = table;
					break;
				case RIFFID.globalSettings:
					globals = *cast(GlobalSettings*)(data.ptr + pos);
					pos += GlobalSettings.sizeof;
					break;
				default:
					throw new Exception("Invalid data error!");
			}
		}
	}
	/**
	 *Not supported currently
	 */
	override public ref void[] saveConfig(){
		throw new Exception("Unimplemented feature!");
	}
}

