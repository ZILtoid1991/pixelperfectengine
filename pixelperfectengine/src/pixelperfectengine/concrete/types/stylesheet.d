/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.stylesheet module
 */

module pixelperfectengine.concrete.types.stylesheet;

import pixelperfectengine.graphics.bitmap;
import pixelperfectengine.graphics.fontsets;
import collections.hashmap;
/**
 * Defines style data for the Concrete GUI.
 */
public class StyleSheet{
	///Default color palette. First 16 colors are reserved for GUI defaults in a single workspace, second 16 colors are of the RGBI standard, the rest could
	///be used for other GUI elements such as backgrounds and icons
	public static enum Color[] defaultpaletteforGUI =
	[Color(0x00,0x00,0x00,0x00),	//transparent
	Color(0xFF,0xFF,0xFF,0xFF),		//reserved
	Color(0x30,0x30,0x30,0xFF),		//buttonTop
	Color(0x40,0x40,0x40,0xFF),		//windowascent
	Color(0x18,0x18,0x18,0xFF),		//windowdescent
	Color(0x10,0x10,0x10,0xff),		//windowBottom
	Color(0x20,0x20,0x20,0xff),		//window
	Color(0x00,0x00,0xaa,0xFF),		//WHAascent
	Color(0x00,0x00,0x40,0xFF),		//WHAdescent
	Color(0x00,0x00,0x70,0xFF),		//WHAtop
	Color(0x00,0x00,0xFF,0xFF),		//reserved (cursors now use a given color)
	Color(0x00,0x00,0x7F,0xFF),		//reserved for windowascentB
	Color(0xFF,0xFF,0x00,0xFF),		//reserved for windowBottomB
	Color(0x0a,0x0a,0x0a,0xFF),		//windowdescentB
	Color(0x7F,0x7F,0x7F,0xFF),		//reserved for WHAascentB
	Color(0x00,0x00,0x00,0xFF),		//reserved for WHAdescentB

	Color(0x00,0x00,0x00,0xFF),		//Black
	Color(0x7F,0x00,0x00,0xFF),		//Dark Red
	Color(0x00,0x7F,0x00,0xFF),		//Dark Green
	Color(0x7F,0x7F,0x00,0xFF),		//Dark Yellow
	Color(0x00,0x00,0x7F,0xFF),		//Dark Blue
	Color(0x7F,0x00,0x7F,0xFF),		//Dark Purple
	Color(0x00,0x7F,0x7F,0xFF),		//Dark Turquiose
	Color(0x7F,0x7F,0x7F,0xFF),		//Grey
	Color(0x3F,0x3F,0x3F,0xFF),		//Dark Grey
	Color(0xFF,0x00,0x00,0xFF),		//Red
	Color(0x00,0xFF,0x00,0xFF),		//Green
	Color(0xFF,0xFF,0x00,0xFF),		//Yellow
	Color(0x00,0x00,0xFF,0xFF),		//Blue
	Color(0xFF,0x00,0xFF,0xFF),		//Purple
	Color(0x00,0xFF,0xFF,0xFF),		//Turquiose
	Color(0xFF,0xFF,0xFF,0xFF),		//White
	];
	//public Fontset!Bitmap8Bit[string] 		font;		
	public HashMap!(string, Fontset!Bitmap8Bit)	font;///Fonts stored here. 
	public HashMap!(string, CharacterFormattingInfo!Bitmap8Bit) _chrFormat;	///Character formatting
	//public CharacterFormattingInfo!Bitmap8Bit[string]	_chrFormat; ///Character formatting
	//public ubyte[string]						color;		///Colors are identified by strings.
	public HashMap!(string, ubyte)				color;		///Colors are identified by strings.
	//public ubyte[][string]					pattern;	///Stores line patterns.
	public HashMap!(string, ubyte[])			pattern;	///Stores line patterns.
	//public Bitmap8Bit[string]					images;		///For icons, pattern fills, etc...
	public HashMap!(string, Bitmap8Bit)			images;		///For icons, pattern fills, etc...
	//public int[string]							drawParameters;		///Draw parameters are used for border thickness, padding, etc...
	public HashMap!(string, int)				drawParameters;		///Draw parameters are used for border thickness, padding, etc...
	//public string[string]						fontTypes;	///Font type descriptions for various kind of components.
	
