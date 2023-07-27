module pixelperfectengine.audio.modules.delaylines;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.osc;
import pixelperfectengine.audio.base.filter;
import pixelperfectengine.system.etc : isPowerOf2;

import inteli.emmintrin;

import midi2.types.structs;
import midi2.types.enums;

import collections.treemap;

import std.bitmanip : bitfields;
import std.math;

/**
 * Implements a configurable delay line device, that can be used to create various time-based effects.
 * It contains:
 * * two delay lines
 * * four taps per delay line
 * * a short 8 element FIR per tap
 * * 4 filters per tap (3 with mix amount + 1 for feedback)
 * * 4 LFO globally
 * The module is controllable via MIDI CC commands.
 */
public class DelayLines : AudioModule {
	shared static this () {
		import std.conv : to;
		for (uint i ; i < 8 ; i++) {
			for (uint j ; j < 16 ; j++) {
				SET_VALS ~= MValue(MValueType.Float, (i<<7) | j, "Tap" ~ i.to!string ~ "_FIR" ~ j.to!string);
			}
			
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (16), "Tap" ~ i.to!string ~ "_OutputL");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (17), "Tap" ~ i.to!string ~ "_OutputR");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (18), "Tap" ~ i.to!string ~ "_FeedbackPri");
			SET_VALS ~= MValue(MValueType.Float, (i<<7) | (19), "Tap" ~ i.to!string ~ "_FeedbackSec");
			SET_VALS ~= MValue(MValueType.Int32, (i<<7) | (20), "Tap" ~ i.to!string ~ "_Pos");
			SET_VALS ~= MValue(MValueType.Boolean, (i<<7) | (21), "Tap" ~ i.to!string ~ "_TapEnable");
			SET_VALS ~= MValue(MValueType.Boolean, (i<<7) | (22), "Tap" ~ i.to!string ~ "_BypassFIR");
		}
		for (uint i ; i < 4 ; i++) {
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (0), "LFO" ~ i.to!string ~ "_Waveform");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (1), "LFO" ~ i.to!string ~ "_Level");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (2), "LFO" ~ i.to!string ~ "_Freq");
			SET_VALS ~= MValue(MValueType.Float, (8<<7) | (i<<3) | (3), "LFO" ~ i.to!string ~ "_PWM");
			SET_VALS ~= MValue(MValueType.Int32, (8<<7) | (i<<3) | (4), "LFO" ~ i.to!string ~ "_Target");
		}
		for (uint i ; i < 8 ; i++) {
			SET_VALS ~= MValue(MValueType.Float, (9<<7) | (i<<2) | (0), "EQ" ~ i.to!string ~ "_Level");
			SET_VALS ~= MValue(MValueType.Float, (9<<7) | (i<<2) | (1), "EQ" ~ i.to!string ~ "_Freq");
			SET_VALS ~= MValue(MValueType.Float, (9<<7) | (i<<2) | (2), "EQ" ~ i.to!string ~ "_Q");
		}
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (0), "InputAtoPri");
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (1), "InputAtoSec");
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (2), "InputBtoPri");
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (3), "InputBtoSec");
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (4), "MasterL");
		SET_VALS ~= MValue(MValueType.Float, (10<<7) | (5), "MasterR");

	}
	protected static MValue[] SET_VALS;
	/** 
	 * Defines a delay line tap.
	 */
	protected struct Tap {
		__m128		outLevels	= __m128(0.0);///Output levels (0: Left; 1: Right, 2: Primary feedback, 3: Secondary feedback)
		__m128[4]	fir = [__m128(0.0),__m128(0.0),__m128(0.0),__m128(0.0)];///Short finite impulse response for the tap tap
		uint		pos;		///Median position of the tap (unaffected by LFO)
		bool		tapEnable;	///True if tap is enabled
		bool		bypassFIR;	///Bypasses FIR calculation
	}
	
	///Defines an LFO target
	protected enum OscTarget : ubyte {
		init		=	0,
		TapOut		=	1,
		TapFeedback	=	2,
		TapPosition	=	4,
		ToA			=	8,
		ToB			=	16,
	}
	///Contains recallable preset data.
	protected struct Preset {
		///Defines oscillator waveform selection data.
		///Bitfield notation:
		///  sawtooth = Enables or disables sawtooth output.
		///  triangle = Enables or disables triangle output.
		///  pulse = Enables or disables pulse output.
		///  sawpulse = Enables or disables sawpulse output.
		///  integrate = Compensates triangle/saw output for position offsetting.
		///  phaseInvert = Inverts the output phase of the oscillator.
		struct OscWaveform {
			union {
				mixin(bitfields!(
					bool, "sawtooth", 1,
					bool, "triangle", 1,
					bool, "pulse", 1,
					bool, "sawpulse", 1,
					bool, "integrate", 1,
					bool, "phaseInvert", 1,
					ubyte, "", 2,
				));
				ubyte raw;
			}
		}
		Tap[4][2]				taps;			///Defines delay line taps
		__m128[2]				iirFreq = [__m128([100, 500, 1000, 10_000]), __m128([100, 500, 1000, 10_000])];///Defines IIR frequencies
		__m128[2]				iirQ = [__m128(0.707), __m128(0.707)];///Defines IIR Q value
		__m128[2]				eqLevels = [__m128(0), __m128(0)];///Stores EQ send levels
		__m128					inputLevel = __m128(1);
		__m128					oscLevels = __m128(0);///Defines the amount of effect a given LFO has on a parameter
		float[4]				oscFrequencies = [4, 4, 4, 4];///Defines LFO freqencies
		uint[4]					oscPWM;			///Defines the PWM of the LFOs
		float[2]				outputLevel = [1.0, 1.0];
		ubyte[4]				oscTargets;		///Sets the target of a given LFO
		OscWaveform[4]			oscWaveform;	///Sets the waveform output of the LFOs
		
	}
	protected TreeMap!(uint,Preset)	presetBank;	///Stores presets
	protected Preset			currPreset;		///Contains the copy of the current preset
	protected IIRBank[2]		filterBanks;	///Stores filter data for the EQ
	protected float[2]			feedbackSends;	///Stores feedback send levels
	protected float[][2]		delayLines;		///The two delay lines of the 
	protected __m128			inLevel;		///0: A to pri, 1: A to sec, 2: B to pri, 3: B to sec
	protected float[2]			outLevel;		///Output levels
	protected float[2]			feedbackSum;	///Feedback sums to be mixed in with the inputs
	protected QuadMultitapOsc	osc;			///Oscillators to modify fix tap points
	protected __m128i[]			oscOut;			///LFO buffer
	protected size_t[2]			dLPos;			///Delay line positions
	protected size_t[2]			dLMod;			///Delay line modulo
	protected float[]			dummyBuf;		///Buffer used for unused inputs/outputs
	protected uint				presetNum;
	protected ubyte[68][8]		chCtrlLower;	///Lower parts of the channel controllers (0-31 / 32-63) + Unregistered parameter set
	
	/**
	 * Creates an instance of this module using the supplied parameters.
	 * Params:
	 *   priLen = Primary buffer length. Must be power of two.
	 *   secLen = Secondary buffer length. Must be power of two.
	 */
	public this(size_t priLen, size_t secLen) {
		assert(isPowerOf2(priLen));
		assert(isPowerOf2(secLen) || !secLen);
		info.nOfAudioInput = 2;
		info.nOfAudioOutput = 2;
		info.inputChNames = ["inputA", "inputB"];
		info.outputChNames = ["mainL", "mainR"];
		info.hasMidiIn = true;
		delayLines[0].length = priLen;
		delayLines[1].length = secLen;
		dLMod[0] = priLen - 1;
		dLMod[1] = secLen - 1;
		resetBuffer(delayLines[0]);
		resetBuffer(delayLines[1]);
	}
	/**
	 * Sets the module up.
	 *
	 * Can be overridden in child classes to allow resets.
	 */
	public override void moduleSetup(ubyte[] inputs, ubyte[] outputs, int sampleRate, size_t bufferSize, 
			ModuleManager handler) @safe nothrow {
		enabledInputs = StreamIDSet(inputs);
		enabledOutputs = StreamIDSet(outputs);
		this.sampleRate = sampleRate;
		this.bufferSize = bufferSize;
		this.handler = handler;
		oscOut.length = bufferSize;
		dummyBuf.length = bufferSize;
		feedbackSum[0] = 0;
		feedbackSum[1] = 0;
		//resetBuffer(oscOut);
		foreach (ref __m128i key; oscOut) {
			key = __m128i(0);
		}
		resetBuffer(dummyBuf);
		filterBanks[0].reset();
		filterBanks[1].reset();
	}

	override public void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow {
		switch (data0.msgType) {
			case MessageType.MIDI1:
				switch (data0.status) {
					case MIDI1_0Cmd.CtrlCh:
						if (data0.channel >= 8)
							return;
						if (data0.note < 63) {
							chCtrlLower[data0.channel][data0.note] = data0.value;
							if ((data0.note & 31) >= 16 && (data0.note & 31) <= 31) {
								controlChangeCmd(data0.channel, cast(ubyte)((data0.note & 31) - 16), 
										convertM1CtrlValToM2(chCtrlLower[data0.channel][data0.note & 31], 
										chCtrlLower[data0.channel][(data0.note & 31) + 32]));
							} else {
								switch (data0.note & 31) {
									case 0:
										chCtrlLower[0][data0.note] = data0.value;
										break;
									default:
										break;
								}
							}
						}
						break;
					case MIDI1_0Cmd.PrgCh:
						presetChangeCmd((data0.program) | (chCtrlLower[0][0]<<8) | (chCtrlLower[0][32]<<16));
						break;
					default:
						break;
				}
				break;
			case MessageType.MIDI2:
				switch (data0.status) {
					case MIDI2_0Cmd.CtrlCh:
						controlChangeCmd(data0.note, data0.value, data1);
						break;
					case MIDI2_0Cmd.PrgCh:
						chCtrlLower[0][0] = cast(ubyte)((data1>>8) & ubyte.max);
						chCtrlLower[0][32] = cast(ubyte)(data1 & ubyte.max);
						presetChangeCmd((data1>>24) | (chCtrlLower[0][0]<<8) | (chCtrlLower[0][32]<<16));
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}

	protected void controlChangeCmd(ubyte paramMSB, ubyte paramLSB, uint val) @nogc nothrow {
		switch (paramMSB) {
			case 0: .. case 7://Taps
				switch ( paramLSB ) {
					case 0: .. case 15:
						const int firGr = paramLSB / 4;
						currPreset.taps[paramMSB>>2][paramMSB&3].fir[firGr][paramLSB - 0] = (val / cast(double)int.max) - 1.0;
						break;
					case 16: .. case 19:
						currPreset.taps[paramMSB>>2][paramMSB&3].outLevels[paramMSB - 16] = val / cast(double)uint.max;
						break;
					case 20:
						currPreset.taps[paramMSB>>2][paramMSB&3].pos = 
								cast(uint)((val / cast(double)uint.max) * delayLines[paramMSB>>2].length);
						break;
					case 21:
						currPreset.taps[paramMSB>>2][paramMSB&3].tapEnable = val != 0;
						break;
					case 22:
						currPreset.taps[paramMSB>>2][paramMSB&3].bypassFIR = val != 0;
						break;
					default:
						break;
				}
				break;
			case 8://LFOs
				const int lfoGr = paramLSB>>3;
				switch (paramLSB & 7) {
					case 0:
						currPreset.oscWaveform[lfoGr].raw = cast(ubyte)val;
						break;
					case 1:
						currPreset.oscLevels[lfoGr] = val / cast(double)uint.max;
						break;
					case 2:
						currPreset.oscFrequencies[lfoGr] = val / cast(double)uint.max * 20;
						break;
					case 3:
						currPreset.oscPWM[lfoGr] = val;
						break;
					case 4:
						currPreset.oscTargets = cast(ubyte)val;
						break;
					default:
						break;
				}
				resetLFO(lfoGr);
				break;
			case 9://EQ
				const int eqGr = paramLSB>>2;
				switch (paramLSB & 3) {
					case 0:
						currPreset.eqLevels[eqGr>>2][eqGr&3] = sqrt(val / cast(double)uint.max) * 1.5 - 0.5;
						break;
					case 1:
						currPreset.iirFreq[eqGr>>2][eqGr&3] = pow(val / cast(double)uint.max, 2) * 20_000;
						break;
					case 2:
						currPreset.iirQ[eqGr>>2][eqGr&3] = pow(val / cast(double)uint.max, 2) * 9.99 + 0.01;
						break;
					default:
						break;
				}
				resetFilter(eqGr);
				break;
			case 10://Master
				switch (paramLSB) {
					case 0: .. case 3:
						currPreset.inputLevel[paramLSB] = pow(val / cast(double)uint.max, 2);
						break;
					case 4: case 5:
						currPreset.outputLevel[paramLSB - 4] = pow(val / cast(double)uint.max, 2);
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}

	protected void resetFilter(int filterID) @safe @nogc nothrow pure {
		filterBanks[filterID>>2].setFilter(createBPF1(sampleRate, currPreset.iirFreq[filterID>>2][filterID & 3], 
				currPreset.iirFreq[filterID>>2][filterID & 3]), filterID & 3);
		filterBanks[filterID>>2].fixFilter();
	}

	protected void resetLFO(int lfoID) @safe @nogc nothrow pure {
		osc.setRate(sampleRate, currPreset.oscFrequencies[lfoID], lfoID);
		osc.pulseWidth[lfoID] = currPreset.oscPWM[lfoID];
		const int waveNum = cast(int)currPreset.oscWaveform[lfoID].sawtooth + cast(int)currPreset.oscWaveform[lfoID].triangle 
				+ cast(int)currPreset.oscWaveform[lfoID].pulse + cast(int)currPreset.oscWaveform[lfoID].sawpulse;
		if (waveNum) {
			const short level = cast(short)((short.max * currPreset.oscWaveform[lfoID].phaseInvert) / waveNum);
			if (currPreset.oscWaveform[lfoID].sawtooth)
				osc.levelCtrl01[lfoID * 2] = level;
			if (currPreset.oscWaveform[lfoID].triangle)
				osc.levelCtrl01[lfoID * 2 + 1] = level;
			if (currPreset.oscWaveform[lfoID].pulse)
				osc.levelCtrl23[lfoID * 2] = level;
			if (currPreset.oscWaveform[lfoID].sawpulse)
				osc.levelCtrl23[lfoID * 2 + 1] = level;
		}
	}

	protected void presetChangeCmd(uint preset) @nogc nothrow {
		Preset* presetPtr = presetBank.ptrOf(preset);
		if (presetPtr is null) return;
		currPreset = *presetPtr;
		for (int i = 0 ; i < 8 ; i++) {
			resetFilter(i);
		}
		for (int i = 0 ; i < 4 ; i++) {
			resetLFO(i);
		}
	}

	override public void renderFrame(float*[] input, float*[] output) @nogc nothrow {
		//function to read from the delay line
		__m128[4] readDL(int lineNum, uint pos) @nogc @safe pure nothrow {
			__m128[4] result;
			for (int i ; i < 4 ; i++) {
				for (int j ; j < 4 ; j++) {
					result[i][j] = delayLines[lineNum][dLMod[lineNum] & (dLPos[lineNum] - pos - j - (i<<2))];
				}
			}
			return result;
		}
		float readDL0(int linenum, uint pos) @nogc @safe pure nothrow {
			return delayLines[linenum][dLMod[linenum] * (dLPos[linenum] - pos)];
		}
		float*[2] inBuf, outBuf;			//Set up input and output buffers
		for (ubyte i, j, k ; i < 2 ; i++) {
			if (enabledInputs.has(i)) {
				inBuf[i] = output[j];
				j++;
			} else {
				inBuf[i] = dummyBuf.ptr;
			}
			if (enabledOutputs.has(i)) {
				outBuf[i] = output[k];
				k++;
			} else {
				outBuf[i] = dummyBuf.ptr;
			}
		}
		//Precalculate values, so they don't need to be done on a per-cycle basis.
		
		__m128i[2] tapLFOOffset;
		__m128[2] tapLFOLevel;
		__m128[2] tapLFOFB;
		for (int i ; i < 2 ; i++) {
			for (int j ; j < 4 ; j++) {
				tapLFOLevel[i][j] = currPreset.oscTargets[j] == ((8<<i) | OscTarget.TapOut) ? 1.0 : 0.0;
				tapLFOOffset[i][j] = currPreset.oscTargets[j] == ((8<<i) | OscTarget.TapPosition) ? 1 : 0;
				tapLFOFB[i][j] = currPreset.oscTargets[j] == ((8<<i) | OscTarget.TapFeedback) ? 1.0 : 0.0;
			}
		}
		{	//Render LFO outs.
			for (int lfoPos ; lfoPos < bufferSize ; lfoPos++) {
				oscOut[lfoPos] = osc.output();
			}
			for (int i ; i < 4 ; i++) {
				if (currPreset.oscWaveform[i].integrate){	//integrate output if needed
					for (int lfoPos ; lfoPos < bufferSize ; lfoPos++) {
						oscOut[lfoPos][i] = cast(int)((abs(oscOut[lfoPos][i]) * cast(long)oscOut[lfoPos][i])>>32L);
					}
				}
			}
		}
		__m128 allSums = __m128(0.0);
		for (int outputPos ; outputPos < bufferSize ; outputPos++) {
			delayLines[0][dLMod[0] & dLPos[0]] = inBuf[0][outputPos] * currPreset.inputLevel[0] + 
					inBuf[1][outputPos] * currPreset.inputLevel[1] + allSums[2];
			delayLines[1][dLMod[1] & dLPos[1]] = inBuf[0][outputPos] * currPreset.inputLevel[0] + 
					inBuf[1][outputPos] * currPreset.inputLevel[1] + allSums[3];
			for (int d ; d < 2 ; d++) {
				for (int t ; t < 4 ; t++) {
					if (currPreset.taps[d][t].tapEnable) {
						float sum;
						if (currPreset.taps[d][t].bypassFIR) {
							sum = readDL0(d, currPreset.taps[d][t].pos + (oscOut[outputPos][t] * tapLFOOffset[d][t]));
						} else {
							__m128[4] impulse = readDL(d, currPreset.taps[d][t].pos);
							__m128 acc = __m128(0.0);
							for (int i ; i < 4 ; i++) {
								acc += impulse[i] * currPreset.taps[d][t].fir[i];
							}
							sum = acc[0] + acc[1] + acc[2] + acc[3];
						}
						allSums += currPreset.taps[d][t].outLevels * __m128(sum);
					}
				}
			}
			__m128 filterOutL = filterBanks[0].output(__m128(allSums[0])) * currPreset.eqLevels[0];
			__m128 filterOutR = filterBanks[1].output(__m128(allSums[1])) * currPreset.eqLevels[1];
			outBuf[0][outputPos] += allSums[0] + filterOutL[0] + filterOutL[1] + filterOutL[2] + filterOutL[3];
			outBuf[1][outputPos] += allSums[1] + filterOutR[0] + filterOutR[1] + filterOutR[2] + filterOutR[3];
			dLPos[0]++;
			dLPos[1]++;
			//delayLines[0][dLMod[0] & dLPos[0]] = allSums[2];
			//delayLines[1][dLMod[1] & dLPos[1]] = allSums[3];
		}
	}

	override public int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow {
		return SampleLoadErrorCode.SampleLoadingNotSupported;
	}

	override public int writeParam_int(uint presetID, uint paramID, int value) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			presetBank[presetID] = Preset.init;
			presetPtr = presetBank.ptrOf(presetID);
		}
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F;
				switch (subParamID) {
					case 0: .. case 19:
						return 1;
					case 20:	//Position
						presetPtr.taps[lineID][tapID].pos = value;
						return 0;
					case 21:	//Tap enable
						presetPtr.taps[lineID][tapID].tapEnable = value != 0;
						return 0;
					case 22:	//Bypass FIR
						presetPtr.taps[lineID][tapID].bypassFIR = value != 0;
						return 0;
					default:
						break;
				}
				break;
			case 8:		//LFO
				const uint lfoID = (paramID>>3) & 3, subParamID = paramID & 7;
				switch (subParamID) {
					case 0:
						presetPtr.oscWaveform[lfoID].raw = cast(ubyte)value;
						return 0;
					case 4:
						presetPtr.oscTargets[lfoID] = cast(ubyte)value;
						return 0;
					default:
						break;
				}
				break;
			default:
				break;
		}
		return 1;
	}

	override public int writeParam_long(uint presetID, uint paramID, long value) nothrow {
		return 1;
	}

	override public int writeParam_double(uint presetID, uint paramID, double value) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			presetBank[presetID] = Preset.init;
			presetPtr = presetBank.ptrOf(presetID);
		}
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F;
				switch (subParamID) {
					case 0: .. case 3:	//FIR 0
						presetPtr.taps[lineID][tapID].fir[0][subParamID] = value;
						return 0;
					case 4: .. case 7:	//FIR 1
						presetPtr.taps[lineID][tapID].fir[1][subParamID - 4] = value;
						return 0;
					case 8: .. case 11:	//FIR 2
						presetPtr.taps[lineID][tapID].fir[2][subParamID - 8] = value;
						return 0;
					case 12: .. case 15://FIR 3
						presetPtr.taps[lineID][tapID].fir[3][subParamID - 12] = value;
						return 0;
					
					case 16: .. case 19:	//Output Levels
						const uint levelID = (subParamID - 16) & 3;
						presetPtr.taps[lineID][tapID].outLevels[levelID] = value;
						return 0;
					default:
						break;
				}
				break;
			case 8:	//LFO
				const uint lfoID = (paramID>>3) & 3, subParamID = paramID & 7;
				switch (subParamID) {
					case 1:
						presetPtr.oscLevels[lfoID] = value;
						return 0;
					case 2:
						presetPtr.oscFrequencies[lfoID] = value;
						return 0;
					case 3:
						presetPtr.oscPWM[lfoID] = cast(uint)(value * uint.max);
						return 0;
					default:
						break;
				}
				break;
			case 9: //EQ
				const uint EQID = (paramID>>2) & 7;
				switch (paramID & 3) {
					case 0:
						presetPtr.eqLevels[EQID>>2][EQID & 3] = value;
						return 0;
					case 1:
						presetPtr.iirFreq[EQID>>2][EQID & 3] = value;
						return 0;
					case 2:
						presetPtr.iirQ[EQID>>2][EQID & 3] = value;
						return 0;
					default:
						break;
				}
				break;
			case 10: //Levels
				const uint subParamID = paramID & 7;
				switch (subParamID) {
					case 0: .. case 3:
						presetPtr.inputLevel[subParamID] = value;
						return 0;
					case 4, 5:
						presetPtr.outputLevel[subParamID - 4] = value;
						return 0;
					default:
						break;
				}
				break;
			default:
				break;
		}
		return 1;
	}

	override public int writeParam_string(uint presetID, uint paramID, string value) nothrow {
		return int.init; // TODO: implement
	}

	override public MValue[] getParameters() nothrow {
		return SET_VALS;
	}

	override public int readParam_int(uint presetID, uint paramID) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			return int.init;
		}
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F;
				switch (subParamID) {
					
					case 20:	//Position
						return presetPtr.taps[lineID][tapID].pos;
					case 21:	//Tap enable
						return presetPtr.taps[lineID][tapID].tapEnable ? 1 : 0;
					case 22:	//Bypass FIR
						return presetPtr.taps[lineID][tapID].tapEnable ? 1 : 0;
					default:
						break;
				}
				break;
			case 8:		//LFO
				const uint lfoID = (paramID>>3) & 3, subParamID = paramID & 7;
				switch (subParamID) {
					case 0:
						return presetPtr.oscWaveform[lfoID].raw;
					case 4:
						return presetPtr.oscTargets[lfoID];
					default:
						break;
				}
				break;
			default:
				break;
		}
		return int.init;
	}

	override public double readParam_double(uint presetID, uint paramID) nothrow {
		Preset* presetPtr = presetBank.ptrOf(presetID);
		if (presetPtr is null) {
			return double.init;
		}
		const uint paramGr = (paramID)>>7;
		switch (paramGr) {
			case 0: .. case 7:
				const uint tapID = paramGr & 3, lineID = paramGr>>2;
				const uint subParamID = paramID & 0x3F;
				switch (subParamID) {
					case 0: .. case 3:	//FIR 0
						return presetPtr.taps[lineID][tapID].fir[0][subParamID];
					case 4: .. case 7:	//FIR 1
						return presetPtr.taps[lineID][tapID].fir[1][subParamID - 4];
					case 8: .. case 11:	//FIR 2
						return presetPtr.taps[lineID][tapID].fir[2][subParamID - 8];
					case 12: .. case 15://FIR 3
						return presetPtr.taps[lineID][tapID].fir[3][subParamID - 12];
					case 16: .. case 19:	//Output Levels
						const uint levelID = (subParamID - 24) & 3;
						return presetPtr.taps[lineID][tapID].outLevels[levelID];
					default:
						break;
				}
				break;
			case 8:	//LFO
				const uint lfoID = (paramID>>3) & 3, subParamID = paramID & 7;
				switch (subParamID) {
					case 1:
						return presetPtr.oscLevels[lfoID];
					case 2:
						return presetPtr.oscFrequencies[lfoID];
					case 3:
						return presetPtr.oscPWM[lfoID] / uint.max;
					default:
						break;
				}
				break;
			case 9:	//EQ
				const uint EQID = (paramID>>2) & 7;
				switch (paramID & 3) {
					case 0:
						return presetPtr.eqLevels[EQID>>2][EQID & 3];
					case 1:
						return presetPtr.iirFreq[EQID>>2][EQID & 3];
					case 2:
						return presetPtr.iirQ[EQID>>2][EQID & 3];
					default:
						break;
				}
				break;
			case 10: //Levels
				const uint subParamID = paramID & 7;
				switch (subParamID) {
					case 0: .. case 3:
						return presetPtr.inputLevel[subParamID];
					case 4, 5:
						return presetPtr.outputLevel[subParamID - 4];
					default:
						break;
				}
				break;
			default:
				break;
		}
		return double.init; // TODO: implement
	}

	override public long readParam_long(uint presetID, uint paramID) nothrow {
		return long.init; // TODO: implement
	}

	override public string readParam_string(uint presetID, uint paramID) nothrow {
		return string.init; // TODO: implement
	}
}