/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, data compression module
 */
module PixelPerfectEngine.system.dat;

import std.stdio;
import std.file;
import std.zlib;

/**
 * Stores compressed data on the hard drive to save storage space. Currently have a low-priority, not yet implemented.
 */ 

public class DatFile{
	private string fileName;
	private void[] dataBuffer;
	private DatFileHeader header;

	public this(string file){
		fileName = file;
	}

	/*public void load(){
		dataBuffer = uncompress(std.file.read(fileName));

		header.headerLenght = cast(uint)dataBuffer[0..3];
		int j = -1;
		string s;
		for(int i = 4; i < header.headerLenght; i++){
			if(cast(ubyte)dataBuffer[i] == 255 && j == -1){
				header.fileName ~= s;
				j++;
			}
			if(j++ != -1){
				if(j == 0){
					header.filePos[s] = cast(uint)dataBuffer[i..i+4];
				}
				else if(j == 4){
					header.fileLenght[s] = cast(uint)dataBuffer[i..i+4];
				}
				j++;
				if(j == 8){
					j = -1;
					s = "";
				}
			}
			else{
				s ~= cast(char)dataBuffer[i];
			}
		}
	}*/

	public void[] getFile(string name){
		return dataBuffer[header.filePos[name] .. header.fileLenght[name]];
	}
}

protected struct DatFileHeader{
	public uint headerLenght;
	public uint[string] fileLenght, filePos;
	public string[] fileName;

	//public this();
}