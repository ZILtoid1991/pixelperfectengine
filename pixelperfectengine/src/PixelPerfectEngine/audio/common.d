module PixelPerfectEngine.audio.common;

import PixelPerfectEngine.system.platform;
static if(USE_INTEL_INTRINSICS){
	import inteli.emmintrin;
	//immutable __m128i zeroes;
	immutable __m128 multiVal = [32_768f, 32_768f, 32_768f, 32_768f];
}else{
	immutable float[4] multiVal = [32_768f, 32_768f, 32_768f, 32_768f];
}

import std.bitmanip;
import std.math;

/**
 * Defines basic functions for an envelope generator.
 */
public interface IEnvelopeGenerator{
	public @nogc uint updateEnvelopeState();
	public @nogc void setKeyOn();
	public @nogc void setKeyOff();
}
/**
 * Stores an MICP command on 64 bits.
 */
public struct MICPCommand{
	mixin(bitfields!(
		ushort, "command", 6,
		ushort, "channel", 10));
	ushort val0;		///
	union{
		ushort[2] vals;
		float valf;
		ubyte[4] midiCMD;
		uint val32;
	}
	/*alias note = val0;
	alias parameter = val0;
	alias velocity = val1[0];
	alias expr = val1[1];
	alias program = val1[0];
	alias bank = val1[1];
	alias valueInt = val1[0];
	alias valueFloat = val2;*/
}
/**
 * Command list for MICP
 */
public enum MICPCommandList : ushort{
	NULL	=	0,
	KeyOn	=	1,			///val0: Note, val1: Velocity, val2: Expression
	KeyOff	=	2,			///val0: Note, val1: Velocity, val2: Expression
	AfterTouch	=	3,		///val0: Note, val1: Velocity, val2: Expression
	PitchBend	=	4,		///val0: Note, val1: Corase, val2: Fine
	PitchBentFP	=	5,		///val0: Note, valf: Amount
	ProgSelect	=	6,		///val0: Prog, val1: Bank if used, val2: Unused
	ParamEdit	=	7,		///val0: Parameter ID, val1: New value, val2: Unused
	ParamEditFP	=	8,		///val0: Parameter ID, valf: New value
	ParamEdit32 =	9,		///val0: Parameter ID, val32: New value
	PrgKeyOn	=	11,		///Special key-on command. Same params as KeyOn. Mainly used for arpeggiation and programming sequences
	PrgKeyOff	=	12,		///Special key-off command. Same params as KeyOff. Mainly used for arpeggiation and programming sequences
	SysExc	=	16,
	MIDIThruMICP	=	17,	///val0 is unused
	Wait	=	24			///val0: bits 32-47 if needed, val32: bits 0-31
}

/**
 * All PPE-FX synths and effects should be inherited from this class.
 */
abstract class AbstractPPEFX{
	public abstract @nogc void render(float** inputBuffers, float** outputBuffers);
	public abstract @nogc int setRenderParams(float samplerate, size_t framelength, size_t nOfFrames);
	public abstract @nogc void receiveMICPCommand(MICPCommand cmd);
	public abstract void loadConfig(ref void[] data);
	public abstract ref void[] saveConfig();
	public abstract PPEFXInfo* getPPEFXInfo();
	/**
	 * Converts a midi note to frequency, can also take fine tuning.
	 */
	public @nogc float midiNoteToFrequency(float note, float tuning = 440.0f){
    	return tuning * pow(2.0, (note - 69.0f) / 12.0f);
	}
	/**
	 * Changes the frequency by the given pitch.
	 */
	public @nogc float bendFreqByPitch(float pitch, float input){
    	return input * pow(2.0, pitch / 12.0f);
	}
	public @nogc float frequencyToMidiNote(float frequency, float tuning = 440.0f){
    	return 69.0f + 12.0f * log2(frequency / tuning);
	}
	/**
	 * Converts int16 values to single-precision floating-point.
	 */
	public @nogc void int16ToFloat(short* input, float* output, size_t length){
		static if(USE_INTEL_INTRINSICS){
			while(length > 4){
				__m128i vals;// = [input[0],input[1],input[2],input[3]];
				vals[0] = input[0];
				vals[1] = input[1];
				vals[2] = input[2];
				vals[3] = input[3];
				*cast(__m128*)output = _mm_cvtepi32_ps(vals) / multiVal;
				input += 4;
				output += 4;
				length -= 4;
			}
		}
		while(length > 0){
			*output = cast(float)*input / multiVal[0];
			input++;
			output++;
			length--;
		}
	}
	/**
	 * Converts single-precision floating point to int16 values.
	 */
	public @nogc void floatToInt16(float* input, short* output, size_t length){
		static if(USE_INTEL_INTRINSICS){
			while(length > 4){
				__m128i vals = _mm_cvtps_epi32(*cast(__m128*)input * multiVal);
				output[0] = cast(short)vals[0];
				output[1] = cast(short)vals[1];
				output[2] = cast(short)vals[2];
				output[3] = cast(short)vals[3];
				input += 4;
				output += 4;
				length -= 4;
			}
		}
		while(length > 0){
			*output = cast(short)(*input / multiVal[0]);
			input++;
			output++;
			length--;
		}
	}
	/**
	 * Mixes a stream into the target.
	 */
	public @nogc void mixStreamIntoTarget(float* input, float* output, size_t length, float sendLevel){
		static if(USE_INTEL_INTRINSICS){
			__m128 sendLevel4;// = [sendLevel,sendLevel,sendLevel,sendLevel];
			sendLevel4[0] = sendLevel;
			sendLevel4[1] = sendLevel;
			sendLevel4[2] = sendLevel;
			sendLevel4[3] = sendLevel;
			while(length > 4){
				*cast(__m128*)output += *cast(__m128*)input * sendLevel4;
				input += 4;
				output += 4;
				length -= 4;
			}
		}
		while(length > 0){
			*output += *input * sendLevel;
			input++;
			output++;
			length--;
		}
	}
	/**
	 * Converts an int16 stream into floating point, then adds it to the target.
	 */
	public @nogc void convAndMixStreamIntoTarget(short* input, float* output, size_t length, float sendLevel){
		static if(USE_INTEL_INTRINSICS){
			__m128 sendLevel4;// = [sendLevel,sendLevel,sendLevel,sendLevel];
			sendLevel4[0] = sendLevel;
			sendLevel4[1] = sendLevel;
			sendLevel4[2] = sendLevel;
			sendLevel4[3] = sendLevel;
			while(length > 4){
				__m128i vals;// = [input[0],input[1],input[2],input[3]];
				vals[0] = input[0];
				vals[1] = input[1];
				vals[2] = input[2];
				vals[3] = input[3];
				*cast(__m128*)output += (_mm_cvtepi32_ps(vals) / multiVal) * sendLevel4;
				input += 4;
				output += 4;
				length -= 4;
			}
		}
		while(length > 0){
			*output += (cast(float)*input / multiVal[0]) * sendLevel;
			input++;
			output++;
			length--;
		}
	}
}

public struct PPEFXInfo{
	public int nOfInputs;
	public int nOfOutputs;
	public string[] inputNames;
	public string[] outputNames;
	public bool isSynth;

}
