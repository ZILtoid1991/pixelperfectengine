module pixelperfectengine.audio.m2.rw_text;

public import pixelperfectengine.audio.m2.types;
import std.string;
import std.exception;
import std.array : split;
import std.uni : isWhite;
import std.math : isNaN;
import std.format.read : formattedRead;
import std.conv : to;
import std.algorithm.searching : canFind, startsWith, countUntil;
import std.algorithm.mutation : remove;
import collections.sortedlist;
import collections.hashmap;
import midi2.types.enums;
import midi2.types.structs;
///Converts the input to all caps.
///TODO: Write a vectorized version.
package string toAllCaps(string s) @safe nothrow {
	string result;
	result.reserve = s.length;
	for (int i = 0; i < s.length ; i++) {
		result ~= s[i] >= 0x61 && s[i] <= 0x7A ? s[i] & 0x5F : s[i];
	}
	return result;
}
///Parses the supplied number, either as decimal of hexadecimal (if starts with `0x`)
package long parsenum(string s) {
	if (s.startsWith("0x") || s.startsWith("0X")) {
		return s[2..$].to!long(16);
	} else {
		return s.to!long;
	}
}
///Removes the comments from the line (after character `;`)
package string removeComment(string s) {
	const ptrdiff_t commentPos = countUntil(s, ";");
	if (commentPos == -1) return s;
	return s[0..commentPos];
}
///Tries to parse a note data.
package int parseNote(string n) {
	//return cast(int)countUntil(NOTE_LOOKUP_TABLE, n);
	n = toAllCaps(n);
	for (int i = 0; i < 128 ; i++) {
		if (NOTE_LOOKUP_TABLE[i] == n) return i;
	}
	return cast(int)parsenum(n);
}
///Tries to parse a velocity macro (MIDI 1.0)
package ubyte parseVelocityM1(string s) {
	s = toAllCaps(s);
	for (int i ; i < 10 ; i++) {
		if (VELOCITY_MACRO_LOOKUP_TABLE_STR[i] == s) return VELOCITY_MACRO_LOOKUP_TABLE_M1[i];
	}
	return cast(ubyte)parsenum(s);
}
///Tries to parse a velocity macro (MIDI 2.0)
package ushort parseVelocityM2(string s) {
	s = toAllCaps(s);
	for (int i ; i < 10 ; i++) {
		if (VELOCITY_MACRO_LOOKUP_TABLE_STR[i] == s) return VELOCITY_MACRO_LOOKUP_TABLE_M2[i];
	}
	return cast(ushort)parsenum(s);
}
///Parses register number.
///Returns register index if successful, returns -1 if not properly formatted register number.
package int parseRegister(const string s) {
	if (s[0] == 'R') {
		try
			return s[1..$].to!int(16);
		catch (Exception e) {}
	}
	return -1;
}
///Returns rhythm duration as floating point number, or returns NaN if rhythm notation is incorrect.
package double getRhythmDur(const char c) @nogc @safe pure nothrow {
	switch (c) {
		case 'W': return 1.0;
		case 'H': return 1.0 / 2.0;
		case 'Q': return 1.0 / 4.0;
		case 'O': return 1.0 / 8.0;
		case 'S': return 1.0 / 16.0;
		case 'T': return 1.0 / 32.0;
		case 'I': return 1.0 / 64.0;
		case 'X': return 1.0 / 128.0;
		case 'Y': return 1.0 / 256.0;
		case 'Z': return 1.0 / 512.0;
		case 'U': return 1.0 / 1024.0;
		default: return double.nan;
	}
}
///Returns the tuplet division for the current rhythm of `base` identified by `c`.
package double getTupletDiv(const string c, const double base) @nogc @safe pure nothrow {
	switch (c) {
		default: return base;
		case "2": return base * 3 / 2;
		case "3": return base * 2 / 3;
		case "4": return base * 3 / 4;
		case "5": return base * 4 / 5;
		case "6": return base * 4 / 6;
		case "7": return base * 4 / 7;
		case "8": return base * 6 / 8;
		case "9": return base * 8 / 9;
		case "10": return base * 8 / 10;
		case "11": return base * 8 / 11;
		case "12": return base * 8 / 12;
		case "13": return base * 8 / 13;
		case "14": return base * 8 / 14;
		case "15": return base * 8 / 15;
	}
}
/**
 * Parses a textual rhythm notation.
 * Params:
 *   n = The string to be parsed.
 *   bpm = The current BPM of the pattern.
 *   timebase = Ticks per miliseconds for the song.
 */
package ulong parseRhythm(string n, float bpm, long timebase) {
	const long whNoteLen = cast(long)(timebase * (1.0 / (bpm / 60.0)));
	double duration = 0.0;
	n = toAllCaps(n);
	string[] indiv = n.split("+");
	foreach (string part ; indiv) {
		enforce (part.length, "Rhythm syntax error");
		int pos;
		double currDur = 0.0;
		if (part[0] >= '1' && part[0] <= '9') {
			if (part[1] >= '0' && part[1] <= '5') {
				currDur = getTupletDiv(part[0..2], getRhythmDur(part[2]));
				pos = 3;
			} else {
				currDur = getTupletDiv(part[0..1], getRhythmDur(part[1]));
				pos = 2;
			}
		} else {
			currDur = getRhythmDur(part[0]);
			pos = 1;
		}
		for (int i = 1 ; pos < part.length ; i++, pos++) {
			if(part[pos] == '.')
				currDur *= 1 + (0.5 * i);
			else
				currDur = double.nan;
		}
		duration += currDur;
	}
	enforce (!isNaN(duration), "Rhythm syntax error");
	return cast(ulong)(duration * whNoteLen);
}
/** 
 * Implements the IMBC assembler.
 * Compiles the IMBC assembly into IMBC binary. Implements some macro support (TODO: Implement `if` and loop macros).
 */
