/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.fontsets module
 */

module PixelPerfectEngine.graphics.fontsets;
public import PixelPerfectEngine.graphics.bitmap;
//import std.stdio;
/**
* Stores the letters and all the data associated with the font, also has functions related to text lenght and line formatting. Supports variable letter width.
*/
public class Fontset{
	public Bitmap16Bit[wchar] letters/*, mask*/;
	private string name;
	private int size;
	public this(string name, int size, Bitmap16Bit[wchar] letters){
		this.name = name;
		this.size = size;
		this.letters = letters;
	}
	///Returns the name of the font 
	public string getName(){
		return name;
	}
	///Returns the height of the font.
	public int getSize(){
		return size;
	}
	///Returns the width of the text.
	public int getTextLength(wstring text){
		int length;
		for(int i ; i < text.length ; i++){
			length += letters[text[i]].getX;
		}
		//writeln(length);
		return length;
	}
	/**
	* Breaks the input text into multiple lines according to the parameters. 
	*/
	public wstring[] breakTextIntoMultipleLines(wstring input, int maxWidth, bool ignoreNewLineChars = false){
		wstring[] output;
		wstring currentWord, currentLine;
		int currentLength;
		
		foreach(character ; input){
			currentLength += letters[character].getX();
			if((!ignoreNewLineChars && (character == FormattingCharacters.newLine || character == FormattingCharacters.carriageReturn))){
				if(currentLength <= maxWidth){
					currentLine ~= currentWord;
				}
				output ~= currentLine;
				currentLine.length = 0;
				currentLength = 0;
				if(getTextLength(currentWord) > maxWidth){
					currentLine ~= currentWord;
				}
			}else if(character == FormattingCharacters.space){
				if(currentLength <= maxWidth){
					currentLine ~= currentWord;
				}else{
					output ~= currentLine;
					currentLine.length = 0;
					currentLength = 0;
					currentLine ~= currentWord;
				}
				currentLine ~= FormattingCharacters.space;
				currentWord.length = 0;
			}else{
				if(getTextLength(currentWord) > maxWidth){
					output ~= currentLine;
					currentLine.length = 0;
					currentLength = 0;
				}
				currentWord ~= character;
				
			}
		}

		return output;
	}	
}

public enum FormattingCharacters : wchar{
	horizontalTab	=	0x9,
	newLine			=	0xA,
	newParagraph	=	0xB,
	carriageReturn	=	0xD,
	space			=	0x20,
}