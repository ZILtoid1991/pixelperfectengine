module pixelperfectengine.system.systemutility;
/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.systemUtility module
 */

public immutable dstring engineVer = "0.11.0";	///Defines engine version
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
	public immutable dstring renderInfo = "CPUBLiT/SSE2";	///Renderer information.
}else version(X86_64){
	public immutable dstring renderInfo = "CPUBLiT/SSE2";
}else version(ARM){
	public immutable dstring renderInfo = "CPUBLiT/NEON";
}else version(AArch64){
	public immutable dstring renderInfo = "CPUBLiT/NEON";
}else{
	public immutable dstring renderInfo = "CPUBLiT";
}


	import pixelperfectengine.concrete.window;
	import pixelperfectengine.system.file;
	//import pixelperfectengine.extbmp.extbmp;
/**
 * Loads the defaults for Concrete.
 */
public void INIT_CONCRETE() {
	import pixelperfectengine.concrete.window;
	import pixelperfectengine.system.file;
	//import pixelperfectengine.extbmp.extbmp;
	import pixelperfectengine.graphics.fontsets;
	import pixelperfectengine.graphics.bitmap;
	import std.stdio;
	import std.path : dirSeparator;
	const string sysPath = getPathToAsset(dirSeparator ~ "system");
	Fontset!Bitmap8Bit defaultFont = new Fontset!Bitmap8Bit(File(sysPath ~ dirSeparator ~ "OpenSans-reg-14.fnt"), sysPath);
	Fontset!Bitmap8Bit fixedWidthFont = new Fontset!Bitmap8Bit(File(sysPath ~ dirSeparator ~ "scp-14-reg.fnt"), sysPath);
	alias ChrFormat = CharacterFormattingInfo!Bitmap8Bit;
	Bitmap8Bit[] ssOrigin = loadBitmapSheetFromFile!Bitmap8Bit(sysPath ~ dirSeparator ~ "concreteGUIE0.tga", 16, 16);
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
	ssOrigin = loadBitmapSheetFromFile!Bitmap8Bit(sysPath ~ dirSeparator ~ "concreteGUIEF.tga", 16, 16);
	ss.setImage(ssOrigin[0],"driveSelButtonA");
	ss.setImage(ssOrigin[1],"driveSelButtonB");
	ss.setImage(ssOrigin[2],"pathButtonA");
	ss.setImage(ssOrigin[3],"pathButtonB");
	ss.setImage(ssOrigin[4],"dirUpButtonA");
	ss.setImage(ssOrigin[5],"dirUpButtonB");
	ss.setImage(ssOrigin[6],"newButtonA");
	ss.setImage(ssOrigin[7],"newButtonB");
	ss.setImage(ssOrigin[8],"saveButtonA");
	ss.setImage(ssOrigin[9],"saveButtonB");
	ss.setImage(ssOrigin[10],"loadButtonA");
	ss.setImage(ssOrigin[11],"loadButtonB");
	ss.setImage(ssOrigin[12],"settingsA");
	ss.setImage(ssOrigin[13],"settingsB");
	//ss.setImage(ssOrigin[14],"leftArrowA");
	//ss.setImage(ssOrigin[15],"leftArrowB");
	ss.setImage(loadBitmapFromFile!Bitmap8Bit(sysPath ~ dirSeparator ~ "concreteGUIDisable.tga"), "ElementDisabledPtrn");
	ss.addFontset(defaultFont, "default");
	ss.addFontset(fixedWidthFont, "fixedWidth");
	ss.addChrFormatting(new ChrFormat(defaultFont, 0x1f, FormattingFlags.leftJustify, 0, 16, 2),"default");
	ss.duplicateChrFormatting("default", "windowHeader");
	ss.addChrFormatting(new ChrFormat(defaultFont, 0x17, FormattingFlags.leftJustify, 0, 16, 2),"windowHeaderInactive");
	ss.addChrFormatting(new ChrFormat(defaultFont, 0x1f, FormattingFlags.centerJustify, 0, 16, 2),"defaultCJ");
	ss.duplicateChrFormatting("defaultCJ", "button");
	ss.duplicateChrFormatting("default", "textBox");
	ss.duplicateChrFormatting("default", "label");
	ss.duplicateChrFormatting("default", "checkBox");
	ss.duplicateChrFormatting("default", "ListViewHeader");
	ss.duplicateChrFormatting("default", "ListViewItem");
	ss.duplicateChrFormatting("default", "radioButton");
	ss.duplicateChrFormatting("defaultCJ", "menuBar");
	ss.duplicateChrFormatting("default", "popUpMenu");
	ss.duplicateChrFormatting("default", "panel");

	ss.addChrFormatting(new ChrFormat(defaultFont, 0x14, FormattingFlags.rightJustify, 0, 16, 2),"popUpMenuSecondary");
	ss.addChrFormatting(new ChrFormat(defaultFont, 0x1f, FormattingFlags.rightJustify, 0, 16, 2),"defaultRJ");
	/+wh.defaultStyle = ss;
	Window.defaultStyle = ss;
	WindowElement.styleSheet = ss;
	PopUpElement.styleSheet = ss;+/
	globalDefaultStyle = ss;
}
