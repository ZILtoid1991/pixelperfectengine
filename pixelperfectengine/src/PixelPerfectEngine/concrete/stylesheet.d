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
	///Default color palette. First 16 colors are reserved for GUI defaults in a single workspace, second 16 colors are of the RGBI standard, the rest could
	///be used for other GUI elements such as backgrounds and icons
	public static enum Color[] defaultpaletteforGUI =
	[Color(0x00,0x00,0x00,0x00),	//transparent
	Color(0xFF,0xFF,0xFF,0xFF),		//reserved
	Color(0xFF,0x77,0x77,0x77),		//window
	Color(0xFF,0xCC,0xCC,0xCC),		//windowascent
	Color(0xFF,0x33,0x33,0x33),		//windowdescent
	Color(0xff,0x22,0x22,0x22),		//windowinactive
	Color(0xff,0xff,0x00,0x00),		//selection
	Color(0xFF,0x77,0x77,0xFF),		//WHAascent
	Color(0xFF,0x00,0x00,0x77),		//WHAdescent
	Color(0xFF,0x00,0x00,0xDD),		//WHAtop
	Color(0xFF,0x00,0x00,0xFF),		//cursor/selection
	Color(0xFF,0x00,0x00,0x7F),		//reserved for windowascentB
	Color(0xFF,0xFF,0xFF,0x00),		//reserved
	Color(0xFF,0xFF,0x7F,0x00),		//reserved for windowdescentB
	Color(0xFF,0x7F,0x7F,0x7F),		//reserved for WHAascentB
	Color(0xFF,0x00,0x00,0x00),		//reserved for WHAdescentB

	Color(0xFF,0x00,0x00,0x00),		//Black
	Color(0xFF,0x7F,0x00,0x00),		//Dark Red
	Color(0xFF,0x00,0x7F,0x00),		//Dark Green
	Color(0xFF,0x7F,0x7F,0x00),		//Dark Yellow
	Color(0xFF,0x00,0x00,0x7F),		//Dark Blue
	Color(0xFF,0x7F,0x00,0x7F),		//Dark Purple
	Color(0xFF,0x00,0x7F,0x7F),		//Dark Turquiose
	Color(0xFF,0x7F,0x7F,0x7F),		//Grey
	Color(0xFF,0x3F,0x3F,0x3F),		//Dark Grey
	Color(0xFF,0xFF,0x00,0x00),		//Red
	Color(0xFF,0x00,0xFF,0x00),		//Green
	Color(0xFF,0xFF,0xFF,0x00),		//Yellow
	Color(0xFF,0x00,0x00,0xFF),		//Blue
	Color(0xFF,0xFF,0x00,0xFF),		//Purple
	Color(0xFF,0x00,0xFF,0xFF),		//Turquiose
	Color(0xFF,0xFF,0xFF,0xFF),		//White
	];
	public Fontset!Bitmap8Bit[string] 		font;		///Fonts stored here. 
	public CharacterFormattingInfo!Bitmap8Bit[string]	_chrFormat; ///Character formatting
	public ubyte[string]						color;		///Colors are identified by strings.
	public Bitmap8Bit[string]					images;		///For icons, pattern fills, etc...
	public int[string]							drawParameters;		///Draw parameters are used for border thickness, padding, etc...
	public string[string]						fontTypes;	///Font type descriptions for various kind of components. WILL BE DEPRECATED!
	
	/**
	 * Creates a default stylesheet.
	 */
	public this(){
		color["transparent"] = 0x0000;
		color["normaltext"] = 0x001F;
		color["window"] = 0x0002;
		color["windowascent"] = 0x0003;
		color["windowdescent"] = 0x0004;
		color["windowinactive"] = 0x0005;
		color["selection"] = 0x0006;
		color["red"] = 0x0006;
		color["WHAascent"] = 0x0007;
		color["WHAdescent"] = 0x0008;
		color["WHTextActive"] = 0x001F;
		color["WHTextInactive"] = 0x0017;
		color["WHAtop"] = 0x0009;
		color["blue"] = 0x000A;
		color["darkblue"] = 0x000B;
		color["yellow"] = 0x000C;
		color["secondarytext"] = 0x001B;
		color["grey"] = 0x000E;
		color["black"] = 0x000F;
		color["white"] = 0x0001;
		color["PopUpMenuSecondaryTextColor"] = 0x001B;
		color["MenuBarSeparatorColor"] = 0x001F;
		color["PanelBorder"] = 0x0004;

		drawParameters["PopUpMenuHorizPadding"] = 4;
		drawParameters["PopUpMenuVertPadding"] = 1;
		drawParameters["PopUpMenuMinTextSpace"] = 8;
		drawParameters["ButtonPaddingHoriz"] = 8;
		drawParameters["PanelTitleFirstCharOffset"] = 16;
		drawParameters["PanelPadding"] = 4;

		drawParameters["MenuBarHorizPadding"] = 4;
		drawParameters["MenuBarVertPadding"] = 2;

		drawParameters["ListBoxRowHeight"] = 16;
		drawParameters["TextSpacingTop"] = 1;
		drawParameters["TextSpacingBottom"] = 1;
		drawParameters["TextSpacingSides"] = 2;
		drawParameters["WindowLeftPadding"] = 5;
		drawParameters["WindowRightPadding"] = 5;
		drawParameters["WindowTopPadding"] = 20;
		drawParameters["WindowBottomPadding"] = 5;
		drawParameters["ComponentHeight"] = 20;
		drawParameters["WindowHeaderHeight"] = 16;
		drawParameters["WHPaddingTop"] = 1;
	}
	/**
	 * Adds a fontset to the stylesheet.
	 */
	public void addFontset(Fontset!Bitmap8Bit f, string style) {
		font[style] = f;
	}
	public Fontset!Bitmap8Bit getFontset(string style) {
		return font.get(fontTypes.get(style, style), font[fontTypes["default"]]);
	}
	public void addChrFormatting(CharacterFormattingInfo!Bitmap8Bit frmt, string type) {
		_chrFormat[type] = frmt;
	}
	/**
	 * Duplicates character formatting for multiple labels.
	 */
	public void duplicateChrFormatting(string src, string dest) {
		_chrFormat[dest] = _chrFormat[src];
	}
	public CharacterFormattingInfo!Bitmap8Bit getChrFormatting(string type) {
		return _chrFormat.get(type, _chrFormat["default"]);
	}
	public void setColor(ubyte c, string colorName) {
		color[colorName] = c;
	}
	public ubyte getColor(string colorName) {
		return color[colorName];
	}
	public void setImage(Bitmap8Bit bitmap, string name) {
		images[name] = bitmap;
	}
	public Bitmap8Bit getImage(string name) {
		return images.get(name, null);
	}
}