public struct IMBCAssembler {
	///Defines context states for parsing
	enum Context {
		init,			///Initial parsing state
		headerParse,	///Assembler is parsing header
		arrayParse,		///Parsing of array data
		metadataParse,	///Parsing of metadata 
		deviceParse,	///Device data and descriptors
		patternParse,	///Pattern data
		stringParse,	///String (only used with metadata).
	}
	///Defines a yet to be resolved position, array, and pattern label
	struct UnresolvedPositionLabel {
		string name;
		uint[2][] positions;		///0: Pattern ID if applicable, 1: Position of place where label must be resolved
	}
	/// Defines the type of the scope statement
	enum ScopeType {
		init,
		IfStatement,
		ElseifStatement,
		ElseStatement,
		WhileStatement,
		DoUntilStatement,
	}
	/// Defines a scope for macro statements
	struct Scope {
		ScopeType type;
		size_t begin;
	}
	/// Defines locally stored pattern information
	struct PatternData {
		string name;
		size_t lineNum;
		uint id;
		float currBPM = 120;
		//size_t[string] positionLabels;
		HashMap!(string, size_t) positionLabels;
		UnresolvedPositionLabel[] unresolvedLabels;
		Scope[] scopeStack;
		this(string name, size_t lineNum, uint id) {
			this.name = name;
			this.lineNum = lineNum;
			this.id = id;
		}
		sizediff_t searchUnresolvedPositionLabelByName(string name) @nogc @safe pure nothrow const {
			for (sizediff_t i ; i < unresolvedLabels.length ; i++) {
				if (unresolvedLabels[i].name) return i;
			}
			return -1;
		}
	}
	///Defines note macro data
	struct NoteData {
		uint device;
		ubyte ch;
		ubyte note;
		ushort velocity;
		long durFrom;
		long durTo;
		bool opEquals(const NoteData other) @nogc @safe pure nothrow const {
			return this.device == other.device && this.ch == other.ch && this.note == other.note && 
					this.velocity == other.velocity && this.durFrom == other.durFrom && this.durTo == other.durTo;
		}
		int opCmp(const NoteData other) @nogc @safe pure nothrow const {
			if (this.durTo > other.durTo) return 1;
			if (this.durTo < other.durTo) return -1;
			return 0;
		}
		size_t toHash() const @nogc @safe pure nothrow {
			return durFrom ^ durTo;
		}
	}
	string input;
	M2File result;
	Context context, prevContext;
	uint currPatternID, patternCntr = 1;
	ulong timePos;
	ushort currDevNum;
	string parsedString;
	PatternData[] ptrnData;
	string[] arrayNames;
	uint[] currEmitStr;
	SortedList!(NoteData, "a > b") noteMacroHandler;
	UnresolvedPositionLabel[] unresolvedPatterns;
	this(string input) {
		this.input = input;
	}
	///Searches pattern by `name`, returns its index, or -1 if not found
	sizediff_t searchPatternByName(const string name) @nogc @safe pure nothrow const {
		for (sizediff_t i ; i < ptrnData.length ; i++) {
			if (ptrnData[i].name == name) return i;
		}
		return -1;
	}
	///Searches unresolved pattern by `name`, returns its index, or -1 if not found
	sizediff_t searchUnresolvedPatternByName(const string name) @nogc @safe pure nothrow const {
		for (sizediff_t i ; i < unresolvedPatterns.length ; i++) {
			if (unresolvedPatterns[i].name == name) return i;
		}
		return -1;
	}
	/** 
	 * Overwrites a command in pattern at the given position
	 * Params:
	 *   ptrnID = Identifies the pattern where the data to be overwritten is stored
	 *   data = The data to be written
	 *   pos = The position of the command
	 */
	void overwriteCmdAt(uint ptrnID, uint data, uint pos) {
		auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
		assert (ptrn !is null);
		(*ptrn)[pos] = data;
	}
	///Reads data from pattern identified by `ptrnID` at position of `pos`.
	uint readCmd(uint ptrnID, uint pos) {
		auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
		assert (ptrn !is null);
		return (*ptrn)[pos];
	}
	/** 
	 * Writes a command string at the end of a pattern.
	 * Params:
	 *   ptrnID = The pattern where the command must be written to.
	 *   data = The command string data to be written.
	 */
	void writeCmdStr(uint ptrnID, uint[] data) {
		auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
		assert (ptrn !is null);
		*ptrn ~= data;
	}
	/// Returns the length of pattern identified by `ptrnID`.
	uint getCurrentPos(uint ptrnID) {
		auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
		assert (ptrn !is null);
		return cast(uint)(ptrn.length);
	}
	/** 
	 * Flushes the emit string as a command string.
	 * Params:
	 *   ptrnID = The pattern to which the emit string belongs to.
	 *   devNum = The device targeted by the emit command.
	 */
	void flushEmitStr(uint ptrnID, ushort devNum) {
		if (currEmitStr.length) {
			auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
			assert (ptrn !is null);
			//*ptrn ~= [(0x03<<24) | (cast(uint)(currEmitStr.length<<16)) | currDevNum] ~ currEmitStr;
			*ptrn ~= [M2Command.emit(currEmitStr.length, devNum).word] ~ currEmitStr;
			currEmitStr.length = 0;
		}
	}
	/**
	 * Parses pattern data.
	 * Params:
	 *   wholeLine = The unprocessed line as is.
	 *   words = Each command words separated by whitespace.
	 *   ptrnID = Pattern identifier.
	 */
	void parsePattern(string wholeLine, string[] words, uint ptrnID) {
		if (words.length == 0) return;		//There are no useful words on this line after comment removal, skip
		if (words[0] == "END") {			//Pattern end hit, set context to init, flush emit string, then return
			context = Context.init;
			flushEmitStr(ptrnID, currDevNum);
			enforce(!ptrnData[$-1].unresolvedLabels.length, "Unresolved position markers found!");
			return;
		}
		if (words[0][0] == '@') {			//Position marker hit, parse it!
			const sizediff_t endOfJumpLabel = countUntil(words[0], ':');
			enforce(endOfJumpLabel != -1, "Malformated jump label!");
			string positionLabel = words[0][1..endOfJumpLabel];
			enforce(!ptrnData[$-1].positionLabels.has(positionLabel), "Position label duplicate found!");//Check if position marker exists already, error out if yes
			ptrnData[$-1].positionLabels[positionLabel] = result.songdata.ptrnData[ptrnID].length;//Store the new position marker
			const sizediff_t unresolvedPosMrk = ptrnData[$-1].searchUnresolvedPositionLabelByName(positionLabel);//Check if anything else before have referenced it
			if (unresolvedPosMrk != -1) {	//Resolve any position markers found.
				auto ptrn = result.songdata.ptrnData[ptrnID];
				uint position;
				foreach (uint[2] key ; ptrnData[$-1].unresolvedLabels[unresolvedPosMrk].positions) {
					position = key[1];
					sizediff_t jumpAmount = ptrnData[$-1].positionLabels[positionLabel] - position - 3;
					debug assert(jumpAmount > 0);
					ptrn[position] = cast(int)jumpAmount;
				}
				ptrnData[$-1].unresolvedLabels = remove(ptrnData[$-1].unresolvedLabels, unresolvedPosMrk);
			}
		} else if (words[0][0] == '[') {	//Emit command
			parseEmitCmd(wholeLine, words, ptrnID);
		} else {							//Misc command (control, math, etc.)
			flushEmitStr(ptrnID, currDevNum);
			parseMiscCmd(wholeLine, words, ptrnID);
		}
	}
	/** 
	 * Inserts a MIDI 2.0 command with optional register emit commands
	 * Params:
	 *   longfield = If true, then field 2 and 3 are parsed as two 7 bit field making a 14 bit one.
	 *   note = If true, then the command is being treated as a note.
	 *   cmdCode = Command identifier code.
	 *   chField = Channel field of the command.
	 *   upperField = Field 2 of the command.
	 *   lowerField = Field 3 of the command.
	 *   valueField = The value field of the command.
	 *   aux = Auxilliary field of the command, primarily used for note commands
	 *   ptrnID = Pattern ID.
	 *   devNum = Device number.
	 */
	void insertMIDI2Cmd(const bool longfield, const bool note, const ubyte cmdCode, string chField, string upperField, 
			string lowerField, string valueField, string aux, uint ptrnID, ushort devNum) {
		uint emitWithRegVal;
		int rCh, rNote, rValue, rAux = -1;
		uint value, upper, lower, channel;
		UMP midiCMD;
		if (note) {
			rValue = parseRegister(valueField);
			if (rValue == -1) { 
				rValue = 0;
				value = (cast(uint)parsenum(valueField))<<16;
			} else {
				emitWithRegVal |= 0x08;
			}
			if (aux.length) {
				if (aux.length >= 4) {
					switch (aux[0..2]) {
						case "ms": lower = 0x01; break;
						case "ps": lower = 0x02; break;
						case "pt": lower = 0x03; break;
						default: break;
					}
					rAux = parseRegister(aux[3..$]);
					if (rAux == -1) {
						rAux = 0;
						value |= cast(uint)parsenum(aux[3..$]);
					} else {
						emitWithRegVal |= 0x01;
					}
				}
			}
		} else {
			rValue = parseRegister(valueField);
			if (rValue == -1) {
				rValue = 0;
				value = cast(uint)parsenum(valueField);
			} else {
				emitWithRegVal |= 0x08;
			}
		}
		if (longfield) {
			rNote = parseRegister(upperField);
			if (rNote == -1) {
				rNote = 0;
				const uint lf = cast(uint)parsenum(upperField);
				lower = lf>>7;
				upper = lf & 0x7F;
			} else {
				emitWithRegVal |= 0x04;
			}
		} else {
			if (upperField.length) {
				rNote = parseRegister(upperField);
				if (rNote == -1) {
					rNote = 0;
					if (note) {
						upper = cast(uint)parseNote(upperField);
					} 
				} else {
					emitWithRegVal |= 0x04;
				}
			}
			if (lowerField.length) {
				rAux = parseRegister(lowerField);
				if (rAux == -1) {
					rAux = 0;
					lower = cast(uint)parsenum(lowerField);
				} else {
					emitWithRegVal |= 0x01;
				}
			}
		}
		rCh = parseRegister(chField);
		if (rCh != -1) emitWithRegVal |= 0x02;
		else channel = cast(uint)parsenum(chField);
		if (emitWithRegVal) {
			flushEmitStr(ptrnID, devNum);
			midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), cmdCode, cast(ubyte)(channel&0x0F), 
					cast(ubyte)upper, cast(ubyte)lower);
			M2Command cmdUprHl = M2Command([OpCode.emit_r, cast(ubyte)rValue, 0, 0]);
			cmdUprHl.hwords[1] = cast(ushort)currDevNum;
			M2Command cmdLwrHl = M2Command([cast(ubyte)rNote, cast(ubyte)rCh, cast(ubyte)rAux, cast(ubyte)emitWithRegVal]);
			writeCmdStr(ptrnID, [cmdUprHl.word, cmdLwrHl.word, midiCMD.base, value]);
			//currEmitStr ~= [cmdUprHl.word, cmdLwrHl.word, midiCMD.base, value];
		} else {
			midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), cmdCode, cast(ubyte)(channel&0x0F), 
					cast(ubyte)upper, cast(ubyte)lower);
			currEmitStr ~= [midiCMD.base, value];
		}
	}
	/** 
	 * Parses MIDI emit commands.
	 * Params:
	 *   wholeLine = The unprocessed line as is.
	 *   words = Each command words separated by whitespace.
	 *   ptrnID = Pattern identifier.
	 */
	void parseEmitCmd(string wholeLine, string[] words, uint ptrnID) {
		const sizediff_t f = countUntil(words[0], '['), t = countUntil(words[0], ']');
		enforce(f >= 0 && t >= 0 && t > f, "Malformed emit string!");
		const uint deviceNum = cast(uint)parsenum(words[0][f + 1..t]);
		enforce(deviceNum <= 65_535, "Device number too large");
		if (currEmitStr.length > 251 || currDevNum != deviceNum) flushEmitStr(ptrnID, currDevNum);//flush emit string if it's not guaranteed that a 4 word long data won't fit, or device isn't equal
		currDevNum = cast(ushort)deviceNum;
		switch (words[1]) {
			case "note":		//note macro, inserts a note on, then a note off command after a set time
				const uint channel = cast(uint)parsenum(words[2]);
				const uint vel = cast(uint)parseVelocityM2(words[3]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 65_535, "Velocity number too high");
				if (words[4][0] == '~') {	//use the same duration to all the notes
					const ulong noteDur = parseRhythm(words[4][1..$], ptrnData[$-1].currBPM, result.songdata.ticsPerSecs);
					for (int j = 5 ; j < words.length ; j++) {
						const uint note = parseNote(words[j]);
						UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
								cast(ubyte)note);
						currEmitStr ~= [midiCMD.base, vel<<16];
						noteMacroHandler.put(NoteData(deviceNum, cast(ubyte)channel, cast(ubyte)note, cast(ushort)vel, timePos, 
								timePos + noteDur));
					}
				} else {	//each note should have their own duration
					for (int j = 4 ; j < words.length ; j++) {
						string[] notebase = words[j].split(":");
						const ulong noteDur = parseRhythm(notebase[0], ptrnData[$-1].currBPM, result.songdata.ticsPerSecs);
						const uint note = parseNote(notebase[1]);
						UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
								cast(ubyte)note);
						currEmitStr ~= [midiCMD.base, vel<<16];
						noteMacroHandler.put(NoteData(deviceNum, cast(ubyte)channel, cast(ubyte)note, cast(ushort)vel, timePos, 
								timePos + noteDur));
					}
				}
				break;

			//MIDI 1.0 begin
			case "m1_nf":		//MIDI 1.0 note off
				const uint channel = cast(uint)parsenum(words[2]);
				const uint note = parseNote(words[3]);
				const uint vel = cast(uint)parseVelocityM1(words[4]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 127, "Velocity number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.NoteOff, cast(ubyte)(channel&0x0F), 
						cast(ubyte)note, cast(ubyte)vel);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_nn":		//MIDI 1.0 note on
				const uint channel = cast(uint)parsenum(words[2]);
				const uint note = parseNote(words[3]);
				const uint vel = cast(uint)parseVelocityM1(words[4]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 127, "Velocity number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
						cast(ubyte)note, cast(ubyte)vel);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_ppres":		//MIDI 1.0 poly pressure
				const uint channel = cast(uint)parsenum(words[2]);
				const uint note = parseNote(words[3]);
				const uint vel = cast(uint)parseVelocityM1(words[4]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 127, "Velocity number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.PolyAftrTch, cast(ubyte)(channel&0x0F), 
						cast(ubyte)note, cast(ubyte)vel);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_cc":			//MIDI 1.0 control change
				const uint channel = cast(uint)parsenum(words[2]);
				const uint num = cast(uint)parsenum(words[3]);
				const uint vel = cast(uint)parseVelocityM1(words[4]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 127, "Velocity number too high");
				enforce(num <= 127, "Control number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.CtrlCh, cast(ubyte)(channel&0x0F), 
						cast(ubyte)num, cast(ubyte)vel);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_pc":			//MIDI 1.0 program change
				const uint channel = cast(uint)parsenum(words[2]);
				const uint num = cast(uint)parsenum(words[3]);
				//const uint vel = cast(uint)parsenum(words[4]);
				enforce(channel <= 255, "Channel number too high");
				//enforce(vel <= 127, "Velocity number too high");
				enforce(num <= 127, "Program number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.PrgCh, cast(ubyte)(channel&0x0F), 
						cast(ubyte)num, cast(ubyte)0);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_cpres":			//MIDI 1.0 channel pressure
				const uint channel = cast(uint)parsenum(words[2]);
				const uint vel = cast(uint)parsenum(words[3]);
				//const uint vel = cast(uint)parsenum(words[4]);
				enforce(channel <= 255, "Channel number too high");
				enforce(vel <= 127, "Velocity number too high");
				//enforce(num <= 127, "Program number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.ChAftrTch, cast(ubyte)(channel&0x0F), 
						cast(ubyte)vel, cast(ubyte)0);
				currEmitStr ~= [midiCMD.base];
				break;
			case "m1_pb":		//MIDI 1.0 pitch bend
				const uint channel = cast(uint)parsenum(words[2]);
				const uint amount = cast(uint)parsenum(words[3]);
				enforce(channel <= 255, "Channel number too high");
				enforce(amount <= 16_383, "Velocity number too high");
				UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.NoteOff, cast(ubyte)(channel&0x0F), 
						cast(ubyte)(amount>>7), cast(ubyte)(amount & 0x7F));
				currEmitStr ~= [midiCMD.base];
				break;
			//MIDI 1.0 end
			//MIDI 2.0 start
			case "nf":			//MIDI note off
				
				string auxField;
				if (words.length == 6) auxField = words[5];
				insertMIDI2Cmd(false, true, MIDI2_0Cmd.NoteOff, words[2], words[4], null, words[3], auxField, ptrnID, currDevNum);
				break;
			case "nn":			//MIDI note on
				
				string auxField;
				if (words.length == 6) auxField = words[5];
				insertMIDI2Cmd(false, true, MIDI2_0Cmd.NoteOn, words[2], words[4], null, words[3], auxField, ptrnID, currDevNum);
				break;
			case "ppres":		//Poly aftertouch
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.PolyAftrTch, words[2], words[4], null, words[3], null, ptrnID, currDevNum);
				break;
			case "pccr":		//Poly registered per-note controller change
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.PolyCtrlChR, words[2], words[3], words[4], words[5], null, ptrnID, 
						currDevNum);
				break;
			case "pcca":		//Poly assignable per-note controller change
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.PolyCtrlCh, words[2], words[3], words[4], words[5], null, ptrnID, 
						currDevNum);
				break;
			case "pnoteman":	//Poly management message
				const uint channel = cast(uint)parsenum(words[2]);
				const uint note = parseNote(words[3]);
				uint option;
				if (words.length >= 5) {
					option |= countUntil(words[4], "S", "s") != -1 ? 0x01 : 0;
					option |= countUntil(words[4], "D", "d") != -1 ? 0x02 : 0;
				}
				enforce(channel <= 255, "Channel number too high");
				//currEmitStr ~= [0x20_F0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8) | option, 0];
				UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.NoteManaMsg, cast(ubyte)(channel & 0x0F), 
						cast(ubyte)note, cast(ubyte)option);
				currEmitStr ~= [midiCMD.base, 0];
				break;
			case "ccl":			//Legacy controller change
				
				insertMIDI2Cmd(true, false, MIDI2_0Cmd.CtrlChOld, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			case "ccr":
				insertMIDI2Cmd(true, false, MIDI2_0Cmd.CtrlChR, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			case "cc":
				insertMIDI2Cmd(true, false, MIDI2_0Cmd.CtrlCh, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			case "rccr":
				insertMIDI2Cmd(true, false, MIDI2_0Cmd.RelCtrlChR, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			case "rcc":
				insertMIDI2Cmd(true, false, MIDI2_0Cmd.RelCtrlCh, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			case "pc":			//Program change
				const uint channel = cast(uint)parsenum(words[2]);
				const uint prg = cast(uint)parsenum(words[3]);
				uint option, bank;
				if (words.length >= 5) {
					option = 1;
					const uint bank0 = cast(uint)parsenum(words[4]);
					enforce(bank0 <= 16_383, "Bank number too high");
					bank = ((bank0 & 0x3F_80)<<1) | (bank0 & 0x7F);
				}
				enforce(prg <= 127, "Program number too high");
				/* currEmitStr ~= [0x20_C0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (prg<<8) | option, 
						(prg<<24) | bank]; */
				UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.PrgCh, cast(ubyte)(channel & 0x0F), 0, 
						cast(ubyte)option);
				currEmitStr ~= [midiCMD.base, (prg<<24) | bank];
				//writeCmdStr(ptrnID, [midiCMD.base, (prg<<24) | bank]);
				break;
			case "cpres":		//Channel aftertouch
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.ChAftrTch, words[2], null, null, words[3], null, ptrnID, currDevNum);
				break;
			case "pb":			//Pitch bend
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.PitchBend, words[2], null, null, words[3], null, ptrnID, currDevNum);
				break;
			case "ppb":			//Poly pitch bend
				
				insertMIDI2Cmd(false, false, MIDI2_0Cmd.PitchBend, words[2], words[3], null, words[4], null, ptrnID, currDevNum);
				break;
			//MIDI 2.0 end
			default:
				break;
		}
	}
	/** 
	 * Inserts a math command done on the registers.
	 * Params:
	 *   ptrnID = Identifier of the currently parsed pattern.
	 *   cmdCode = Command code to be written.
	 *   instr = Instruction words, like register numbers, etc.
	 */
	void insertMathCmd(uint ptrnID, const ubyte cmdCode, string[] instr) {
		//enforce(instr.length == 3, "Incorrect number of registers");
		const int ra = parseRegister(instr[0]);
		const int rb = parseRegister(instr[1]);
		const int rd = parseRegister(instr[2]);
		//enforce((ra|rb|rd) <= -1, "Bad register number");
		writeCmdStr(ptrnID, [M2Command([cmdCode, cast(ubyte)ra, cast(ubyte)rb, cast(ubyte)rd]).word]);
	}
	/** 
	 * Inserts a shift by immediate command.
	 * Params:
	 *   ptrnID = Identifier of the currently parsed pattern.
	 *   cmdCode = Command code to be written.
	 *   instr = Instruction words, like register numbers, etc.
	 */
	void insertShImmCmd(uint ptrnID, const ubyte cmdCode, string[] instr) {
		//enforce(instr.length == 3, "Incorrect number of registers");
		const int ra = parseRegister(instr[0]);
		const int rb = cast(int)parsenum(instr[1]);
		const int rd = parseRegister(instr[2]);
		enforce(rb <= 31 && rb >= 0, "Bad immediate amount");
		writeCmdStr(ptrnID, [M2Command([cast(ubyte)cmdCode, cast(ubyte)ra, cast(ubyte)rb, cast(ubyte)rd]).word]);
	}
	/** 
	 * Inserts a two operand command.
	 * Params:
	 *   ptrnID = Identifier of the currently parsed pattern.
	 *   cmdCode = Command code to be written.
	 *   instr = Instruction words, like register numbers, etc.
	 */
	void insertTwoOpCmd(uint ptrnID, const ubyte cmdCode, string[] instr) {
		//enforce(instr.length == 2, "Incorrect number of registers");
		const int ra = parseRegister(instr[0]);
		const int rd = parseRegister(instr[1]);
		writeCmdStr(ptrnID, [M2Command([cmdCode, cast(ubyte)ra, cast(ubyte)0x00, cast(ubyte)rd]).word]);
	}
	/** 
	 * Inserts a compare instruction.
	 * Params:
	 *   ptrnID = Identifier of the currently parsed pattern.
	 *   cmprCode = Comparison code.
	 *   instr = Registers to be parsed.
	 */
	void insertCmpInstr(uint ptrnID, const ubyte cmprCode, string[] instr) {
		//enforce(instr.length == 2, "Incorrect number of registers");
		const int ra = parseRegister(instr[0]);
		const int rb = parseRegister(instr[1]);
		writeCmdStr(ptrnID, [M2Command([OpCode.cmp, cmprCode, cast(ubyte)ra, cast(ubyte)rb]).word]);
	}
	/** 
	 * Inserts a jump command. Automatically calculates the delta for the jump instruction if jump label is encountered, or records an unresolved jump if not.
	 * Params:
	 *   ptrnID = Identifier of the currently parsed pattern.
	 *   cmdCode = The command code of the jump instruction.
	 *   instr = Position label and the condition mask for further parsing.
	 */
	void insertJmpCmd(uint ptrnID, uint cmdCode, string[] instr) {
		//enforce(key.positionLabels.has(instr[1]), "Position label not found");
		//flushEmitStr();
		int targetAm;
		const uint conditionMask = cast(uint)parsenum(instr[0]);
		const uint currPos = getCurrentPos(ptrnID);
		if (ptrnData[$-1].positionLabels.has(instr[1])) {	//Previous label have been processed.
			targetAm = cast(int)(ptrnData[$-1].positionLabels[instr[1]] - currPos);
		} else {											//Label is likely ahead.
			sizediff_t unresPos = ptrnData[$-1].searchUnresolvedPositionLabelByName(instr[1]);
			if (unresPos == -1) {							//Unresolved position haven't yet hit, add it
				ptrnData[$-1].unresolvedLabels ~= UnresolvedPositionLabel(instr[1], [[0, currPos]]);
				//unresPos = ptrnData[$-1].unresolvedLabels.length - 1;
			} else {
				ptrnData[$-1].unresolvedLabels[unresPos].positions ~= [0, currPos];
			}
		}
		writeCmdStr(ptrnID, [cmdCode, conditionMask, cast(uint)targetAm]);
	}
	/** 
	 * Inserts a wait command, also resolves any potential note macros.
	 * Params:
	 *   amount = The amount of wait.
	 *   ptrnID = Pattern identifier.
	 */
	void insertWaitCmd(ulong amount, uint ptrnID) {
		if (amount) {
			auto ptrn = result.songdata.ptrnData.ptrOf(ptrnID);
			assert (ptrn !is null);
			if (amount <= 0xFF_FF_FF) {	//Short wait
				*ptrn ~= M2Command.cmd24bit(OpCode.shwait, cast(uint)amount).word;
			} else {					//Long wait
				*ptrn ~= [M2Command.cmd24bit(OpCode.lnwait, cast(uint)(amount)).word, cast(uint)(amount>>24L)];
			}
		}
	}
	/** 
	 * Inserts a chain command.
	 * Params:
	 *   type = Chain command code.
	 *   ptrnName = The name of the to be chained-in command. If not found, issues a resolve request.
	 *   ptrnID = Identifier of the current pattern.
	 */
	void insertChainCmd(ubyte type, string ptrnName, uint ptrnID) {
		sizediff_t patternID = searchPatternByName(ptrnName);
		if (patternID == -1) {	//Pattern not found, check if resolve notice have filled for it already
			const uint currPos = getCurrentPos(ptrnID);
			sizediff_t unresolvedPatternID = searchUnresolvedPatternByName(ptrnName);
			if (unresolvedPatternID == -1) {
				unresolvedPatterns ~= UnresolvedPositionLabel(ptrnName, [[ptrnID, currPos]]);
			} else {
				unresolvedPatterns[unresolvedPatternID].positions ~= [ptrnID, currPos];
			}
			writeCmdStr(ptrnID, [M2Command.cmd24bit(type, 0).word]);
		} else {				//Pattern found
			writeCmdStr(ptrnID, [M2Command.cmd24bit(type, cast(uint)patternID).word]);
		}
	}
	/** 
	 * Parses any pattern command that isn't note emit, end of pattern, or position label.
	 * Params:
	 *   wholeLine = The unprocessed line as is.
	 *   words = Each command words separated by whitespace.
	 *   ptrnID = Pattern identifier.
	 */
	void parseMiscCmd(string wholeLine, string[] words, uint ptrnID) {
		switch (words[0]) {
			case "wait":		//parse wait command
				long amount;
				try {	//Try to parse it as a number
					amount = parsenum(words[1]);
				} catch (Exception e) {	//It is not a number, try to parse it as a rhythm
					amount = parseRhythm(words[1], ptrnData[$-1].currBPM, result.songdata.ticsPerSecs);
				}
				//go through all the note macros if any of them have expired, and insert one or more wait commands if needed
				while (amount > 0) {
					flushEmitStr(ptrnID, currDevNum);
					size_t num;
					long lowestAmount;
					if (noteMacroHandler.length) {
						//check if there's any expired note macros
						if (noteMacroHandler[0].durTo <= timePos + amount) {
							num = 1;
							//get current lowest amount
							lowestAmount = amount - (timePos + amount - noteMacroHandler[0].durTo);
							assert (lowestAmount >= 0);
							//check if there's more with the same amount
							for (size_t searchPos = 1 ; searchPos < noteMacroHandler.length ; searchPos++) {
								if (noteMacroHandler[0].durTo == noteMacroHandler[searchPos].durTo) {
									num = searchPos + 1;
								} else {
									break;	//Break immediately on different wait times
								}
							}
						}
					}
					for (size_t outputPos ; outputPos < num ; outputPos++) {	//emit all expired note macros
						NoteData nd = noteMacroHandler.remove(0);
						currEmitStr ~= [UMP(MessageType.MIDI2, nd.ch>>4, MIDI2_0Cmd.NoteOff, nd.ch & 0x0F, nd.note).base, nd.velocity];
						if (currEmitStr.length >= 254) flushEmitStr(ptrnID, currDevNum);
					}
					if (!num) {			//if there's no (more) expired note macros, then just simply emit a wait command with the current amount
						insertWaitCmd(amount, ptrnID);
						timePos += amount;
						amount = 0;
					} else {				//if there's some, insert wait command, and subtract 
						insertWaitCmd(lowestAmount, ptrnID);
						timePos += lowestAmount;
						amount -= lowestAmount;
					}
				}
				break;
			case "chain-par":
				insertChainCmd(0x05, words[1], ptrnID);
				break;
			case "chain-ser":
				insertChainCmd(0x06, words[1], ptrnID);
				break;
			case "chain":
				insertChainCmd(0x41, words[1], ptrnID);
				break;
			case "jmpnc", "jmp":
				insertJmpCmd(ptrnID, 0x04, words[1..$]);
				break;
			case "jmpeq":
				insertJmpCmd(ptrnID, 0x0104, words[1..$]);
				break;
			case "jmpne":
				insertJmpCmd(ptrnID, 0x0204, words[1..$]);
				break;
			case "jmpsh":
				insertJmpCmd(ptrnID, 0x0304, words[1..$]);
				break;
			case "jmpop":
				insertJmpCmd(ptrnID, 0x0404, words[1..$]);
				break;
			case "add": 
				insertMathCmd(ptrnID, OpCode.add, words[1..$]);
				break;
			case "sub":
				insertMathCmd(ptrnID, OpCode.sub, words[1..$]);
				break;
			case "mul":
				insertMathCmd(ptrnID, OpCode.mul, words[1..$]);
				break;
			case "div":
				insertMathCmd(ptrnID, OpCode.div, words[1..$]);
				break;
			case "mod":
				insertMathCmd(ptrnID, OpCode.mod, words[1..$]);
				break;
			case "and":
				insertMathCmd(ptrnID, OpCode.and, words[1..$]);
				break;
			case "or":
				insertMathCmd(ptrnID, OpCode.or, words[1..$]);
				break;
			case "xor":
				insertMathCmd(ptrnID, OpCode.xor, words[1..$]);
				break;
			case "not":
				insertTwoOpCmd(ptrnID, OpCode.not, words[1..$]);
				break;
			case "lshi": 
				insertShImmCmd(ptrnID, OpCode.lshi, words[1..$]);
				break;
			case "rshi": 
				insertShImmCmd(ptrnID, OpCode.rshi, words[1..$]);
				break;
			case "rasi": 
				insertShImmCmd(ptrnID, OpCode.rasi, words[1..$]);
				break;
			case "adds": 
				insertMathCmd(ptrnID, OpCode.adds, words[1..$]);
				break;
			case "subs": 
				insertMathCmd(ptrnID, OpCode.subs, words[1..$]);
				break;
			case "muls": 
				insertMathCmd(ptrnID, OpCode.muls, words[1..$]);
				break;
			case "divs": 
				insertMathCmd(ptrnID, OpCode.divs, words[1..$]);
				break;
			case "lsh": 
				insertMathCmd(ptrnID, OpCode.lsh, words[1..$]);
				break;
			case "rsh": 
				insertMathCmd(ptrnID, OpCode.rsh, words[1..$]);
				break;
			case "ras": 
				insertMathCmd(ptrnID, OpCode.ras, words[1..$]);
				break;
			case "mov":
				insertTwoOpCmd(ptrnID, OpCode.mov, words[1..$]);
				break;
			case "cmpeq":
				insertCmpInstr(ptrnID, CmpCode.eq, words[1..$]);
				break;
			case "cmpne":
				insertCmpInstr(ptrnID, CmpCode.ne, words[1..$]);
				break;
			case "cmpgt":
				insertCmpInstr(ptrnID, CmpCode.gt, words[1..$]);
				break;
			case "cmpge":
				insertCmpInstr(ptrnID, CmpCode.ge, words[1..$]);
				break;
			case "cmplt":
				insertCmpInstr(ptrnID, CmpCode.lt, words[1..$]);
				break;
			case "cmple":
				insertCmpInstr(ptrnID, CmpCode.le, words[1..$]);
				break;
			case "cmpze":
				insertCmpInstr(ptrnID, CmpCode.ze, words[1..$]);
				break;
			case "cmpnz":
				insertCmpInstr(ptrnID, CmpCode.nz, words[1..$]);
				break;
			case "cmpng":
				insertCmpInstr(ptrnID, CmpCode.ng, words[1..$]);
				break;
			case "cmppo":
				insertCmpInstr(ptrnID, CmpCode.po, words[1..$]);
				break;
			case "cmpsgt":
				insertCmpInstr(ptrnID, CmpCode.sgt, words[1..$]);
				break;
			case "cmpsge":
				insertCmpInstr(ptrnID, CmpCode.sge, words[1..$]);
				break;
			case "cmpslt":
				insertCmpInstr(ptrnID, CmpCode.slt, words[1..$]);
				break;
			case "cmpsle":
				insertCmpInstr(ptrnID, CmpCode.sle, words[1..$]);
				break;
			case "ctrl":
				M2Command ctrlCMD = M2Command([OpCode.ctrl, 0, 0, 0]);
				switch (words[1]) {
					case "setReg":
						ctrlCMD.bytes[1] = CtrlCmdCode.setRegister;
						ctrlCMD.bytes[2] = cast(ubyte)parseRegister(words[2]);
						uint val = cast(uint)parsenum(words[3]);
						writeCmdStr(ptrnID, [ctrlCMD.word, val]);
						break;
					default:
						break;
				}
				break;
			case "display":
				M2Command displCMD = M2Command([OpCode.display, 0, 0, 0]);
				switch (words[1]) {
					case "BPM":
						displCMD.bytes[1] = DisplayCmdCode.setVal;
						displCMD.hwords[1] = SetDispValCode.BPM;
						ptrnData[$-1].currBPM = to!float(words[2]);
						writeCmdStr(ptrnID, [displCMD.word, *cast(uint*)&ptrnData[$-1].currBPM]);
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}
	///Compiles the assembly into a binary which is returned. Throws an exception if errors were found.
	M2File compile() {
		string[] lines = input.splitLines;
		enforce(lines[0][0..12] == "MIDI2.0 VER " && lines[0][12] == '1', "Wrong version or file!");
		for (size_t lineNum = 1 ; lineNum < lines.length ; lineNum++) {
			string[] words = removeComment(lines[lineNum]).split!isWhite();
			if (!words.length) continue;		//If line does not contain any data, skip it completely.
			switch (context) {
				case Context.headerParse:		//Header parse start
					switch (words[0]) {
						case "timeFormatID":
							switch (words[1]) {
								case "ms", "fmt0":
									result.timeFormat = M2TimeFormat.ms;
									break;
								case "us", "fmt1":
									result.timeFormat = M2TimeFormat.us;
									break;
								case "hns", "fmt2":
									result.timeFormat = M2TimeFormat.hns;
									break;
								case "fmt3":
									result.timeFormat = M2TimeFormat.fmt3;
									break;
								case "fmt4":
									result.timeFormat = M2TimeFormat.fmt4;
									break;
								case "fmt5":
									result.timeFormat = M2TimeFormat.fmt5;
									break;
								default:
									throw new Exception("Unrecognized format!");
							}
							break;
						case "timeFormatPeriod":
							result.timeFrmtPer = cast(uint)parsenum(words[1]);
							break;
						case "timeFormatRes":
							result.timeFrmtRes = cast(uint)parsenum(words[1]);
							break;
						case "maxPattern":
							result.patternNum = cast(ushort)parsenum(words[1]);
							break;
						case "END":
							result.songdata = M2Song(result.patternNum, result.timeFormat, result.timeFrmtPer, result.timeFrmtRes);
							context = Context.init;
							break;
						default:
							break;
					}
					break;						//Header parse end
				case Context.arrayParse:
					if (words[0] == "END") context = Context.init;
					else result.songdata.arrays[$-1] ~= cast(uint)parsenum(words[0]);
					break;
				case Context.metadataParse:
					if (words[0] == "END") context = Context.init;	//TODO: Implement proper metadata handling
					break;
				case Context.deviceParse:
					if (words[0] == "END") {
						context = Context.init;
					} else {
						const ushort devID = cast(ushort)parsenum(words[$ - 1]);
						result.devicelist[devID] = words[0][0..$ - 1];
					}
					break;
				case Context.patternParse:
					parsePattern(lines[lineNum], words, currPatternID);//Put pattern parsing into its own function since it's the most complicated part of the parsing
					break;
				default:						//Check for new context.
					switch (words[0]) {	
					case "HEADER":
						context = Context.headerParse;
						break;
					case "METADATA":
						context = Context.metadataParse;
						break;
					case "DEVLIST":
						context = Context.deviceParse;
						break;
					case "ARRAY":
						context = Context.arrayParse;
						arrayNames ~= words[1];
						result.songdata.arrays ~= [];
						break;
					case "PATTERN":
						context = Context.patternParse;
						if (words[1] == "main") {
							currPatternID = 0;
						} else {
							currPatternID = patternCntr;
							patternCntr++;
						}
						ptrnData ~= PatternData(words[1], lineNum, currPatternID);
						result.songdata.ptrnData[currPatternID] = [];
						//Resolve any potential previously unrecognized pattern references
						sizediff_t unresolvedPatternID = searchUnresolvedPatternByName(words[1]);
						if (unresolvedPatternID != -1) {
							const uint cmdOvrWrite = currPatternID<<8;
							foreach (uint[2] position; unresolvedPatterns[unresolvedPatternID].positions) {
								uint origCmd = readCmd(position[0], position[1]);
								overwriteCmdAt(position[0], origCmd | cmdOvrWrite, position[1] - 1);
							}
							unresolvedPatterns = remove(unresolvedPatterns, unresolvedPatternID);
						}
						break;
					default:
						break;
				}
					break;
			}
		}
		enforce(context == Context.init, "Scope end have not reached");
		enforce(unresolvedPatterns.length == 0, "One or more unresolved pattern references were found");
		return result;
	}
}
