/*
 *Copyright (C) 2016, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, windowing.stylesheet module
 */

module windowing.stylesheet;

import graphics.bitmap;
import graphics.fontsets;

public class StyleSheet{
	public static const ubyte[64] defaultpaletteforGUI = 
	[0x00,0x00,0x00,0x00,	0xFF,0xFF,0xFF,0xFF,	0xFF,0x34,0x9e,0xff,	0xff,0xa2,0xd7,0xff,	
		0xff,0x00,0x2c,0x59,	0xff,0x00,0x75,0xe7,	0xff,0xff,0x00,0x00,	0xFF,0x7F,0x00,0x00,
		0xFF,0x00,0xFF,0x00,	0xFF,0x00,0x7F,0x00,	0xFF,0x00,0x00,0xFF,	0xFF,0x00,0x00,0x7F,
		0xFF,0xFF,0xFF,0x00,	0xFF,0xFF,0x7F,0x00,	0xFF,0x7F,0x7F,0x7F,	0xFF,0x00,0x00,0x00];
	private Fontset[string] font;
	private ushort[string] color;
	private Bitmap16Bit[string] images;		///For icons, pattern fills, etc...

	/**
	 * Creates a default stylesheet. Only uses the first 7 colors (0-6 or 0x0000-0x0006).
	 */
	public this(){
		color["transparent"] = 0x0000;
		color["normaltext"] = 0x0001;
		color["window"] = 0x0002;
		color["windowascent"] = 0x0003;
		color["windowdescent"] = 0x0004;
		color["windowinactive"] = 0x0005;
		color["selection"] = 0x0006;
		/*color["red"] = 0x0006;
		color["darkred"] = 0x0007;
		color["green"] = 0x0008;
		color["darkgreen"] = 0x0009;
		color["blue"] = 0x000A;
		color["darkblue"] = 0x000B;
		color["yellow"] = 0x000C;
		color["orange"] = 0x000D;
		color["grey"] = 0x000E;
		color["black"] = 0x000F;
		color["white"] = 0x0000;*/
	}
	public void addFontset(Fontset f, string style){
		font[style] = f;
	}
	public Fontset getFontset(string style){
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

