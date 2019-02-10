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
	ExtendibleBitmap ssOrigin = new ExtendibleBitmap("../system/sysdef.xmp");
	StyleSheet ss = new StyleSheet();
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI0"),"closeButtonA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI1"),"closeButtonB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI0"),"checkBoxA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI1"),"checkBoxB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI2"),"radioButtonA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI3"),"radioButtonB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI4"),"upArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI5"),"upArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI6"),"downArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI7"),"downArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI8"),"plusA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUI9"),"plusB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUIA"),"minusA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUIB"),"minusB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUIC"),"leftArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUID"),"leftArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUIE"),"rightArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap8Bit(ssOrigin,"GUIF"),"rightArrowB");
	ss.addFontset(defaultFont, "OpenSans");
	//ss.addFontset(defaultFont, "SourceCodePro");
	ss.addFontset(fixedWidthFont, "SourceCodePro");
	wh.defaultStyle = ss;
	Window.defaultStyle = ss;
	WindowElement.styleSheet = ss;
	PopUpElement.styleSheet = ss;
}
