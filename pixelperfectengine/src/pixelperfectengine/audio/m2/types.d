module pixelperfectengine.audio.m2.types;

public import core.time : Duration, hnsecs, nsecs;
import std.typecons : BitFlags;
import collections.treemap;
public import pixelperfectengine.system.exc;

/** 
 * Contains opcodes for IMBC operations.
 */
public enum OpCode : ubyte {
	nullcmd		=   0x00,		///Null command
	shwait		=   0x01,		///Short wait (24 bits)
	lnwait		=   0x02,		///Long wait (48 bits)
	emit		=   0x03,		///Emit command list to device
	jmp			=   0x04,		///Conditional jump
	chain_par	=   0x05,		///Chain in pattern in parallel
	chain_ser	=   0x06,		///Chain in pattern in serial
	//Math operations on registers begin
	add			=   0x07,		///Add two registers, store in third
	sub			=   0x08,		///Subtract two registers, store in third
	mul			=   0x09,		///Multiply two registers, store in third
	div			=   0x0a,		///Divide two registers, store in third
	mod			=   0x0b,		///Modulo two registers, store in third
	and			=   0x0c,		///Binary and two registers, store in third
	or			=   0x0d,		///Binary or two registers, store in third
	xor			=   0x0e,		///Binary xor two registers, store in third
	not			=   0x0f,		///Binary invert RA, store in RD
	lshi		=   0x10,		///Logically shift left RA by RB immediate value, store in RD
	rshi		=   0x11,		///Logically shift right RA by RB immediate value, store in RD
	rasi		=   0x12,		///Arithmetically shift right RA by RB immediate value, store in RD
	adds		=   0x13,		///Add two registers, store in third (signed)
	subs		=   0x14,		///Subtract two registers, store in third (signed)
	muls		=   0x15,		///Multiply two registers, store in third (signed)
	divs		=   0x16,		///Divide two registers, store in third (signed)
	lsh         =   0x17,		///Logically shift left RA by RB, store in RD
	rsh         =   0x18,		///Logically shift right RA by RB, store in RD
	ras         =   0x19,		///Arithmetically shift right RA by RB, store in RD
	mov         =   0x1a,		///Move register content of RA to RD
	satadd		=	0x1b,		///Saturated add
	satsub		=	0x1c,		///Saturated subtract
	satmul		=	0x1d,		///Saturated multiply
	satadds		=	0x1e,		///Saturated signed add
	satsubs		=	0x1f,		///Saturated signed subtract
	satmuls		=	0x20,		///Saturated signed multiply
	//Math operations on registers end
	cmp			=	0x40,		///Compare two register values
	chain		=	0x41,		///Abandon current pattern to next one
	emit_r		=	0x42,		///Emit command with value from register
	cue			=	0x48,		///Set cue point/marker
	trnsps		=	0x49,		///Transpose
	array		=	0x4a,		///Array operation
	ctrl		=	0xf0,		///Control command
	display		=	0xff,		///Display command
}
/** 
 * Contains compare codes for M2 cmp operations.
 */
public enum CmpCode : ubyte {
	init,
	eq,							///Equal
	ne,							///Not equal
	gt,							///Greater than
	ge,							///Greater or equal
	lt,							///Less than
	le,							///Less or equal
	ze,							///RA is zero
	nz,							///RA is not zero
	ng,							///RA is negative
	po,							///RA is positive
	sgt,						///Signed greater than
	sge,						///Signed greater or equal
	slt,						///Signed less than
	sle,						///Signed less or equal
}
/** 
 * Contains jump condition coded for M2 jmp operations.
 */
public enum JmpCode : ubyte {
	nc,							///Always jump
	eq,							///Jump if condition code is equal to condition register
	ne,							///Jump if condition code is not equal to condition register
	sh,							///Jump if at least some of the same bits are high in both the condition code and the condition register
	op,							///Jump is all the bits are opposite in the condition code from the condition register
}
/** 
 * Sets the mode/scale for the transposing mode
 */
public enum TransposeMode : ubyte {
	chromatic,
	maj,
	min,
}
/** 
 * Defines display command codes.
 */
public enum DisplayCmdCode : ubyte {
	init,
	setVal					=	0x01,
	setVal64				=	0x02,

	unrollLoop				=	0x03,
	unrollLoop48			=	0x04,

	strCue					=	0xF0,
	strNotation				=	0xF1,
	strLyrics				=	0xF2,

	strPrevBlC				=	0xFF,
}
/** 
 * Defines values that can be modified by the display command.
 */
