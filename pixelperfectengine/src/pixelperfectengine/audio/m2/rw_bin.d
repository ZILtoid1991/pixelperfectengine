module pixelperfectengine.audio.m2.rw_bin;

import bitleveld.reinterpret;
import std.exception;
import std.digest.crc : crc32Of;
public import pixelperfectengine.audio.m2.types;
import midi2.types.enums;
import midi2.types.structs;

public M2File readIMBCBin(ubyte[] src) {
	M2File result;
	enforce!IMBCException(cast(string)src[0..8] == "MIDI2.0B", "Not an IMBC file!");
	size_t pos= 8;
	uint ptrnNum, devNum;
	while (pos< src.length) {
		char[] chunkID = cast(char[])src[pos..pos+8];
		pos += 8;
		ulong chunkSize = reinterpretGet!ulong(src[pos..pos+8]);
		pos += 8;
		if (!chunkSize) continue;
		ubyte[4] checkSum = crc32Of(src[pos..pos + cast(size_t)chunkSize]);
		enforce!IMBCException(checkSum == src[pos+chunkSize..pos+chunkSize+4], "CRC32 error!");
		switch (chunkID) {
		case "HEADER\0\0":
			result.timeFormat = cast(M2TimeFormat)src[pos];
			pos++;
			result.timeFrmtPer = src[pos] | (src[pos+1]<<8) | (src[pos+2]<<16);
			pos+=3;
			result.timeFrmtRes = reinterpretGet!uint(src[pos..pos+4]);
			pos+=4;
			result.deviceNum = reinterpretGet!ushort(src[pos..pos+2]);
			pos+=2;
			const ptrnSl = reinterpretGet!ushort(src[pos..pos+2]);
			pos+=2;
			ptrnNum = reinterpretGet!uint(src[pos..pos+4]);
			pos+=4;
			result.songdata = M2Song(ptrnSl, result.timeFormat, result.timeFrmtPer, result.timeFrmtRes);
			break;
		case "METADATA":
			while (pos < src.length + chunkSize) {
				const idSize = src[pos];
				pos++;
				if (!idSize) continue;	//Likely padding to boundary at the end of this chunk, if present
				string id = cast(string)src[pos..pos+idSize];
				pos+=idSize;
				const dataSize = reinterpretGet!ushort(src[pos..pos+2]);
				pos+=2;
				string data = cast(string)src[pos..pos+dataSize];
				result.metadata[id] = data;
				pos+=dataSize;
			}
			break;
		case "DEVLIST\0":
			while (pos < src.length + chunkSize) {
				if (devNum == result.deviceNum) {
					pos++;
					continue;
				}
				const deviceID = reinterpretGet!ushort(src[pos..pos+2]);
				pos+=2;
				const idSize = src[pos];
				pos++;
				string id = cast(string)src[pos..pos+idSize];
				pos+=idSize;
				result.devicelist[deviceID] = id;
				devNum++;
			}
			break;
		case "PATTERN\0":
			const patternID = reinterpretGet!uint(src[pos..pos+4]);
			result.songdata.ptrnData[patternID & 0x00_ff_ff_ff] = cast(uint[])src[pos + 4 .. pos + 4 + chunkSize];
			pos+=cast(size_t)chunkSize;
			break;
		case "ARRAY\0\0\0":
			const arrayID = reinterpretGet!uint(src[pos..pos+4]);
			result.songdata.arrays[arrayID & 0x00_ff_ff_ff] = cast(uint[])src[pos + 4 .. pos + 4 + chunkSize];
			pos+=cast(size_t)chunkSize;
			break;
		default:	//Just ignore any and all unrecognized chunks.
			pos+=cast(size_t)chunkSize;
			break;
		}
	}
	return result;
}
public ubyte[] writeIMBCBin(M2File file) {
	ubyte[] result = cast(ubyte[])"MIDI2.0B\0\0\0\0";
	result ~= cast(ubyte[])"HEADER\0\0";
	result ~= reinterpretAsArray!ubyte(16LU);
	result ~= reinterpretAsArray!ubyte(cast(ubyte)file.timeFormat | (file.timeFrmtPer<<8));
	result ~= reinterpretAsArray!ubyte(file.timeFrmtRes);
	result ~= reinterpretAsArray!ubyte(cast(ushort)file.devicelist.length);
	result ~= reinterpretAsArray!ubyte(cast(ushort)file.songdata.ptrnSl.length);
	result ~= reinterpretAsArray!ubyte(cast(uint)file.songdata.ptrnData.length);
	result ~= crc32Of(result[$-16..$]);
	if (file.metadata.length) {
		result ~= cast(ubyte[])"METADATA";
		const toOverwritePos = result.length;
		result ~= cast(ubyte[])"\0\0\0\0\0\0\0";
		foreach (string key, string data ; file.metadata) {
			result ~= cast(ubyte)key.length;
			result ~= cast(ubyte[])key;
			result ~= reinterpretAsArray!ubyte(cast(ushort)data.length);
			result ~= cast(ubyte[])data;
		}
		while (result.length & 3) {
			result ~= 0x00;
		}
		result[toOverwritePos..toOverwritePos+8] = reinterpretAsArray!ubyte(cast(ulong)(result.length - toOverwritePos));
		result ~= crc32Of(result[toOverwritePos+8..$]);
	}
	if (file.devicelist.length) {
		result ~= cast(ubyte[])"DEVLIST\0";
		const toOverwritePos = result.length;
		result ~= cast(ubyte[])"\0\0\0\0\0\0\0";
		foreach (uint key, string id ; file.devicelist) {
			result ~= reinterpretAsArray!ubyte(cast(ushort)key);
			result ~= cast(ubyte)id.length;
			result ~= cast(ubyte[])id;
		}
		while (result.length & 3) {
			result ~= 0x00;
		}
		result[toOverwritePos..toOverwritePos+8] = reinterpretAsArray!ubyte(cast(ulong)(result.length - toOverwritePos));
		result ~= crc32Of(result[toOverwritePos+8..$]);
	}
	foreach (uint id, uint[] data ; file.songdata.arrays) {
		result ~= cast(ubyte[])"ARRAY\0\0\0";
		result ~= reinterpretAsArray!ubyte((data.length * 4) + 4UL);
		result ~= reinterpretAsArray!ubyte(id);
		result ~= cast(ubyte[])data;
		result ~= crc32Of(data);
	}
	foreach (uint id, uint[] data ; file.songdata.ptrnData) {
		result ~= cast(ubyte[])"PATTERN\0";
		result ~= reinterpretAsArray!ubyte((data.length * 4) + 4UL);
		result ~= reinterpretAsArray!ubyte(id);
		result ~= cast(ubyte[])data;
		result ~= crc32Of(data);
	}
	return result;
}
