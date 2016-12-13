/*
Copyright (C) 2015, by Laszlo Szeremi under the Boost license.

VDP Engine
*/


module app;

import std.stdio;
import std.string;
import std.conv;
import std.random;

import derelict.sdl2.sdl;
import derelict.freeimage.freeimage;

//import system.config;

import graphics.core;
import graphics.raster;
import graphics.layers;

import graphics.bitmap;
import collision;
import system.inputHandler;
import system.file;
import system.etc;
//import system.tgaconv;
import system.config;
import system.advBitArray;
import sound.sound;
import editor;

int main(string[] args)
{

    DerelictSDL2.load();
	DerelictFI.load();

	Editor e = new Editor(args);
	e.whereTheMagicHappens;
    //MainProgram game = new MainProgram();
	//testAdvBitArrays(128);


	return 0;
}

void testAdvBitArrays(int l){
	//General rule: at every step, write all the results to the screen
	//step 1: Generate 4 bitarrays with the l length
	AdvancedBitArray[4] ba;
	for(int i; i < ba.length; i++){
		int x = (l/8)+1;
		void[] rawData;
		rawData.length = x;
		for(int j; j < l/8 ; j++){
			ubyte b = to!ubyte(uniform(0,255));
			*cast(ubyte*)(rawData.ptr + j) = b;
		}
		ba[i] = new AdvancedBitArray(rawData,l);
		writeln(ba[i].toString());
	}
	//step 2: And, or, and then xor all the arrays together
	/*for(int i; i < ba.length; i++){
		for(int j; j < ba.length; j++){
			AdvancedBitArray resand = ba[i] & ba[j], resor = ba[i] | ba[j], resxor = ba[i] ^ ba[j];
			writeln(resand.toString());writeln(resor.toString());writeln(resxor.toString());
		}
	}//*/
	//step 3: Test bit shifting in both ways by 13
	for(int i; i < ba.length; i++){
		AdvancedBitArray shl = ba[i]<<5, shr = ba[i]>>5, sl = ba[i][1..50];
		writeln(shl.toString());
		writeln(shr.toString());
		writeln(sl.toString());
	}
}