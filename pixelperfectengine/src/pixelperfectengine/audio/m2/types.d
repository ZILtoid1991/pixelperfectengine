module pixelperfectengine.audio.m2.types;

public import core.time : Duration, hnsecs, nsecs;
import std.typecons : BitFlags;
import collections.treemap;

/** 
 * Contains opcodes for M2 operations.
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
	emit_r0		=	0x42,		///Emit command with value from register
	emit_0r		=	0x43,		///Emit command to group/channel from register
	emit_rr		=	0x44,		///Emit command to group/channel from register with value from register
	cue			=	0x48,		///Set cue point/marker
	trnsps		=	0x49,		///Transpose
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
 * Defines an M2 pattern slot status data.
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
	public uint position;				///Position within the pattern
	public uint timeMult = 0x1_00_00;	///Time multiplier (16bit precision)
	public uint backLink = uint.max;	///Backlinking for pattern nesting
	public Duration timeToWait;			///Time until next command chunk
	public void reset() @nogc @safe nothrow {
		status = status.init;
		foreach (ref uint key; localReg) {
			key = 0;
		}
		lastCue = 0;
		position = 0;
		timeMult = 0x1_00_00;
		timeToWait = hnsecs(0);
	}
}

public struct M2Song {
	public uint[128] globalReg;
	public M2PatternSlot[] ptrnSl;
	//public uint[] activePtrnNums;
	public uint globTimeMult = 0x1_00_00;///Time multiplier (16bit precision)
	public ulong timebase;				///nsecs of a single tic
	public TreeMap!(uint, uint[]) ptrnData;
	this (uint parPtrnNum, M2TimeFormat timefrmt, uint timeper, uint timeres) @safe nothrow {
		ptrnSl.length = parPtrnNum;
		final switch (timefrmt) with(M2TimeFormat) {
			case ms:
				timebase = 1_000_000;
				break;
			case us:
				timebase = 1_000;
				break;
			case hns:
				timebase = 100;
				break;
			case fmt3:
				timebase = cast(ulong)((1 / (cast(real)timeper / timeres)) * 1_000_000_000);
				break;
			case fmt4:
				timebase = cast(ulong)((1 / (timeper / 256.0 / timeres)) * 1_000_000_000);
				break;
			case fmt5:
				timebase = cast(ulong)((1 / (timeper / 65_536.0 / timeres)) * 1_000_000_000);
				break;
		}
		
	}
}

public struct M2File {
	public M2Song songdata;
	public string[string] metadata;
	public string[uint] devicelist;
	public ushort patternNum;
	public M2TimeFormat timeFormat;
	public uint timeFrmtPer;
	public uint timeFrmtRes;
}

package struct DataReaderHelper {
	union {
		uint word;
		ushort[2] hwords;
		ubyte[4] bytes;
	}
	this (uint base) @nogc @safe pure nothrow {
		word = base;
	}
}

package immutable string[128] noteLookupTable =
	[
		"C-00", "C#00", "D-00", "D#00", "E-00", "F-00", "F#00", "G-00", //0
		"G#00", "A-00", "A#00", "B-00", "C-0", "C#0", "D-0", "D#0", 	//1
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