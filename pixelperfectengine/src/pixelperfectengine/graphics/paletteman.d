/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, graphics.paletteMan module
 */

module pixelperfectengine.graphics.paletteMan;

import pixelperfectengine.graphics.common;

/**
 * Manages palettes
 * DEPRECATED! Palette management is now done by the raster.
 */
public class PaletteManager{
	Color[][string] palettes;
	this(){
	
	}
	/**
	 * Adds palette if it doesn't exist yet, then returns the pointer.
	 */
	public Color* addPalette(string name, Color[] pal){
		if(!palettes.get(name, null)){
			palettes[name] = pal;
		}
		return palettes[name].ptr;
	}
	/**
	 * Gets palette pointer
	 */
	public Color* getPalette(string name){
		return palettes[name].ptr;
	}
	public void removePalette(string name){
		palettes.remove(name);
	}
}