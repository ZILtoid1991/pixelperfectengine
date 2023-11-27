module pixelperfectengine.audio.m2.rw_text;

public import pixelperfectengine.audio.m2.types;
import std.string;
import std.exception;
import std.array : split;
import std.uni : isWhite;
import std.format.read : formattedRead;
import std.conv : to;
import std.algorithm.searching : canFind, startsWith;

public M2File loadM2FromText(string src) {
	long parsenum(string s) {
		if (s.startsWith("0x")) {
			return s[2..$].to!long(16);
		} else {
			return s.to!long;
		}
	}
	enum Context {
		init,
		headerParse,
		metadataParse,
		deviceParse,
		patternParse,
	}
	struct PatternData {
		string name;
		size_t lineNum;
		uint lineLen;
		float currBPM = 120;
	}
	M2File result;
	Context context;
	string[] lines = src.splitLines;
	PatternData[] ptrnData;
	//Validate file
	enforce(lines[0][0..12] == "MIDI2.0 VER " && lines[0][12] == '1', "Wrong version or file!");
	//First pass: parse header, 
	for (size_t lineNum = 1 ; lineNum < lines.length ; lineNum++) {
		string[] words = lines[lineNum].split!isWhite();
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
						break;
					case "timeFormatPeriod":
						
						break;
					case "timeFormatRes":
						break;
					case "maxPattern":
						break;
					case "END":
						break;
					default:
						break;
				}
				break;
			default:
				switch (words[0]) {	
					case "HEADER":
						context = Context.headerParse;
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
	
	return result;
}