public enum SetDispValCode : ushort {
	init,
	BPM						=	0x00_01,
	timeSignature			=	0x00_02,
	clef					=	0x00_03,
	keySignature			=	0x00_04,
}
/** 
 * Defines control command codes.
 */
public enum CtrlCmdCode : ubyte {
	init,
	setRegister				=	0x01,
	setEnvVal				=	0x02,
}
/** 
 * Defines environment values that can be modified by the control command.
 */
public enum SetEnvValCode : ushort {
	init,
	setTimeMultLocal		=	0x00_01,
	setTimeMultGlobal		=	0x00_02,
}
public enum ArrayOpCode : ubyte {
	init,
	read					=	0x01,
	write					=	0x02,
	readsat					=	0x03,
	writesat				=	0x04,
	length					=	0x05,
}
/**
 * Defines the time formats that are possible within the M2 format.
 */
public enum M2TimeFormat : ubyte {
	ms,
	us,
	hns,
	fmt3,
	fmt4,
	fmt5,
}
///Compare register number.
public enum CR = 127;
///ID used to designate inactive pattern slots.
public enum PATTERN_SLOT_INACTIVE_ID = uint.max;

/** 
 * Defines an IMBC pattern slot status data.
 */
public struct M2PatternSlot {
	public enum StatusFlags : uint {
		isRunning		=	1<<0,		///Set if pattern is running
		hasEnded		=	1<<1,		///Set if pattern has ended(slot can be reused)
		suspend			=	1<<2,		///Set if pattern is on suspension
	}
	public uint[128] localReg;			///Local register bank
	public BitFlags!StatusFlags status;	///Status flags
	public uint lastCue;				///ID of the last reached cue
	public uint id = PATTERN_SLOT_INACTIVE_ID;///ID of the currently played pattern
	public int position;				///Position within the pattern
	public uint timeMult = 0x1_00_00;	///Time multiplier (16bit precision)
	public uint backLink = uint.max;	///Backlinking for pattern nesting
	public Duration timeToWait;			///Time until next command chunk
	public Duration patternTime;		///Stores the current time of the pattern
	public void reset() @nogc @safe pure nothrow {
		status = status.init;
		foreach (ref uint key; localReg) {
			key = 0;
		}
		lastCue = 0;
		position = 0;
		timeMult = 0x1_00_00;
		timeToWait = hnsecs(0);
		patternTime = hnsecs(0);
		id = PATTERN_SLOT_INACTIVE_ID;
	}
}
/** 
 * Defines IMBC song data.
 */
public struct M2Song {
	public uint[128] globalReg;			///Global (shared) register bank
	public M2PatternSlot[] ptrnSl;		///Pattern slots that can be used for pattern processing
	//public uint[] activePtrnNums;
	public uint globTimeMult = 0x1_00_00;///Time multiplier (16bit precision)
	public ulong timebase;				///nsecs of a single tic
	public ulong ticsPerSecs;			///Tics per second
	public TreeMap!(uint, uint[]) ptrnData;
	public TreeMap!(uint, uint[]) arrays;				///List of registered arrays
	this (uint parPtrnNum, M2TimeFormat timefrmt, uint timeper, uint timeres) @safe nothrow {
		ptrnSl.length = parPtrnNum;
		final switch (timefrmt) with(M2TimeFormat) {
			case ms:
				//timebase = 1_000_000;
				ticsPerSecs = 1000;
				break;
			case us:
				//timebase = 1_000;
				ticsPerSecs = 1_000_000;
				break;
			case hns:
				//timebase = 100;
				ticsPerSecs = 10_000_000;
				break;
			case fmt3:
				//timebase = cast(ulong)((1 / (cast(real)timeper / timeres)) * 1_000_000_000);
				ticsPerSecs = timeper * timeres;
				break;
			case fmt4:
				//timebase = cast(ulong)((1 / (timeper / 256.0 / timeres)) * 1_000_000_000);
				ticsPerSecs = cast(ulong)((timeper / 16.0) * timeres);
				break;
			case fmt5:
				//timebase = cast(ulong)((1 / (timeper / 65_536.0 / timeres)) * 1_000_000_000);
				ticsPerSecs = cast(ulong)((timeper / 256.0) * timeres);
				break;
		}
		//timebase = cast(ulong)((1.0 / ticsPerSecs) * 10_000_000_000L);	
		timebase = cast(ulong)(1_000_000_000.0 / ticsPerSecs);
	}
}
/** 
 * Contains information related to transposing.
 */
public struct TransposingData {
	ubyte		mode;			//Scale ID, or zero for chromatic mode
	byte		amount;			//The amount of (semi)notes
	ubyte		exclCh;			//Excluded channel(s)'s ID
	ubyte		exclType;		//Exclusion type (0: none, 1: single channel, 2: all channels above ID, 3 all channels below ID)
}
	