	/**
	 * Creates a default stylesheet.
	 */
	public this() @safe {
		color["transparent"] = 0x0000;
		color["normaltext"] = 0x001F;
		color["window"] = 0x0006;
		color["buttonTop"] = 0x0002;
		color["windowascent"] = 0x0003;
		color["windowdescent"] = 0x0004;
		color["windowinactive"] = 0x0005;
		color["selection"] = 0x0019;
		color["red"] = 0x0019;
		color["WHAascent"] = 0x0007;
		color["WHAdescent"] = 0x0008;
		color["WHTextActive"] = 0x001F;
		color["WHTextInactive"] = 0x0017;
		color["WHAtop"] = 0x0009;
		color["blue"] = 0x001c;
		color["darkblue"] = 0x0014;
		color["yellow"] = 0x001b;
		color["secondarytext"] = 0x001B;
		color["grey"] = 0x0017;
		color["black"] = 0x000F;
		color["white"] = 0x0001;
		color["PopUpMenuSecondaryTextColor"] = 0x001B;
		color["MenuBarSeparatorColor"] = 0x001F;
		color["PanelBorder"] = 0x0010;
		color["SliderBackground"] = 0x0004;
		color["SliderColor"] = 0x0003;
		color["ListViewVSep"] = 0x0000;
		color["ListViewHSep"] = 0x0000;

		drawParameters["PopUpMenuHorizPadding"] = 4;
		drawParameters["PopUpMenuVertPadding"] = 1;
		drawParameters["PopUpMenuMinTextSpace"] = 8;
		drawParameters["PopUpMenuSeparatorSize"] = 7;
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
		drawParameters["WindowHeaderHeight"] = 16;
		drawParameters["ComponentHeight"] = 20;
		drawParameters["WindowHeaderHeight"] = 16;
		drawParameters["WHPaddingTop"] = 1;
		drawParameters["HorizScrollBarSize"] = 16;
		drawParameters["VertScrollBarSize"] = 16;
		drawParameters["horizTextPadding"] = 1;

		drawParameters["WindowElementSize"] = 20;
		drawParameters["WindowElementSpacing"] = 5;

		drawParameters["PopUpLabelHorizPadding"] = 2;
		drawParameters["PopUpLabelVertPadding"] = 2;

		drawParameters["defDialogPadding"] = 10;

		drawParameters["windowMinimumSizes"] = 64;

		pattern["blackDottedLine"] = [0x1f, 0x1f, 0x10, 0x10];
	}
	/**
	 * Adds a fontset to the stylesheet with the given ID.
	 * IMPORTANT: ID of "default" must be set at least in order to ensure fallback capabilities!
	 */
	public void addFontset(Fontset!Bitmap8Bit f, string ID) @safe {
		font[ID] = f;
	}
	/**
	 * Returns the fontset with the given ID, or the default one if not found.
	 */
	public Fontset!Bitmap8Bit getFontset(string ID) @safe nothrow {
		auto result = font[ID];
		if (result !is null) return result;
		else return font["default"];
	}
	/**
	 * Adds a character formatting to the stylesheet with the given identifier.
	 * IMPORTANT: ID of "default" must be set at least in order to ensure fallback capabilities!
	 */
	public void addChrFormatting(CharacterFormattingInfo!Bitmap8Bit frmt, string ID) @safe nothrow {
		_chrFormat[ID] = frmt;
		//assert(_chrFormat[type] is frmt);
	}
	/**
	 * Duplicates character formatting for multiple IDs.
	 */
	public void duplicateChrFormatting(string src, string dest) @safe nothrow {
		_chrFormat[dest] = _chrFormat[src];
		
	}
	/**
	 * Returns the character formatting with the given ID, or the default one if not found.
	 */
	public CharacterFormattingInfo!Bitmap8Bit getChrFormatting(string ID) @safe nothrow {
		auto result = _chrFormat[ID];
		if (result !is null) return result;
		else return _chrFormat["default"];
	}
	/**
	 * Sets the given color to the supplied name to be recalled by element draw functions.
	 */
	public void setColor(ubyte c, string colorName) @safe nothrow {
		color[colorName] = c;
	}
	/**
	 * Returns the color that matches the name, or 0 if not found.
	 */
	public ubyte getColor(string colorName) @safe nothrow {
		return color[colorName];
	}
	/**
	 * Sets the image of the given name.
	 */
	public void setImage(Bitmap8Bit bitmap, string name) @safe nothrow {
		images[name] = bitmap;
	}
	/**
	 * Returns the image that matches the name, or null if not found.
	 */
	public Bitmap8Bit getImage(string name) @safe nothrow {
		return images[name];
	}
}

///Stores a global, default stylesheet.
///Must be initialized alongside with the GUI.
public static StyleSheet globalDefaultStyle;