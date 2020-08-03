module editor;

import types;
import serializer;
import editorEvents;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.etc : csvParser, isInteger;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.outputScreen;
import std.bitmanip : bitfields;

import conv = std.conv;
import stdio = std.stdio;

public class EditorWindowHandler : WindowHandler, ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	public ListBox objectList, propList;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Editor ie;

	//public InputHandler ih;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry, ISpriteLayer sl, Editor ie){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);

		WindowElement.popUpHandler = this;
		this.ie = ie;
	}
	public void clearArea(WindowElement sender){

	}
	public void initGUI(){
		Text pt(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("popUpMenu"));
		}
		Text st(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("popUpMenuSecondary"));
		}
		Text mt(dstring text) {
			return new Text(text, WindowElement.styleSheet.getChrFormatting("menuBar"));
		}
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);

		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", mt("FILE"));

		menuElements[0] ~= new PopUpMenuElement("new", pt("New window"), st("Ctrl + N"));
		menuElements[0] ~= new PopUpMenuElement("load", pt("Load window"), st("Ctrl + L"));
		menuElements[0] ~= new PopUpMenuElement("save", pt("Save window"), st("Ctrl + S"));
		menuElements[0] ~= new PopUpMenuElement("saveAs", pt("Save window as"), st("Ctrl + Shift + S"));
		menuElements[0] ~= new PopUpMenuElement("Export", pt("Export window as D code"), st("Ctrl + Shift + X"));
		menuElements[0] ~= new PopUpMenuElement("exit", pt("Exit application"), st("Alt + F4"));

		menuElements ~= new PopUpMenuElement("edit", mt("EDIT"));

		menuElements[1] ~= new PopUpMenuElement("undo", pt("Undo"), st("Ctrl + Z"));
		menuElements[1] ~= new PopUpMenuElement("redo", pt("Redo"), st("Ctrl + Shift + Z"));
		menuElements[1] ~= new PopUpMenuElement("copy", pt("Copy"), st("Ctrl + C"));
		menuElements[1] ~= new PopUpMenuElement("cut", pt("Cut"), st("Ctrl + X"));
		menuElements[1] ~= new PopUpMenuElement("paste", pt("Paste"), st("Ctrl + V"));

		menuElements ~= new PopUpMenuElement("elements", mt("ELEMENTS"));

		menuElements[2] ~= new PopUpMenuElement("Label", pt("Label"), st("Ctrl + F1"));
		menuElements[2] ~= new PopUpMenuElement("Button", pt("Button"), st("Ctrl + F2"));
		menuElements[2] ~= new PopUpMenuElement("TextBox", pt("TextBox"), st("Ctrl + F3"));
		menuElements[2] ~= new PopUpMenuElement("ListBox", pt("ListBox"), st("Ctrl + F4"));
		menuElements[2] ~= new PopUpMenuElement("CheckBox", pt("CheckBox"), st("Ctrl + F5"));
		menuElements[2] ~= new PopUpMenuElement("RadioButton", pt("RadioButton"), st("Ctrl + F6"));
		//menuElements[2] ~= new PopUpMenuElement("MenuBar", pt("MenuBar"), st("Ctrl + F7"));
		menuElements[2] ~= new PopUpMenuElement("HSlider", pt("HSlider"), st("Ctrl + F8"));
		menuElements[2] ~= new PopUpMenuElement("VSlider", pt("VSlider"), st("Ctrl + F9"));

		menuElements ~= new PopUpMenuElement("help", mt("HELP"));

		menuElements[3] ~= new PopUpMenuElement("helpFile", pt("Content"));
		menuElements[3] ~= new PopUpMenuElement("about", pt("About"));

		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,rasterX - 1,16),menuElements);
		addElement(mb);

		objectList = new ListBox("objectList", Coordinate(644,20,rasterX - 5,238), [], new ListBoxHeader(["Type"d,"Name"d],[128,128]),16);
		propList = new ListBox("propList", Coordinate(644,242,rasterX - 5,477), [], new ListBoxHeader(["Prop"d,"Val"d],[128,256]),16,true);
		addElement(objectList);
		addElement(propList);

		foreach(WindowElement we; elements){
			we.draw();
		}
		mb.onMouseLClickPre = &ie.menuEvent;
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we){
		elements ~= we;
		we.elementContainer = this;
	}

	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}

	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; elements){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; elements){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){

				e.onScroll(y, x, wX, wY);

				return;
			}
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
}

