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
import collections.sortedlist;
import midi2.types.enums;
import midi2.types.structs;

package string toAllCaps(string s) @safe nothrow {
	string result;
	result.reserve = s.length;
	for (int i = 0; i < s.length ; i++) {
		result ~= s[i] >= 0x61 && s[i] <= 0x7A ? s[i] & 0x5F : s[i];
	}
	return result;
}
package long parsenum(string s) {
	if (s.startsWith("0x")) {
		return s[2..$].to!long(16);
	} else {
		return s.to!long;
	}
}
package string removeComment(string s) {
	const ptrdiff_t commentPos = countUntil(s, ";");
	if (commentPos == -1) return s;
	return s[0..commentPos];
}
package int parseNote(string n) {
	//return cast(int)countUntil(NOTE_LOOKUP_TABLE, n);
	n = toAllCaps(n);
	for (int i = 0; i < 128 ; i++) {
		if (NOTE_LOOKUP_TABLE[i] == n) return i;
	}
	return cast(int)parsenum(n);
}
package int parseRegister(const string s) {
	if (s[0] == 'R') {
		try
			return s[1..$].to!int(16);
		catch (Exception e) {}
	}
	return -1;
}
package double getRhythmDur(const char c) @nogc @safe pure nothrow {
	switch (c) {
		case 'W': return 1.0;
		case 'H': return 1.0 / 2;
		case 'Q': return 1.0 / 4;
		case 'O': return 1.0 / 8;
		case 'S': return 1.0 / 16;
		case 'T': return 1.0 / 32;
		case 'I': return 1.0 / 64;
		case 'X': return 1.0 / 128;
		case 'Y': return 1.0 / 256;
		case 'Z': return 1.0 / 512;
		case 'U': return 1.0 / 1024;
		default: return double.nan;
	}
}
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
package ulong parseRhythm(string n, float bpm, long timebase) {
	const long whNoteLen = cast(long)((1_000_000_000 / cast(double)timebase) * (15 / bpm));
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
///Reads textual M2 files and compiles them into binary.
public M2File loadM2FromText(string src) {
	
	enum Context {
		init,
		headerParse,
		metadataParse,
		deviceParse,
		patternParse,
		stringParse,
	}
	struct PatternData {
		string name;
		size_t lineNum;
		uint lineLen;
		float currBPM = 120;
		size_t[string] positionLabels;
	}
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
	M2File result;
	Context context, prevContext;
	string parsedString;
	string[] lines = src.splitLines;
	PatternData[] ptrnData;
	sizediff_t searchPatternByName(const string name) @nogc @safe pure nothrow const {
		for (sizediff_t i = 0; i < ptrnData.length ; i++) {
			if (ptrnData[i].name == name)
				return i;
		}
		return -1;
	}
	//Validate file
	enforce(lines[0][0..12] == "MIDI2.0 VER " && lines[0][12] == '1', "Wrong version or file!");
	//First pass: parse header, etc.
	for (size_t lineNum = 1 ; lineNum < lines.length ; lineNum++) {
		string[] words = removeComment(lines[lineNum]).split!isWhite();
		if (!words.length) continue;
		switch (context) {
			case Context.patternParse:
				if (words[0] == "END") {	//Calculate line numbers then close current pattern parsing.
					ptrnData[$-1].lineLen = cast(uint)(lineNum - ptrnData[$-1].lineNum - 1);
					context = Context.init;
				} else if (startsWith(words[0], "@")) {
					ptrnData[$-1].positionLabels[words[0][1..$]] = lineNum;
				}
				break;
			case Context.headerParse:
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
						context = Context.init;
						break;
					default:
						break;
				}
				break;
			case Context.metadataParse:
				if (words[0] == "END") context = Context.init;
				break;
			case Context.deviceParse:
				if (words[0] == "END") context = Context.init;
				else {
					const ushort devID = cast(ushort)parsenum(words[$ - 1]);
					result.devicelist[devID] = words[0][0..$ - 1];
				}
				break;
			default:
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
					case "PATTERN":
						context = Context.patternParse;
						ptrnData ~= PatternData(words[1], lineNum, 0);
						break;

					default:
						break;
				}
				break;
		}
			
	}
	//check if a main pattern is present, raise an error if it doesn't exist, or set it as the first if it's not already
	if (ptrnData[0].name != "main") {
		bool mainExists;
		for (int i = 1 ; i < ptrnData.length ; i++) {
			if (ptrnData[i].name == "main") {
				mainExists = true;
				ptrnData = ptrnData[i] ~ ptrnData[0..i] ~ ptrnData[i + 1..$];
				break;
			}
		}
		enforce(mainExists, "Entry point pattern doesn't exists");
	}
	//Initialize song data
	result.songdata = M2Song(result.patternNum, result.timeFormat, result.timeFrmtPer, result.timeFrmtRes);
	//Second pass: parse patterns
	foreach (size_t i, PatternData key; ptrnData) {
		result.songdata.ptrnData[cast(uint)i] = [];
		//NoteData[] noteMacroHandler;
		SortedList!(NoteData) noteMacroHandler;
		uint[] currEmitStr;
		uint currDevNum;
		float bpm = 120;
		ulong timepos;
		void flushEmitStr() {
			if (currEmitStr.length) {
				auto ptrn = result.songdata.ptrnData.ptrOf(cast(uint)i);
				assert (ptrn !is null);
				//*ptrn ~= [(0x03<<24) | (cast(uint)(currEmitStr.length<<16)) | currDevNum] ~ currEmitStr;
				*ptrn ~= [M2Command.emit(currEmitStr.length, currDevNum).word] ~ currEmitStr;
				currEmitStr.length = 0;
			}
		}
		void insertWaitCmd(ulong amount) {
			if (amount) {
				auto ptrn = result.songdata.ptrnData.ptrOf(cast(uint)i);
				assert (ptrn !is null);
				if (amount <= 0xFF_FF_FF) {	//Short wait
					*ptrn ~= M2Command.cmd24bit(OpCode.shwait, cast(uint)amount).word;
				} else {					//Long wait
					*ptrn ~= [M2Command.cmd24bit(OpCode.lnwait, cast(uint)(amount>>24)).word, cast(uint)amount];
				}
			}
		}
		void insertCmd(uint[] cmdStr) {
			if (cmdStr.length) {
				auto ptrn = result.songdata.ptrnData.ptrOf(cast(uint)i);
				assert (ptrn !is null);
				*ptrn ~= cmdStr;
			}
		}
		void insertJmpCmd(const sizediff_t currLineNum, uint cmdCode, string[] words) {
			const int targetAm = cast(int)(key.positionLabels[words[1]] - currLineNum);
			const uint conditionMask = cast(uint)parsenum(words[0]);
			insertCmd([cmdCode, conditionMask, targetAm]);
		}
		void insertMathCmd(const ubyte cmdCode, string[] words) {
			enforce(words.length == 3, "Incorrect number of registers");
			const int ra = parseRegister(words[0]);
			const int rb = parseRegister(words[1]);
			const int rd = parseRegister(words[2]);
			enforce((ra|rb|rd) <= -1, "Bad register number");
			insertCmd([M2Command([cmdCode, cast(ubyte)ra, cast(ubyte)rb, cast(ubyte)rd]).word]);
		}
		void insertShImmCmd(const ubyte cmdCode, string[] words) {
			enforce(words.length == 3, "Incorrect number of registers");
			const int ra = parseRegister(words[0]);
			const int rb = cast(int)parsenum(words[1]);
			const int rd = parseRegister(words[2]);
			enforce((ra|rd) <= -1, "Bad register number");
			enforce(rb <= 31 && rb >= 0, "Bad immediate amount");
			insertCmd([M2Command([cast(ubyte)cmdCode, cast(ubyte)ra, cast(ubyte)rb, cast(ubyte)rd]).word]);
		}
		void insertTwoOpCmd(const ubyte cmdCode, string[] words) {
			enforce(words.length == 2, "Incorrect number of registers");
			const int ra = parseRegister(words[0]);
			const int rd = parseRegister(words[1]);
			enforce((ra|rd) <= -1, "Bad register number");
			insertCmd([M2Command([cmdCode, cast(ubyte)ra, cast(ubyte)0x00, cast(ubyte)rd]).word]);
		}
		void insertCmpInstr(const ubyte cmprCode, string[] words) {
			enforce(words.length == 2, "Incorrect number of registers");
			const int ra = parseRegister(words[0]);
			const int rb = parseRegister(words[1]);
			enforce((ra|rb) <= -1, "Bad register number");
			insertCmd([M2Command([OpCode.cmp, cmprCode, cast(ubyte)ra, cast(ubyte)rb]).word]);
		}
		void insertMIDI2Cmd(bool longfield, bool note)(const ubyte cmdCode, string chField, string upperField, 
				string lowerField, string valueField, string aux) {
			uint emitWithRegVal;
			int rCh, rNote, rValue, rAux = -1;
			uint value, upper, lower, channel;
			static if (note) {
				rValue = parseRegister(valueField);
				if (rValue != -1) emitWithRegVal |= 0x08;
				else value = (cast(uint)parsenum(valueField))<<16;
				if (aux.length) {
					if (aux.length >= 4) {
						switch (aux[0..2]) {
							case "ms": lower = 0x01; break;
							case "ps": lower = 0x02; break;
							case "pt": lower = 0x03; break;
							default: break;
						}
						rAux = parseRegister(aux[3..$]);
						if (rAux != -1) emitWithRegVal |= 0x01;
						else value |= cast(uint)parsenum(aux[3..$]);
					}
				}
			} else {
				rValue = parseRegister(valueField);
				if (rValue != -1) emitWithRegVal |= 0x08;
				else value = cast(uint)parsenum(valueField);
			}
			static if (longfield) {
				rNote = parseRegister(upperField);
				if (rNote != -1) emitWithRegVal |= 0x04;
				else {
					const uint lf = cast(uint)parsenum(upperField);
					lower = lf & 0x7F;
					upper = lf>>7;
				}
			} else {
				if (upperField.length) {
					rNote = parseRegister(upperField);
					if (rNote != -1) emitWithRegVal |= 0x04;
					else {
						static if (note) {
							upper = cast(uint)parseNote(upperField);
						} 
					}
				}
				if (lowerField.length) {
					rAux = parseRegister(lowerField);
					if (rAux != -1) emitWithRegVal |= 0x01;
					else lower = cast(uint)parsenum(lowerField);
				}
			}
			rCh = parseRegister(chField);
			if (rCh != -1) emitWithRegVal |= 0x02;
			else channel = cast(uint)parsenum(chField);
			if (emitWithRegVal) {
				flushEmitStr();
				UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), cmdCode, cast(ubyte)(channel&0x0F), 
						cast(ubyte)upper, cast(ubyte)lower);
				M2Command cmdUprHl = M2Command([OpCode.emit_r, cast(ubyte)rValue, 0, 0]);
				cmdUprHl.hwords[1] = cast(ushort)currDevNum;
				M2Command cmdLwrHl = M2Command([cast(ubyte)rNote, cast(ubyte)rCh, cast(ubyte)rAux, cast(ubyte)emitWithRegVal]);
				currEmitStr ~= [cmdUprHl.word, cmdLwrHl.word, midiCMD.base, value];
				/* insertCmd([0x42_00_00_00 | currDevNum | (rValue<<16), (rNote<<24) | (rCh<<16) | (rAux<<8) | emitWithRegVal,
						cmdCode | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | upper | lower, value]); */
			} else {
				UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), cmdCode, cast(ubyte)(channel&0x0F), 
						cast(ubyte)upper, cast(ubyte)lower);
				currEmitStr ~= [midiCMD.base, value];
				//currEmitStr ~= [cmdCode | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | upper | lower, value];
			}
		}
		for (sizediff_t lineNum = key.lineNum ; lineNum < key.lineNum + key.lineLen ; lineNum++) {
			string[] words = removeComment(lines[lineNum]).split!isWhite();
			if (!words.length) continue;//If line is used as padding or just for comments, don't try to parse it
			if (words[0][0] == '$') {	//parse MIDI emit commands
				const sizediff_t f = countUntil(words[0], '['), t =countUntil(words[0], ']');
				const uint deviceNum = cast(uint)parsenum(words[0][f + 1..t]);
				enforce(deviceNum <= 65_535, "Device number too large");
				if (currEmitStr.length > 251 || currDevNum != deviceNum) flushEmitStr();	//flush emit string if it's not guaranteed that a 4 word long data won't fit, or device isn't equal
				currDevNum = deviceNum;
				switch (words[1]) {
					case "note":		//note macro, inserts a note on, then a note off command after a set time
						const uint channel = cast(uint)parsenum(words[2]);
						const uint vel = cast(uint)parsenum(words[3]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 65_535, "Velocity number too high");
						if (words[4][0] == '~') {	//use the same duration to all the notes
							const ulong noteDur = parseRhythm(words[4][1..$], bpm, result.songdata.timebase);
							for (int j = 5 ; j < words.length ; j++) {
								const uint note = parseNote(words[j]);
								UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
										cast(ubyte)note);
								currEmitStr ~= [midiCMD.base, vel<<16];
								noteMacroHandler.put(NoteData(deviceNum, cast(ubyte)channel, cast(ubyte)note, cast(ushort)vel, timepos, 
										timepos + noteDur));
							}
						} else {	//each note should have their own duration
							for (int j = 4 ; j < words.length ; j++) {
								string[] notebase = words[j].split(":");
								const ulong noteDur = parseRhythm(notebase[0], bpm, result.songdata.timebase);
								const uint note = parseNote(notebase[1]);
								UMP midiCMD = UMP(MessageType.MIDI2, cast(ubyte)(channel>>4), MIDI2_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
										cast(ubyte)note);
								currEmitStr ~= [midiCMD.base, vel<<16];
								noteMacroHandler.put(NoteData(deviceNum, cast(ubyte)channel, cast(ubyte)note, cast(ushort)vel, timepos, 
										timepos + noteDur));
							}
						}
						break;
					//MIDI 1.0 begin
					case "m1_nf":		//MIDI 1.0 note off
						const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 127, "Velocity number too high");
						UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.NoteOff, cast(ubyte)(channel&0x0F), 
								cast(ubyte)note, cast(ubyte)vel);
						currEmitStr ~= [midiCMD.base];
						break;
					case "m1_nn":		//MIDI 1.0 note on
						const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 127, "Velocity number too high");
						UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.NoteOn, cast(ubyte)(channel&0x0F), 
								cast(ubyte)note, cast(ubyte)vel);
						currEmitStr ~= [midiCMD.base];
						break;
					case "m1_ppres":		//MIDI 1.0 poly pressure
						const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 127, "Velocity number too high");
						UMP midiCMD = UMP(MessageType.MIDI1, cast(ubyte)(channel>>4), MIDI1_0Cmd.PolyAftrTch, cast(ubyte)(channel&0x0F), 
								cast(ubyte)note, cast(ubyte)vel);
						currEmitStr ~= [midiCMD.base];
						break;
					case "m1_cc":			//MIDI 1.0 control change
						const uint channel = cast(uint)parsenum(words[2]);
						const uint num = cast(uint)parsenum(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
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
					//MIDI 2.0 begin
					case "nf":			//MIDI note off
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 65_535, "Velocity number too high");
						currEmitStr ~= [0x20_80_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8), vel<<16]; */
						string auxField;
						if (words.length == 6) auxField = words[5];
						insertMIDI2Cmd!(false, true)(MIDI2_0Cmd.NoteOff, words[2], words[3], null, words[4], auxField);
						break;
					case "nn":			//MIDI note on
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(vel <= 65_535, "Velocity number too high");
						currEmitStr ~= [0x20_90_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8), vel<<16]; */
						string auxField;
						if (words.length == 6) auxField = words[5];
						insertMIDI2Cmd!(false, true)(MIDI2_0Cmd.NoteOn, words[2], words[3], null, words[4], auxField);
						break;
					case "ppres":		//Poly aftertouch
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint vel = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						currEmitStr ~= [0x20_A0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8), vel]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.PolyAftrTch, words[2], words[3], null, words[4], null);
						break;
					case "pccr":		//Poly registered per-note controller change
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint index = cast(uint)parsenum(words[4]);
						const uint val = cast(uint)parsenum(words[5]);
						enforce(channel <= 255, "Channel number too high");
						enforce(index <= 255, "Index number too high");
						currEmitStr ~= [0x20_00_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8) | index, val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.PolyCtrlChR, words[2], words[3], words[4], words[5], null);
						break;
					case "pcca":		//Poly assignable per-note controller change
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint index = cast(uint)parsenum(words[4]);
						const uint val = cast(uint)parsenum(words[5]);
						enforce(channel <= 255, "Channel number too high");
						enforce(index <= 255, "Index number too high");
						currEmitStr ~= [0x20_10_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8) | index, val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.PolyCtrlCh, words[2], words[3], words[4], words[5], null);
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
						currEmitStr ~= [];
						break;
					case "ccl":			//Legacy controller change
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint index = cast(uint)parsenum(words[3]);
						const uint val = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						enforce(index <= 127, "Index number too high");
						currEmitStr ~= [0x20_B0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (index<<8), val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.CtrlChOld, words[2], words[3], null, words[4], null);
						break;
					case "ccr":
						insertMIDI2Cmd!(true, false)(MIDI2_0Cmd.CtrlChR, words[2], words[3], null, words[4], null);
						break;
					case "cc":
						insertMIDI2Cmd!(true, false)(MIDI2_0Cmd.CtrlCh, words[2], words[3], null, words[4], null);
						break;
					case "rccr":
						insertMIDI2Cmd!(true, false)(MIDI2_0Cmd.RelCtrlChR, words[2], words[3], null, words[4], null);
						break;
					case "rcc":
						insertMIDI2Cmd!(true, false)(MIDI2_0Cmd.RelCtrlCh, words[2], words[3], null, words[4], null);
						break;
					/* case "cc", "ccr", "rcc", "rccr"://Controller change commands
						const uint channel = cast(uint)parsenum(words[2]);
						const uint index = cast(uint)parsenum(words[3]);
						const uint val = cast(uint)parsenum(words[4]);
						const uint cmdNum = words[1] == "ccr" ? 0x20_20_00_00 : 
								(words[1] == "cc" ? 0x20_30_00_00 : 
								(words[1] == "rccr" ? 0x20_40_00_00 : 0x20_50_00_00));
						enforce(channel <= 255, "Channel number too high");
						enforce(index <= 16_383, "Index number too high");
						currEmitStr ~= [cmdNum | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | 
								((index & 0x3F_80)<<1) | (index & 0x7F), val];
						break; */
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
						break;
					case "cpres":		//Channel aftertouch
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint val = cast(uint)parsenum(words[3]);
						enforce(channel <= 255, "Channel number too high");
						currEmitStr ~= [0x20_D0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16), val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.ChAftrTch, words[2], null, null, words[3], null);
						break;
					case "pb":			//Pitch bend
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint val = cast(uint)parsenum(words[3]);
						enforce(channel <= 255, "Channel number too high");
						currEmitStr ~= [0x20_E0_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16), val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.PitchBend, words[2], null, null, words[3], null);
						break;
					case "ppb":			//Poly pitch bend
						/* const uint channel = cast(uint)parsenum(words[2]);
						const uint note = parseNote(words[3]);
						const uint val = cast(uint)parsenum(words[4]);
						enforce(channel <= 255, "Channel number too high");
						currEmitStr ~= [0x20_60_00_00 | ((channel & 0xF0)<<20) | ((channel & 0x0F)<<16) | (note<<8), val]; */
						insertMIDI2Cmd!(false, false)(MIDI2_0Cmd.PitchBend, words[2], words[3], null, words[4], null);
						break;
					//MIDI 2.0 end
					default:
						break;
				}
			} else {					//parse any other command
				//flush emit string to command list before moving onto parsing any other data.
				flushEmitStr();
				switch (words[0]) {
					case "wait":		//parse wait command
						ulong amount;
						try {	//Try to parse it as a number
							amount = parsenum(words[1]);
						} catch (Exception e) {	//It is not a number, try to parse it as a rhythm
							amount = parseRhythm(words[1], bpm, result.songdata.timebase);
						}
						//go through all the note macros if any of them have expired, and insert one or more wait commands if needed
						do {
							flushEmitStr();
							size_t num;
							ulong lowestAmount;
							for (size_t j ; j < noteMacroHandler.length ; j++) {	//search for few first elements with the same wait amounts
								if (noteMacroHandler[i].durTo <= timepos + amount) {
									if (!lowestAmount) {
										lowestAmount = (timepos + amount) - noteMacroHandler[j].durTo;
									} else if (lowestAmount != noteMacroHandler[j].durTo) {
										break;
									}
									num = j + 1;
								} else {
									break;
								}
							}
							for (size_t j ; j < num ; j++) {						//if there are expired note macros: put noteoff commands into the emit string and remove them from the list
								NoteData nd = noteMacroHandler.remove(0);
								currEmitStr ~= [UMP(MessageType.MIDI2, nd.ch>>4, MIDI2_0Cmd.NoteOff, nd.ch & 0x0F, nd.note).base, nd.velocity];
								if (currEmitStr.length >= 254) flushEmitStr();
							}
							if (num == 0) {											//if there's no (more) expired note macros, then just simply emit a wait command with the current amount
								insertWaitCmd(amount);
								timepos += amount;
								amount = 0;
							} else {
								insertWaitCmd(lowestAmount);
								timepos += lowestAmount;
								amount -= lowestAmount;
							}
						} while(amount);
						break;
					case "chain-par":
						sizediff_t refPtrnID = searchPatternByName(words[1]);
						enforce(refPtrnID != -1, "Pattern not found");
						insertCmd([0x05_00_00_00 | cast(uint)refPtrnID]);
						break;
					case "chain-ser":
						sizediff_t refPtrnID = searchPatternByName(words[1]);
						enforce(refPtrnID != -1, "Pattern not found");
						insertCmd([0x06_00_00_00 | cast(uint)refPtrnID]);
						break;
					case "chain":
						sizediff_t refPtrnID = searchPatternByName(words[1]);
						enforce(refPtrnID != -1, "Pattern not found");
						insertCmd([0x41_00_00_00 | cast(uint)refPtrnID]);
						break;
					case "jmpnc", "jmp":
						insertJmpCmd(lineNum, 0x04, words[1..$]);
						break;
					case "jmpeq":
						insertJmpCmd(lineNum, 0x0104, words[1..$]);
						break;
					case "jmpne":
						insertJmpCmd(lineNum, 0x0204, words[1..$]);
						break;
					case "jmpsh":
						insertJmpCmd(lineNum, 0x0304, words[1..$]);
						break;
					case "jmpop":
						insertJmpCmd(lineNum, 0x0404, words[1..$]);
						break;
					case "add": 
						insertMathCmd(OpCode.add, words[1..$]);
						break;
					case "sub":
						insertMathCmd(OpCode.sub, words[1..$]);
						break;
					case "mul":
						insertMathCmd(OpCode.mul, words[1..$]);
						break;
					case "div":
						insertMathCmd(OpCode.div, words[1..$]);
						break;
					case "mod":
						insertMathCmd(OpCode.mod, words[1..$]);
						break;
					case "and":
						insertMathCmd(OpCode.and, words[1..$]);
						break;
					case "or":
						insertMathCmd(OpCode.or, words[1..$]);
						break;
					case "xor":
						insertMathCmd(OpCode.xor, words[1..$]);
						break;
					case "not":
						insertTwoOpCmd(OpCode.not, words[1..$]);
						break;
					case "lshi": 
						insertShImmCmd(OpCode.lshi, words[1..$]);
						break;
					case "rshi": 
						insertShImmCmd(OpCode.rshi, words[1..$]);
						break;
					case "rasi": 
						insertShImmCmd(OpCode.rasi, words[1..$]);
						break;
					case "adds": 
						insertMathCmd(OpCode.adds, words[1..$]);
						break;
					case "subs": 
						insertMathCmd(OpCode.subs, words[1..$]);
						break;
					case "muls": 
						insertMathCmd(OpCode.muls, words[1..$]);
						break;
					case "divs": 
						insertMathCmd(OpCode.divs, words[1..$]);
						break;
					case "lsh": 
						insertMathCmd(OpCode.lsh, words[1..$]);
						break;
					case "rsh": 
						insertMathCmd(OpCode.rsh, words[1..$]);
						break;
					case "ras": 
						insertMathCmd(OpCode.ras, words[1..$]);
						break;
					case "mov":
						insertTwoOpCmd(OpCode.mov, words[1..$]);
						break;
					case "cmpeq":
						insertCmpInstr(CmpCode.eq, words[1..$]);
						break;
					case "cmpne":
						insertCmpInstr(CmpCode.ne, words[1..$]);
						break;
					case "cmpgt":
						insertCmpInstr(CmpCode.gt, words[1..$]);
						break;
					case "cmpge":
						insertCmpInstr(CmpCode.ge, words[1..$]);
						break;
					case "cmplt":
						insertCmpInstr(CmpCode.lt, words[1..$]);
						break;
					case "cmple":
						insertCmpInstr(CmpCode.le, words[1..$]);
						break;
					case "cmpze":
						insertCmpInstr(CmpCode.ze, words[1..$]);
						break;
					case "cmpnz":
						insertCmpInstr(CmpCode.nz, words[1..$]);
						break;
					case "cmpng":
						insertCmpInstr(CmpCode.ng, words[1..$]);
						break;
					case "cmppo":
						insertCmpInstr(CmpCode.po, words[1..$]);
						break;
					case "cmpsgt":
						insertCmpInstr(CmpCode.sgt, words[1..$]);
						break;
					case "cmpsge":
						insertCmpInstr(CmpCode.sge, words[1..$]);
						break;
					case "cmpslt":
						insertCmpInstr(CmpCode.slt, words[1..$]);
						break;
					case "cmpsle":
						insertCmpInstr(CmpCode.sle, words[1..$]);
						break;
					case "ctrl":
						break;
					case "display":
						M2Command displCMD = M2Command([OpCode.display, 0, 0, 0]);
						switch (words[1]) {
							case "BPM":
								displCMD.bytes[1] = DisplayCmdCode.setVal;
								displCMD.hwords[1] = SetDispValCode.BPM;
								key.currBPM = to!float(words[2]);
								insertCmd([displCMD.word, *cast(uint*)&key.currBPM]);
								break;
							default:

								break;
						}
						break;
					default:
						break;
				}
			}
			
		}
	}
	return result;
}