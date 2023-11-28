module pixelperfectengine.audio.m2.rw_text;

public import pixelperfectengine.audio.m2.types;
import std.string;
import std.exception;
import std.array : split;
import std.uni : isWhite;
import std.format.read : formattedRead;
import std.conv : to;
import std.algorithm.searching : canFind, startsWith, countUntil;

public M2File loadM2FromText(string src) {
	long parsenum(string s) {
		if (s.startsWith("0x")) {
			return s[2..$].to!long(16);
		} else {
			return s.to!long;
		}
	}
	string removeComment(string s) {
		const ptrdiff_t commentPos = countUntil(s, ";");
		if (commentPos == -1) return s;
		return s[0..commentPos];
	}
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
	}
	M2File result;
	Context context, prevContext;
	string parsedString;
	string[] lines = src.splitLines;
	PatternData[] ptrnData;
	//Validate file
	enforce(lines[0][0..12] == "MIDI2.0 VER " && lines[0][12] == '1', "Wrong version or file!");
	//First pass: parse header, etc.
	for (size_t lineNum = 1 ; lineNum < lines.length ; lineNum++) {
		string[] words = removeComment(lines[lineNum]).split!isWhite();
		switch (context) {
			case Context.patternParse:
				if (words[0] == "END") {	//Calculate line numbers then close current pattern parsing.
					ptrnData[$-1].lineLen = cast(uint)(lineNum - ptrnData[$-1].lineNum - 1);
					context = Context.init;
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

	return result;
}