module PixelPerfectEngine.system.systemUtility;


public immutable wstring engineVer = "0.9.2";	///Defines engine version
public immutable wstring sdlVer = "2.0.5";		///Defines SDL version
version(X86){
	public immutable wstring sysInfo = "x86";	///Defines what CPU architecture the software is being built for.
}else version(X86_64){
	public immutable wstring sysInfo = "AMD86";
}else version(ARM){
	public immutable wstring sysInfo = "ARMv8";
}else version(AArch64){
	public immutable wstring sysInfo = "AArch64";
}else{
	public immutable wstring sysInfo = "UNDEFINED";	//Contact me or make a pull request if something needs to be added.
}
version(Windows){
	public immutable wstring osInfo = "Windows";	///Defines target OS
}else version(linux){
	public immutable wstring osInfo = "Linux";
}else version(OSX){
	public immutable wstring osInfo = "OSX";
}else version(Posix){
	public immutable wstring osInfo = "Posix";
}else{
	public immutable wstring osInfo = "UNDEFINED";
}
version(X86){
	version(NO_SSE2){
		public immutable wstring renderInfo = "CPUBLiT/MMX";
	}else{
		public immutable wstring renderInfo = "CPUBLiT/SSE2";	///Renderer information.
	}
}else version(X86_64){
	version(USE_AVX){
		public immutable wstring renderInfo = "CPUBLiT/AVX";
	}else{
		public immutable wstring renderInfo = "CPUBLiT/SSE2";
	}
}else version(ARM){
	version(NEON){
		public immutable wstring renderInfo = "CPUBLiT/NEON";
	}else{
		public immutable wstring renderInfo = "Slow";
	}
}else version(AArch64){
	version(NEON){
		public immutable wstring renderInfo = "CPUBLiT/NEON";
	}else{
		public immutable wstring renderInfo = "Slow";
	}
}else{
	public immutable wstring renderInfo = "Slow";
}
/**
 * Initializes SDL2.
 * Use "import derelict.sdl2.sdl;" to import derelictSDL2, and "mixin(INIT_SDL);" to insert it into your code.
 */
string INIT_SDL(){
	string result;
	version(Windows){
		result ~= `DerelictSDL2.load("system\\SDL2.dll\")`;
	}else{
		result ~= `DerelictSDL2.load("/system/SDL2.so")`;
	}
	debug{
		result ~= `SDL_SetHint(SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING, "1")`;
	}
	return result;
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
	Fontset!Bitmap16Bit defaultFont = loadFontsetFromXMP(new ExtendibleBitmap("system/sysfont.xmp"), "font");
	ExtendibleBitmap ssOrigin = new ExtendibleBitmap("system/sysdef.xmp");
	StyleSheet ss = new StyleSheet();
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI0"),"closeButtonA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI1"),"closeButtonB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI0"),"checkBoxA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI1"),"checkBoxB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI2"),"radioButtonA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI3"),"radioButtonB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI4"),"upArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI5"),"upArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI6"),"downArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI7"),"downArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI8"),"plusA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUI9"),"plusB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUIA"),"minusA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUIB"),"minusB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUIC"),"leftArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUID"),"leftArrowB");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUIE"),"rightArrowA");
	ss.setImage(loadBitmapFromXMP!Bitmap16Bit(ssOrigin,"GUIF"),"rightArrowB");
	ss.addFontset(defaultFont, "default");
	wh.defaultStyle = ss;
	Window.defaultStyle = ss;
}
