/*
Copyright (C) 2015, by Laszlo Szeremi under the Boost license.

VDP Engine
*/


module app;

import std.stdio;
import std.string;
import std.conv;

import derelict.sdl2.sdl;

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
import sound.sound;
import editor;

int main(string[] args)
{

    DerelictSDL2.load();

	Editor e = new Editor(args);
	e.whereTheMagicHappens;
    //MainProgram game = new MainProgram();



	return 0;
}
