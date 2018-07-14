/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.stylesheet module
 */

module PixelPerfectEngine.concrete.stylesheet;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.fontsets;
/**
 * Defines style data for the Concrete GUI.
 */
public class StyleSheet{
	public static const Color[] defaultpaletteforGUI = 
	[Color(0x00,0x00,0x00,0x00),Color(0xFF,0xFF,0xFF,0xFF),Color(0xFF,0x34,0x9e,0xff),Color(0xff,0xa2,0xd7,0xff),	
		Color(0xff,0x00,0x2c,0x59),Color(0xff,0x00,0x75,0xe7),Color(0xff,0xff,0x00,0x00),Color(0xFF,0x7F,0x00,0x00),
		Color(0xFF,0x00,0xFF,0x00),Color(0xFF,0x00,0x7F,0x00),Color(0xFF,0x00,0x00,0xFF),Color(0xFF,0x00,0x00,0x7F),
		Color(0xFF,0xFF,0xFF,0x00),Color(0xFF,0xFF,0x7F,0x00),Color(0xFF,0x7F,0x7F,0x7F),Color(0xFF,0x00,0x00,0x00)];	///Default 16 color palette
	private Fontset!Bitmap16Bit[string] font;		///Fonts stored here.
	public ushort[string] color;		///Colors are identified by strings.
	private Bitmap16Bit[string] images;		///For icons, pattern fills, etc...
	public int[string] drawParameters;		///Draw parameters are used for border thickness, padding, etc...
	public string[string] fontTypes;		///Font type descriptions for various kind of components

	/**
	 * Creates a default stylesheet.
	 */
	public this(){
		color["transparent"] = 0x0000;
		color["normaltext"] = 0x0001;
		color["window"] = 0x0002;
		color["windowascent"] = 0x0003;
		color["windowdescent"] = 0x0004;
		color["windowinactive"] = 0x0005;
		color["selection"] = 0x0006;
		color["red"] = 0x0006;
		color["darkred"] = 0x0007;
		color["green"] = 0x0008;
		color["darkgreen"] = 0x0009;
		color["blue"] = 0x000A;
		color["darkblue"] = 0x000B;
		color["yellow"] = 0x000C;
		color["orange"] = 0x000D;
		color["grey"] = 0x000E;
		color["black"] = 0x000F;
		color["white"] = 0x0001;
		color["PopUpMenuSecondaryTextColor"] = 0x000D;
		color["MenuBarSeparatorColor"] = 0x000D;

		drawParameters["PopUpMenuHorizPadding"] = 4;
		drawParameters["PopUpMenuVertPadding"] = 1;
		drawParameters["PopUpMenuMinTextSpace"] = 8;

		drawParameters["MenuBarHorizPadding"] = 4;
		drawParameters["MenuBarVertPadding"] = 2;

		drawParameters["ListBoxRowHeight"] = 16;
		drawParameters["TextSpacingTop"] = 1;
		drawParameters["TextSpacingBottom"] = 1;
		drawParameters["WindowLeftPadding"] = 5;
		drawParameters["WindowRightPadding"] = 5;
		drawParameters["WindowTopPadding"] = 20;
		drawParameters["WindowBottomPadding"] = 5;
		drawParameters["ComponentHeight"] = 20;

		fontTypes["Label"] = "default";
	}
	public void addFontset(Fontset!Bitmap16Bit f, string style){
		font[style] = f;
	}
	public Fontset!Bitmap16Bit getFontset(string style){
		return font.get(style, font["default"]);
	}
	public void setColor(ushort c, string colorName){
		color[colorName] = c;
	}
	public ushort getColor(string colorName){
		return color[colorName];
	}
	public void setImage(Bitmap16Bit bitmap, string name){
		images[name] = bitmap;
	}
	public Bitmap16Bit getImage(string name){
		return images.get(name, null);
	}
}

