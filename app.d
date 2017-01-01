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
import extbmp.extbmp;

int main(string[] args)
{

    DerelictSDL2.load();
	DerelictFI.load();

	Editor e = new Editor(args);
	e.whereTheMagicHappens;
    //MainProgram game = new MainProgram();
	//testAdvBitArrays(128);
	//TileLayerUnittest prg = new TileLayerUnittest();
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

class TileLayerUnittest : SystemEventListener, InputListener{
	bool isRunning, up, down, left, right;
	OutputWindow output;
	Raster r;
	TileLayer t;
	//Bitmap16Bit[wchar] tiles;
	InputHandler ih;
	this(){
		isRunning = true;
		ExtendibleBitmap tileSource = new ExtendibleBitmap("tiletest.xmp");
		t = new TileLayer(32,32, TileLayerRenderingMode.BLITTER);
		for(int i; i < tileSource.bitmapID.length; i++){
			string hex = tileSource.bitmapID[i];
			//writeln(hex[hex.length-4..hex.length]);
			t.addTile(loadBitmapFromXMP(tileSource, hex), to!wchar(parseHex(hex[hex.length-4..hex.length])));
		}
		wchar[] mapping;
		mapping.length = 256*256;
		for(int i; i < mapping.length; i++){
			mapping[i] = to!wchar(uniform(0x0000,0x00AA));
		}
		ih = new InputHandler();
		ih.sel ~= this;
		ih.il ~= this;
		ih.kb ~= KeyBinding(4096, SDL_SCANCODE_UP,0, "up", Devicetype.KEYBOARD);
		ih.kb ~= KeyBinding(4096, SDL_SCANCODE_DOWN,0, "down", Devicetype.KEYBOARD);
		ih.kb ~= KeyBinding(4096, SDL_SCANCODE_LEFT,0, "left", Devicetype.KEYBOARD);
		ih.kb ~= KeyBinding(4096, SDL_SCANCODE_RIGHT,0, "right", Devicetype.KEYBOARD);

		t.loadMapping(256,256,mapping);

		output = new OutputWindow("Tile Layer Unittest", 1280,960);
		r = new Raster(320,240,output);
		output.setMainRaster(r);
		loadPaletteFromXMP(tileSource, "default", r);
		r.addLayer(t);
		//r.addRefreshListener(output, 0);
		while(isRunning){
			r.refresh();
			ih.test();
			if(up) t.relScroll(0, 1);
			if(down) t.relScroll(0, -1);
			if(left) t.relScroll(1, 0);
			if(right) t.relScroll(-1, 0);
			//t.relScroll(1,0);
		}
	}
	override public void onQuit() {
		isRunning = false;
	}
	override public void controllerAdded(uint ID) {
		
	}
	override public void controllerRemoved(uint ID) {
		
	}
	override public void keyPressed(string ID,uint timestamp,uint devicenumber,uint devicetype) {
		//writeln(ID);
		switch(ID){
			case "up": up = true; break;
			case "down": down = true; break;
			case "left": left = true; break;
			case "right": right = true; break;
			default: break;
		}
	}
	override public void keyReleased(string ID,uint timestamp,uint devicenumber,uint devicetype) {
		switch(ID){
			case "up": up = false; break;
			case "down": down = false; break;
			case "left": left = false; break;
			case "right": right = false; break;
			default: break;
		}
	}

}