public class DummyWindow : Window{
	Editor ed;
	public this(Coordinate coordinates, dstring name, Editor ed){
		super(coordinates, name);
		this.ed = ed;
	}
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		//super.passMouseEvent(x,y,state,button);
		if(button == MouseButton.LEFT){
			ed.clickEvent(x,y,state);
		}else if(button == MouseButton.RIGHT){
			foreach(we; elements){
				Coordinate c = we.position;
				if(x > c.left && x < c.right){
					if(y > c.top && y < c.bottom){
						ed.selectEvent(we);
					}
				}
			}
		}
	}
	override public void close() {
	//super.close;
	}
	override public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button) {

	}
	override public void passMouseDragEvent(int x, int y, int relX, int relY, ubyte button) {
		ed.dragEvent(x, y, relX, relY, button);
	}
}

public class Editor : SystemEventListener, InputListener{
	EditorWindowHandler ewh;
	DummyWindow 		dw;
	SpriteLayer			sprtL;
	Raster				mainRaster;
	OutputScreen		outScrn;
	InputHandler		inputH;
	EditMode			mode;
	mixin(bitfields!(
		bool, "onExit", 1,
		bool, "undoPressed", 1,
		bool, "redoPressed", 1,
		bool, "delPressed", 1,
		bool, "moveElemMode", 1,
		ubyte, "", 3,
	));
	Coordinate			moveElemOrig;
	int					x0, y0;
	ElementType			typeSel;
	UndoableStack		eventStack;
	WindowElement[string] elements;
	string				selection;