/** 
 * Contains all officially recognized M2 file data.
 */
public struct M2File {
	public M2Song songdata;
	public string[string] metadata;
	public string[uint] devicelist;
	public ushort deviceNum;
	public M2TimeFormat timeFormat;
	public uint timeFrmtPer;
	public uint timeFrmtRes;
	public uint patternNum;
}
///Used by the sequencer for reading command data, and by compilers to create new commands.
public struct M2Command {
	union {
		uint word;
		ushort[2] hwords;
		ubyte[4] bytes;
	}
	this (uint base) @nogc @safe pure nothrow {
		word = base;
	}
	this (ubyte[4] bytes) @nogc @safe pure nothrow {
		this.bytes = bytes;
	}
	static M2Command emit(size_t length, uint target) @nogc @safe pure nothrow {
		M2Command result;
		result.bytes[0] = OpCode.emit;
		result.bytes[1] = cast(byte)length;
		result.hwords[1] = cast(ushort)target;
		return result;
	}
	static M2Command cmd24bit(ubyte op, uint val) @nogc @safe pure nothrow {
		M2Command result;
		result.bytes[0] = op;
		result.bytes[1] = cast(ubyte)(val);
		result.bytes[2] = cast(ubyte)(val>>8);
		result.bytes[3] = cast(ubyte)(val>>16);
		return result;
	}
	
	uint read24BitField() @nogc @safe pure nothrow const {
		return (bytes[1]) | (bytes[2]<<8) | (bytes[3]<<16);
	}
	bool bitField(uint n) @nogc @safe pure nothrow const {
		return ((word<<n) & 0x8000_0000) == 0x8000_0000;
	}
}
///Used for note lookup when reading and writing textual M2 files.
public immutable string[128] NOTE_LOOKUP_TABLE =
	[
		"C-00","C#00","D-00","D#00","E-00","F-00","F#00","G-00",		//0
		"G#00","A-00","A#00","B-00","C-0", "C#0", "D-0", "D#0",			//1
		"E-0", "F-0", "F#0", "G-0", "G#0", "A-0", "A#0", "B-0", 		//2
		"C-1", "C#1", "D-1", "D#1", "E-1", "F-1", "F#1", "G-1", 		//3
		"G#1", "A-1", "A#1", "B-1", "C-2", "C#2", "D-2", "D#2", 		//4
		"E-2", "F-2", "F#2", "G-2", "G#2", "A-2", "A#2", "B-2", 		//5
		"C-3", "C#3", "D-3", "D#3", "E-3", "F-3", "F#3", "G-3", 		//6
		"G#3", "A-3", "A#3", "B-3", "C-4", "C#4", "D-4", "D#4", 		//7
		"E-4", "F-4", "F#4", "G-4", "G#4", "A-4", "A#4", "B-4", 		//8
		"C-5", "C#5", "D-5", "D#5", "E-5", "F-5", "F#5", "G-5", 		//9
		"G#5", "A-5", "A#5", "B-5", "C-6", "C#6", "D-6", "D#6", 		//10
		"E-6", "F-6", "F#6", "G-6", "G#6", "A-6", "A#6", "B-6", 		//11
		"C-7", "C#7", "D-7", "D#7", "E-7", "F-7", "F#7", "G-7", 		//12
		"G#7", "A-7", "A#7", "B-7", "C-8", "C#8", "D-8", "D#8", 		//13
		"E-8", "F-8", "F#8", "G-8", "G#8", "A-8", "A#8", "B-8", 		//14
		"C-9", "C#9", "D-9", "D#9", "E-9", "F-9", "F#9", "G-9", 		//15
	];
public immutable string[10] VELOCITY_MACRO_LOOKUP_TABLE_STR =
	["PPPP","PPP" ,"PP"  ,"P"   ,"MP"  ,"MF"  ,"F"   ,"FF"  ,"FFF" ,"FFFF"];
public immutable ubyte[10] VELOCITY_MACRO_LOOKUP_TABLE_M1 =
	[0x00  ,0x0f  ,0x1f  ,0x2f  ,0x3f  ,0x4f  ,0x5f  ,0x6f  ,0x75  ,0x7f  ];
public immutable ushort[10] VELOCITY_MACRO_LOOKUP_TABLE_M2 =
	[0x0000,0x00ff,0x22ff,0x44ff,0x66ff,0x88ff,0xaaff,0xccff,0xeeff,0xffff];

public class IMBCException : PPEException {
	///
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
	///
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
