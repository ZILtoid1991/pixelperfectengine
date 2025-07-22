module pixelperfectengine.system.dictionary;

/*
 * Copyright (C) 2015-2020, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, dictionary module
 */
import newsdlang;
import std.stdio;
/**
 * Does a two-way coding based on an SDLang file.
 */
public class Dictionary{
	private string[int] encodeTable;
	private int[string] decodeTable;
	/// Uses tag values (string, int) to generate the dictionary
	public this(DLDocument root){
		try{
			//Tag root = parseFile(filename);
			foreach(DLTag t; root.tags){
				string s = t.values[0].get!string();
				int i = t.values[1].ge!int();
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