	static string[ElementType] nameBases;
	public this(){
		import PixelPerfectEngine.system.systemUtility;
		sprtL = new SpriteLayer(LayerRenderingMode.COPY);
		outScrn = new OutputScreen("WindowMaker for PPE/Concrete",1696,960);
		mainRaster = new Raster(848,480,outScrn);
		mainRaster.addLayer(sprtL,0);
		typeSel = ElementType.NULL;

		ewh = new EditorWindowHandler(1696,960,848,480,sprtL, this);
		mainRaster.palette = StyleSheet.defaultpaletteforGUI;
		INIT_CONCRETE(ewh);
		inputH = new InputHandler();
		inputH.sel ~= this;
		inputH.il ~= this;
		inputH.ml ~= ewh;
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl, ScanCode.Z, 0, "undo", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(KeyModifier.Ctrl | KeyModifier.Shift, ScanCode.Z, 0, "redo", Devicetype.KEYBOARD, 
				KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(0, ScanCode.DELETE, 0, "del", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		inputH.kb ~= KeyBinding(0, ScanCode.ESCAPE, 0, "sysesc", Devicetype.KEYBOARD, KeyModifier.LockKeys);
		PopUpElement.inputhandler = inputH;
		WindowElement.inputHandler = inputH;
		ewh.initGUI();
		dw = new DummyWindow(Coordinate(0,16,640,480), "New Window"d, this);
		ewh.addWindow(dw);
		eventStack = new UndoableStack(10);
		wserializer = new WindowSerializer();
		dwtarget = dw;
		editorTarget = this;
		ewh.objectList.onItemSelect = &onObjectListSelect;
		ewh.propList.onTextInput = &onAttributeEdit;
		updateElementList;
	}
	static this(){
		nameBases[ElementType.Label] = "label";
		nameBases[ElementType.Button] = "button";
		nameBases[ElementType.SmallButton] = "smallButton";
		nameBases[ElementType.TextBox] = "textBox";
		nameBases[ElementType.ListBox] = "listBox";
		nameBases[ElementType.RadioButton] = "radioButton";
		nameBases[ElementType.CheckBox] = "checkBox";
		nameBases[ElementType.HSlider] = "hSlider";
		nameBases[ElementType.VSlider] = "vSlider";
		nameBases[ElementType.MenuBar] = "menuBar";
	}
	public string getNextName(string input){
		for(int i ; true ; i++){
			if(elements.get(input ~ conv.to!string(i), null) is null)
				return input ~ conv.to!string(i);
		}
	}
	public void onObjectListSelect(Event ev){
		deinitElemMove;
		ListBoxItem lbi = cast(ListBoxItem)ev.aux;
		if(lbi.getText(0) != "window"){
			selection = conv.to!string(lbi.getText(1));
		}else{//Fill attribute list with data related to the window
			selection = "window";
		}
		updatePropertyList;
	}
	public void onLoadFile(Event ev){
		wserializer = new WindowSerializer(ev.getFullPath);
		wserializer.deserialize(dw, this);
	}
	public void onSaveFileAs(Event ev){
		wserializer.store(ev.getFullPath);
	}
	public void onExportWindow(Event ev){
		wserializer.generateDCode(ev.getFullPath);
	}
	public void onAttributeEdit(Event ev){
		import std.utf : toUTF8;
		ListBoxItem lbi = cast(ListBoxItem)ev.aux;
		if(selection == "window"){
			switch(lbi.getText(0)){
				case "name":
					eventStack.addToTop(new WindowRenameEvent(conv.to!string(ev.text.text)));
					return;
				case "title":
					eventStack.addToTop(new WindowRetitleEvent(ev.text.text));
					return;
				case "size:x":
					eventStack.addToTop(new WindowWidthChangeEvent(conv.to!int(ev.text.text)));
					return;
				case "size:y":
					eventStack.addToTop(new WindowHeightChangeEvent(conv.to!int(ev.text.text)));
					return;
				default:
					return;
			}
		}else{
			switch(lbi.getText(0)){
				case "text":
					eventStack.addToTop(new TextEditEvent(ev.text.text, selection));
					return;
				case "name":
					eventStack.addToTop(new RenameEvent(selection, conv.to!string(ev.text.text)));
					selection = conv.to!string(ev.text);
					return;
				case "position":
					dstring[] src = csvParser(ev.text.text, ';');
					if(src.length == 4){
						Coordinate c;
						foreach(s; src){
							if(!isInteger(s)){
								ewh.messageWindow("Format Error!", "Value is not integer!");
								return;
							}
						}
						c.left = conv.to!int(src[0]);
						c.top = conv.to!int(src[1]);
						c.right = conv.to!int(src[2]);
						c.bottom = conv.to!int(src[3]);
						eventStack.addToTop(new PositionEditEvent(c, selection));
					}else{
						ewh.messageWindow("Format Error!", "Correct format is: [int];[int];[int];[int];");
					}
					return;
				case "source":
					eventStack.addToTop(new SourceEditEvent(selection, conv.to!string(ev.text.text)));
					return;
				default:
					return;
			}
		}
	}
	public void clickEvent(int x, int y, int state){
		if(typeSel != ElementType.NULL) {
			if(state == ButtonState.PRESSED) {
				x0 = x;
				y0 = y;
			}else{
				Coordinate c;
				if(x > x0){
					c.left = x0;
					c.right = x;
				}else{
					c.left = x;
					c.right = x0;
				}
				if(y > y0){
					c.top = y0;
					c.bottom = y;
				}else{
					c.top = y;
					c.bottom = y0;
				}
				WindowElement we;
				string s;
				switch(typeSel){
					case ElementType.Label:
						s = getNextName("label");
						we = new Label(conv.to!dstring(s),s,c);
						break;
					case ElementType.Button:
						s = getNextName("button");
						we = new Button(conv.to!dstring(s),s,c);
						break;
					case ElementType.TextBox:
						s = getNextName("textBox");
						we = new TextBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.ListBox:
						s = getNextName("listBox");
						we = new ListBox(s,c,[], new ListBoxHeader(["col0", "col1"],[40,40]), 16);
						break;
					case ElementType.CheckBox:
						s = getNextName("CheckBox");
						we = new CheckBox(conv.to!dstring(s),s,c);
						break;
					case ElementType.RadioButton:
						s = getNextName("radioButton");
						we = new RadioButton(conv.to!dstring(s),s,c);
						break;
					/+case ElementType.MenuBar:
						s = getNextName("menuBar");
						we = new MenuBar(s,c,[new PopUpMenuElement("menu0","menu0")]);+/
						//break;
					case ElementType.HSlider:
						s = getNextName("hSlider");
						we = new HSlider(16,1,s,c);
						break;
					case ElementType.VSlider:
						s = getNextName("vSlider");
						we = new HSlider(16,1,s,c);
						break;
					default:
						break;
				}
				eventStack.addToTop(new PlacementEvent(we, typeSel, s));
				typeSel = ElementType.NULL;
				//updateElementList;
			}
		} else {
			if (state == ButtonState.PRESSED) {
				if(!moveElemMode) initElemMove;
				//stdio.writeln("element move mode is ", moveElemMode);
			} else {
				finalizeElemMove;
			}
		}
	}
	public void dragEvent(int x, int y, int relX, int relY, ubyte button) {
		if (moveElemMode) {
			const Coordinate temp = elements[selection].position;
			if(temp.left + relX < 0) relX -= temp.left + relX;
			if(temp.right + relX >= dw.position.width) relX -= (temp.right + relX) - dw.position.width;
			if(temp.top + relY < 0) relY -= temp.top + relY;
			if(temp.bottom + relY >= dw.position.height) relY -= (temp.bottom + relY) - dw.position.height;
			elements[selection].position.relMove(relX, relY);
			dw.draw();
		}
	}

	public void updateElementList(){
		ewh.objectList.clearData;
		ListBoxItem[] list = [new ListBoxItem(["window", ""])];
		foreach(s; elements.byKey){
			list ~= new ListBoxItem([conv.to!dstring(elements[s].classinfo.name[37..$]), conv.to!dstring(s)]);
		}
		ewh.objectList.updateColumns(list);
	}
	public void updatePropertyList(){
		import sdlang;
		import std.utf;
		ewh.propList.clearData;
		if(elements.get(selection, null) !is null){
			string classname = elements[selection].classinfo.name[37..$];
			ListBoxItem[] list = [new ListBoxItem(["name", conv.to!dstring(selection)], [TextInputType.NULL, TextInputType.TEXT]),
					new ListBoxItem(["source", conv.to!dstring(wserializer.getValue(selection, "source")[0].get!string())],
					[TextInputType.NULL, TextInputType.TEXT])];
			if(classname == "Label" || classname == "TextBox" || classname == "Button" || classname == "CheckBox" ||
					classname == "RadioButtonGroup"){
				list ~= new ListBoxItem(["text", toUTF32(wserializer.getValue(selection, "text")[0].get!string())], [
						TextInputType.NULL, TextInputType.TEXT]);
			}
			Value[] pos0 = wserializer.getValue(selection, "position");
			dstring pos1 = conv.to!dstring(pos0[0].get!int) ~ ";" ~ conv.to!dstring(pos0[1].get!int) ~ ";" ~
					conv.to!dstring(pos0[2].get!int) ~ ";" ~ conv.to!dstring(pos0[3].get!int) ~ ";";
			list ~= new ListBoxItem(["position", pos1], [TextInputType.NULL, TextInputType.TEXT]);
			switch(classname){
				case "Button", "SmallButton":
					list ~= new ListBoxItem(["icon", conv.to!dstring(wserializer.getValue(selection, "icon")[0].get!string())],
							[TextInputType.NULL, TextInputType.TEXT] );
					break;
				case "ListBox":
					list ~= new ListBoxItem(["header", "[...]"], [TextInputType.NULL, TextInputType.NULL]);
					break;
				case "RadioButtonGroup":
					dstring optionName;
					Value[] optionNameValues = wserializer.getValue(selection, "options");
					foreach(v ; optionNameValues){
						optionName ~= toUTF32(v.get!string()) ~ ';';
					}
					list ~= [new ListBoxItem(["rowHeight",conv.to!dstring(wserializer.getValue(selection,"rowHeight")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL]), new ListBoxItem(["options", optionName], [TextInputType.NULL,
							TextInputType.TEXT])];
					break;
				case "HSlider", "VSlider":
					list ~= [new ListBoxItem(["barLength",conv.to!dstring(wserializer.getValue(selection,"barLength")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL]),
							new ListBoxItem(["maxValue",conv.to!dstring(wserializer.getValue(selection,"maxValue")[0].get!int())],
							[TextInputType.NULL, TextInputType.DECIMAL])];
					break;
				default:
					break;
			}
			ewh.propList.updateColumns(list);
		}else{
			ListBoxItem[] list = [new ListBoxItem(["name", conv.to!dstring(wserializer.getWindowName)], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["title", toUTF32(wserializer.getWindowValue("title")[0].get!string())], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["size:x", conv.to!dstring(wserializer.getWindowValue("size:x")[0].get!int())], [TextInputType.NULL,
					TextInputType.TEXT]),
					new ListBoxItem(["size:y", conv.to!dstring(wserializer.getWindowValue("size:y")[0].get!int())], [TextInputType.NULL,
					TextInputType.TEXT])];

			ewh.propList.updateColumns(list);
		}
	}

	public void selectEvent(WindowElement we){
		foreach(s; elements.byKey){
			if(elements[s] == we){
				selection = s;
				updatePropertyList;
				return;
			}
		}
	}

	public void menuEvent(Event ev){
		switch(ev.source){
			case "Export":
				ewh.addWindow(new FileDialog("Export Window"d, "export", &onExportWindow,
						[FileDialog.FileAssociationDescriptor("D file"d, ["*.d"])], "./", true));
				break;
			case "saveAs":
				ewh.addWindow(new FileDialog("Save Window as"d, "windowsaver", &onSaveFileAs,
						[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./", true));
				break;
			case "save":
				if(wserializer.getFilename){
					wserializer.store;
				}else{
					ewh.addWindow(new FileDialog("Save Window as"d, "windowsaver", &onSaveFileAs,
							[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./", true));
				}
				break;
			case "load":
				//stdio.writeln(&onLoadFile);
				ewh.addWindow(new FileDialog("Load Window"d, "windowloader", &onLoadFile,
						[FileDialog.FileAssociationDescriptor("SDL file"d, ["*.sdl"])], "./"));
				break;
			case "undo":
				eventStack.undo;
				break;
			case "redo":
				eventStack.redo;
				break;
			case "exit":
				onQuit;
				break;
			case "Label":
				typeSel = ElementType.Label;
				break;
			case "Button":
				typeSel = ElementType.Button;
				break;
			case "TextBox":
				typeSel = ElementType.TextBox;
				break;
			case "ListBox":
				typeSel = ElementType.ListBox;
				break;
			case "CheckBox":
				typeSel = ElementType.CheckBox;
				break;
			case "RadioButton":
				typeSel = ElementType.RadioButton;
				break;
			case "MenuBar":
				typeSel = ElementType.MenuBar;
				break;
			case "HSlider":
				typeSel = ElementType.HSlider;
				break;
			case "VSlider":
				typeSel = ElementType.VSlider;
				break;
			default:
				break;
		}
	}
	public void delElement() {
		if(selection != "window")
			eventStack.addToTop(new DeleteEvent(elements[selection], selection));
	}
	public void initElemMove() {
		if(selection != "window") {
			moveElemMode = true;
			moveElemOrig = elements[selection].position;
		}
	}
	public void deinitElemMove() {
		if(moveElemMode) {
			moveElemMode = false;
			elements[selection].position = moveElemOrig;
			dw.draw();
		}
	}
	public void finalizeElemMove() {
		moveElemMode = false;
		Coordinate newPos = elements[selection].position;
		elements[selection].position = moveElemOrig;
		eventStack.addToTop(new MoveElemEvent(newPos, selection));
	}
	public void whereTheMagicHappens(){
		while(!onExit){
			mainRaster.refresh();
			inputH.test();
		}
	}
	public void onQuit(){
		onExit = true;
	}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype) {
		switch(ID){
			case "undo":
				if (!undoPressed) {
					undoPressed = true;
					eventStack.undo;
				}
				break;
			case "redo":
				if (!redoPressed) {
					redoPressed = true;
					eventStack.redo;
				}
				break;
			case "del":
				if (!delPressed) {
					delPressed = true;
					const string prevSelection = selection;
					selection = "window";
					eventStack.addToTop(new DeleteEvent(elements[prevSelection], prevSelection));
				}
				break;
			case "sysesc":
				deinitElemMove;
				typeSel = ElementType.NULL;
				break;
			default:
				break;
		}
	}
	public void keyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype) {
		switch(ID){
			case "undo":
				undoPressed = false;
				break;
			case "redo":
				redoPressed = false;
				break;
			case "del":
				delPressed = false;
				break;
			default:
				break;
		}
	}
}
