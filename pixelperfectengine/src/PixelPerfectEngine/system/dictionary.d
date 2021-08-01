module pixelperfectengine.system.dictionary;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, dictionary module
 */
import sdlang;
import std.stdio;
/**
 * Does a two-way coding based on an SDLang file.
 */
public class Dictionary{
	private string[int] encodeTable;
	private int[string] decodeTable;
	/// Uses tag values (string, int) to generate the dictionary
	public this(Tag root){
		try{
			//Tag root = parseFile(filename);
			foreach(Tag t; root.tags){
				string s = t.expectValue!string();
				int i = t.expectValue!int();
				encodeTable[i] = s;
				decodeTable[s] = i;
			}
		}
		catch(ParseException e){
			debug writeln(e.msg);
		}
	}
	/// Returns the first value from the encodeTable, where decodeTable[i] == input
	public string encode(int input){
		return encodeTable.get(input, null);
	}
	/// Returns the first value from the decodeTable, where encodetable[i] == input
	public int decode(string input){
		return decodeTable.get(input, -1);
	}
}