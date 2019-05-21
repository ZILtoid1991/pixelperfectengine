module PixelPerfectEngine.system.systemUtility;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.systemUtility module
 */

public immutable dstring engineVer = "0.9.4";	///Defines engine version
public immutable dstring sdlVer = "2.0.5";		///Defines SDL version
version(X86){
	public immutable dstring sysInfo = "x86";	///Defines what CPU architecture the software is being built for.
}else version(X86_64){
	public immutable dstring sysInfo = "AMD86";
}else version(ARM){
	public immutable dstring sysInfo = "ARMv8";
}else version(AArch64){
	public immutable dstring sysInfo = "AArch64";
}else{
	public immutable dstring sysInfo = "UNDEFINED";	//Contact me or make a pull request if something needs to be added.
}
version(Windows){
	public immutable dstring osInfo = "Windows";	///Defines target OS
}else version(linux){
	public immutable dstring osInfo = "Linux";
}else version(OSX){
	public immutable dstring osInfo = "OSX";
}else version(Posix){
	public immutable dstring osInfo = "Posix";
}else{
	public immutable dstring osInfo = "UNDEFINED";
}
version(X86){
	version(NO_SSE2){
		public immutable dstring renderInfo = "CPUBLiT/MMX";
	}else{
		public immutable dstring renderInfo = "CPUBLiT/SSE2";	///Renderer information.
	}
}else version(X86_64){
	version(USE_AVX){
		public immutable dstring renderInfo = "CPUBLiT/AVX";
	}else{
		public immutable dstring renderInfo = "CPUBLiT/SSE2";
	}
}else version(ARM){
	version(NEON){
		public immutable dstring renderInfo = "CPUBLiT/NEON";
	}else{
		public immutable dstring renderInfo = "Slow";
	}
}else version(AArch64){
	version(NEON){
		public immutable dstring renderInfo = "CPUBLiT/NEON";
	}else{
		public immutable dstring renderInfo = "Slow";
	}
}else{
	public immutable dstring renderInfo = "Slow";
}


	import PixelPerfectEngine.concrete.window;
	import PixelPerfectEngine.system.file;
	import PixelPerfectEngine.extbmp.extbmp;
/**
 * Loads the defaults for Concrete.
 */
public void INIT_CONCRETE(WindowHandler wh){
	import PixelPerfectEngine.concrete.window;
	import PixelPerfectEngine.system.file;
	import PixelPerfectEngine.extbmp.extbmp;
	import PixelPerfectEngine.graphics.fontsets;
	import PixelPerfectEngine.graphics.bitmap;
	import std.stdio;
	Fontset!Bitmap8Bit defaultFont = new Fontset!Bitmap8Bit(File("../system/OpenSans-reg-14.fnt"), "../system/");
	Fontset!Bitmap8Bit fixedWidthFont = new Fontset!Bitmap8Bit(File("../system/scp-14-reg.fnt"), "../system/");

	Bitmap8Bit[] ssOrigin = loadBitmapSheetFromFile!Bitmap8Bit("../system/concreteGUIE0.tga", 16, 16);
	StyleSheet ss = new StyleSheet();
	ss.setImage(ssOrigin[0],"closeButtonA");
	ss.setImage(ssOrigin[1],"closeButtonB");
	ss.setImage(ssOrigin[0],"checkBoxA");
	ss.setImage(ssOrigin[1],"checkBoxB");
	ss.setImage(ssOrigin[2],"radioButtonA");
	ss.setImage(ssOrigin[3],"radioButtonB");
	ss.setImage(ssOrigin[4],"upArrowA");
	ss.setImage(ssOrigin[5],"upArrowB");
	ss.setImage(ssOrigin[6],"downArrowA");
	ss.setImage(ssOrigin[7],"downArrowB");
	ss.setImage(ssOrigin[8],"plusA");
	ss.setImage(ssOrigin[9],"plusB");
	ss.setImage(ssOrigin[10],"minusA");
	ss.setImage(ssOrigin[11],"minusB");
	ss.setImage(ssOrigin[12],"leftArrowA");
	ss.setImage(ssOrigin[13],"leftArrowB");
	ss.setImage(ssOrigin[14],"rightArrowA");
	ss.setImage(ssOrigin[15],"rightArrowB");
	ss.addFontset(defaultFont, "default");
	ss.addFontset(fixedWidthFont, "fixedWidth");
	wh.defaultStyle = ss;
	Window.defaultStyle = ss;
	WindowElement.styleSheet = ss;
	PopUpElement.styleSheet = ss;
}
