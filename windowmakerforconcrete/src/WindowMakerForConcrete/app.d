import std.stdio;
import std.conv;

import PixelPerfectEngine.graphics.outputScreen;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.draw;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.extbmp.extbmp;

import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.system.file;
import PixelPerfectEngine.system.common;

import windowDataLoader;
import editEvents;
import elementTypes;

public class Main {
	private SpriteLayer sl;
	private OutputScreen os;
	private Raster mainRaster;
}

public class EditorWindowHandler : WindowHandler, ElementContainer, ActionListener{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	public ListBox componentList, prop;
	//private ListBoxColumn[] propTL, propSL, propSLE;
	//private ListBoxColumn[] layerListE;
	public Label[] labels;
	private int[] propTLW, propSLW, propSLEW;
	public DummyWindow dw;

	public MainApplication ma;

	private BitmapDrawer output;
	public this(int sx, int sy, int rx, int ry,ISpriteLayer16Bit sl){
		super(sx,sy,rx,ry,sl);
		output = new BitmapDrawer(rx, ry);
		addBackground(output.output);
		propTLW = [40, 320];
		propSLW = [160, 320, 48, 64];
		propSLEW = [160, 320, 40, 56];
	}

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);
		
		WindowElement.popUpHandler = this;
		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", "FILE");

		menuElements[0].setLength(6);
		menuElements[0][0] = new PopUpMenuElement("new", "New Window", "Ctrl + N");
		menuElements[0][1] = new PopUpMenuElement("load", "Load Window", "Ctrl + L");
		menuElements[0][2] = new PopUpMenuElement("save", "Save Window", "Ctrl + S");
		menuElements[0][3] = new PopUpMenuElement("saveAs", "Save Window As", "Ctrl + Shift + S");
		menuElements[0][4] = new PopUpMenuElement("export", "Export Dlang code", "Ctrl + Shift + X");
		menuElements[0][5] = new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "EDIT");
		
		menuElements[1].setLength(6);
		menuElements[1][0] = new PopUpMenuElement("undo", "Undo", "Ctrl + Z");
		menuElements[1][1] = new PopUpMenuElement("redo", "Redo", "Ctrl + Shift + Z");
		menuElements[1][2] = new PopUpMenuElement("copy", "Copy", "Ctrl + C");
		menuElements[1][3] = new PopUpMenuElement("cut", "Cut", "Ctrl + X");
		menuElements[1][4] = new PopUpMenuElement("paste", "Paste", "Ctrl + V");
		menuElements[1][5] = new PopUpMenuElement("editorSetup", "Editor Settings");

		menuElements ~= new PopUpMenuElement("item", "ITEMS");

		menuElements[2].setLength(9);
		menuElements[2][0] = new PopUpMenuElement("Label", "Label", "Ctrl + F1");
		menuElements[2][1] = new PopUpMenuElement("\\submenu\\", "Button", ">>>");
		menuElements[2][1].setLength(2);
		menuElements[2][1][0] = new PopUpMenuElement("Button", "Button", "Ctrl + F2");
		menuElements[2][1][1] = new PopUpMenuElement("SmallButton", "SmallButton", "Alt + F2");
		menuElements[2][2] = new PopUpMenuElement("TextBox", "TextBox", "Ctrl + F3");
		menuElements[2][3] = new PopUpMenuElement("ListBox", "ListBox", "Ctrl + F4");
		menuElements[2][4] = new PopUpMenuElement("CheckBox", "CheckBox", "Ctrl + F5");
		menuElements[2][5] = new PopUpMenuElement("RadioButtonGroup", "RadioButtonGroup", "Ctrl + F6");
		menuElements[2][6] = new PopUpMenuElement("VSlider", "VSlider", "Ctrl + F7");
		menuElements[2][7] = new PopUpMenuElement("HSlider", "HSlider", "Ctrl + F8");
		menuElements[2][8] = new PopUpMenuElement("MenuBar", "Menubar", "Ctrl + F9");

		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[3].setLength(2);
		menuElements[3][0] = new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[3][1] = new PopUpMenuElement("about", "About");
		
		addElement(new MenuBar("menubar",Coordinate(0,0,800,16),menuElements), EventProperties.MOUSE);
		
		ListBoxHeader componentListHeader = new ListBoxHeader(["Name","Type"],[100,160]);
		componentList = new ListBox("componentList", Coordinate(648,32,792,208),[],componentListHeader,16);
		addElement(componentList, EventProperties.MOUSE);

		ListBoxHeader propHeader = new ListBoxHeader(["Name","Value"],[160,160]);
		prop = new ListBox("prop", Coordinate(648,240,792,472),[],propHeader,16,true);
		addElement(prop, EventProperties.MOUSE);

		foreach(WindowElement we; elements){
			we.draw();
			//we.al ~= this;
			//we.al ~= mainApp;
		}

		dw = new DummyWindow(Coordinate(0,16,640,480),"New project");
		addWindow(dw);
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		we.al ~= this;
		if((eventProperties & EventProperties.KEYBOARD) == EventProperties.KEYBOARD){
			keyboardC ~= we;
		}
		if((eventProperties & EventProperties.MOUSE) == EventProperties.MOUSE){
			mouseC ~= we;
		}
		if((eventProperties & EventProperties.SCROLL) == EventProperties.SCROLL){
			scrollC ~= we;
		}
	}

	
	public void actionEvent(Event event){
		switch(event.source){
			case "exit":
				ma.onExit=true;
				break;
			case "componentList":
				if(event.aux){
					ListBoxItem lbi = cast(ListBoxItem)event.aux;
					loadParametersIntoListbox(prop, ma.windowData.getElementAttributes(to!string(lbi.getText(0))));
					ma.selectedElement = to!string(lbi.getText(0));
				}
				break;

			default:
				ma.actionEvent(event);
				break;
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	/*public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;
		
	}*/
	/*public Bitmap16Bit getStyleBrush(int style){
		return styleBrush[style];
	}*/
	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}
	
	public override void passMouseEvent(int x, int y, int state = 0){
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state);
				return;
			}
		}
	}
	public override void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
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

public class DummyWindow : Window {
	public this(Coordinate size, wstring title, string[] extraButtons = []){
		super(size, title, extraButtons);
	}
	override public void passMouseEvent(int x,int y,int state = 0) {
		//super.passMouseEvent(x,y,state);
	}
	
}
/**
 * It's recommended that the main meat of your application is in a separate class, with optional classes for different modules.
 * Use inheritance to monitor events.
 */
public class MainApplication : InputListener, MouseListener, SystemEventListener, ActionListener{
	public OutputScreen outScrn;
	public SpriteLayer sl;
	public EffectLayer el;
	public Raster rstr;
	public InputHandler input;
	public EditorWindowHandler ewh;
	public WindowElement[string] windowElements;
	public string selectedElement, windowName;
	public WindowData windowData;
	public bool onExit;
	private PlacementMode placementMode;
	private int placementX, placementY;
	public EventChainSystem ecs;
	public this(){
		sl = new SpriteLayer();
		ewh = new EditorWindowHandler(1600,960,800,480,sl);
		ecs = new EventChainSystem(20);

		Fontset defaultFont = loadFontsetFromXMP(new ExtendibleBitmap("system/sysfont.xmp"), "font");
		ExtendibleBitmap ssOrigin = new ExtendibleBitmap("system/sysdef.xmp");

		input = new InputHandler();
		input.ml ~= this;
		input.ml ~= ewh;
		input.il ~= this;
		input.sel ~= this;
		input.kb ~= KeyBinding(0, ScanCode.ESCAPE, 0, "sysesc", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(0, ScanCode.DELETE, 0, "deletthis", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.Z, 0, "undo", Devicetype.KEYBOARD, KeyModifier.LOCKKEYIGNORE);
		input.kb ~= KeyBinding(KeyModifier.LCTRL + KeyModifier.LSHIFT, ScanCode.Z, 0, "redo", Devicetype.KEYBOARD, KeyModifier.LOCKKEYIGNORE);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F2, 0, "Button", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F1, 0, "Label", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F3, 0, "TextBox", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F4, 0, "ListBox", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F8, 0, "HSlider", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F7, 0, "VSlider", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F6, 0, "RadioButtonGroup", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F5, 0, "CheckBox", Devicetype.KEYBOARD);
		input.kb ~= KeyBinding(KeyModifier.LCTRL, ScanCode.F9, 0, "MenuBar", Devicetype.KEYBOARD);
		
		PopUpElement.inputhandler = input;
		WindowElement.inputHandler = input;

		StyleSheet ss = new StyleSheet();

		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI0"),"closeButtonA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI1"),"closeButtonB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI0"),"checkBoxA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI1"),"checkBoxB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI2"),"radioButtonA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI3"),"radioButtonB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI4"),"upArrowA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI5"),"upArrowB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI6"),"downArrowA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI7"),"downArrowB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI8"),"plusA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUI9"),"plusB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUIA"),"minusA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUIB"),"minusB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUIC"),"leftArrowA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUID"),"leftArrowB");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUIE"),"rightArrowA");
		ss.setImage(loadBitmapFromXMP(ssOrigin,"GUIF"),"rightArrowB");
		ss.addFontset(defaultFont, "default");
		ewh.defaultStyle = ss;
		Window.defaultStyle = ss;
		ewh.initGUI();
		ewh.ma = this;

		windowData = new WindowData();
		windowName = "NewWindow";

		outScrn = new OutputScreen("Windowmaker for PPE/Concrete", 1600, 960);
		rstr = new Raster(800,480,outScrn);
		//rstr.setupPalette(256);
		rstr.addLayer(sl, 0);
		rstr.palette.reserve(1024);
		/*foreach(c ; StyleSheet.defaultpaletteforGUI)
			rstr.palette ~= c;*/
		rstr.palette ~= [Color(0x00,0x00,0x00,0x00),Color(0xFF,0xFF,0xFF,0xFF),Color(0xFF,0x34,0x9e,0xff),Color(0xff,0xa2,0xd7,0xff),	
					Color(0xff,0x00,0x2c,0x59),Color(0xff,0x00,0x75,0xe7),Color(0xff,0xff,0x00,0x00),Color(0xFF,0x7F,0x00,0x00),
					Color(0xFF,0x00,0xFF,0x00),Color(0xFF,0x00,0x7F,0x00),Color(0xFF,0x00,0x00,0xFF),Color(0xFF,0x00,0x00,0x7F),
					Color(0xFF,0xFF,0xFF,0x00),Color(0xFF,0xFF,0x7F,0x00),Color(0xFF,0x7F,0x7F,0x7F),Color(0xFF,0x00,0x00,0x00)];
		updateElementList();
	}
	public void whereTheMagicHappens(){
		while(!onExit){
			input.test();
			rstr.refresh();
		}
	}
	public string getNextAvailableElementID(string base){
		int i;
		while(true){
			i++;
			if(windowElements.get(base ~ to!string(i), null) is null){
				return base ~ to!string(i);
			}
		}
		//return null;
	}
	public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype){
		writeln(ID);
		switch(ID){
			case "sysesc":
				placementMode = PlacementMode.NULL;
				placementX = 0;
				placementY = 0;
				break;
			case "deletthis":
				ewh.dw.removeElement(windowElements[selectedElement]);
				windowElements.remove(selectedElement);
				windowData.removeElement(selectedElement);
				updateElementList();
				break;
			case "Button":
				placementMode = PlacementMode.Button;
				break;
			case "Label":
				placementMode = PlacementMode.Label;
				break;
			case "TextBox":
				placementMode = PlacementMode.TextBox;
				break;
			case "ListBox":
				placementMode = PlacementMode.ListBox;
				break;
			case "HSlider":
				placementMode = PlacementMode.HSlider;
				break;
			case "VSlider":
				placementMode = PlacementMode.VSlider;
				break;
			case "RadioButtonGroup":
				placementMode = PlacementMode.RadioButtonGroup;
				break;
			case "CheckBox":
				placementMode = PlacementMode.CheckBox;
				break;
			case "MenuBar":
				placementMode = PlacementMode.MenuBar;
				break;
			default:
				break;
		}
	}
	public void keyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype){}
	public void mouseButtonEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y){
		x/=2;
		y/=2;
		if(placementMode != PlacementMode.NULL){
			writeln(x,",",y);
			if(state == ButtonState.RELEASED){
				Coordinate c;
				if(x < placementX && y < placementY)
					c = Coordinate(x, y, placementX, placementY);
				else
					c = Coordinate(placementX, placementY, x, y);
				c.relMove(ewh.dw.position.left, ewh.dw.position.top * -1);
				switch(placementMode){
					case PlacementMode.Button:
						string id = getNextAvailableElementID("button");
						WindowElement e = new Button(to!wstring(id), id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;
						windowData.addWindowElement("Button",id,to!wstring(id),c);
						break;
					case PlacementMode.SmallButton: 
						/*string id = getNextAvailableElementID("smallButton");
						WindowElement e = new SmallButton(to!wstring(id), id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;*/
						break;
					case PlacementMode.Label: 
						string id = getNextAvailableElementID("label");
						WindowElement e = new Label(to!wstring(id), id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;
						windowData.addWindowElement("Label",id,to!wstring(id),c);
						break;
					case PlacementMode.CheckBox: 
						string id = getNextAvailableElementID("checkBox");
						WindowElement e = new CheckBox(to!wstring(id), id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;
						windowData.addWindowElement("CheckBox",id,to!wstring(id),c);
						break;
					case PlacementMode.HSlider: 
						string id = getNextAvailableElementID("hSlider");
						WindowElement e = new HSlider(10, 1, id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;
						windowData.addWindowElement("HSlider",id,to!wstring(id),c);
						break;
					case PlacementMode.VSlider:
						string id = getNextAvailableElementID("vSlider");
						WindowElement e = new VSlider(10, 1, id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e; 
						windowData.addWindowElement("VSlider",id,to!wstring(id),c);
						break;
					case PlacementMode.ListBox:
						string id = getNextAvailableElementID("listBox");
						WindowElement e = new ListBox(id, c, [], new ListBoxHeader(["col0", "col1"], [40,40]), 16);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e; 
						windowData.addWindowElement("ListBox",id,to!wstring(id),c);
						break;
					case PlacementMode.MenuBar:
						string id = getNextAvailableElementID("menuBar");
						WindowElement e = new MenuBar(id, c, [new PopUpMenuElement(id ~ ".0","menu0"),new PopUpMenuElement(id ~ ".1","menu1")]);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e; 
						windowData.addWindowElement("MenuBar",id,to!wstring(id),c);
						break;
					case PlacementMode.RadioButtonGroup: 
						string id = getNextAvailableElementID("radioButtonGroup");
						WindowElement e = new RadioButtonGroup(to!wstring(id), id, c, ["option0", "option1"], 16, 0);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e;
						windowData.addWindowElement("RadioButtonGroup",id,to!wstring(id),c);
						break;
					case PlacementMode.TextBox:
						string id = getNextAvailableElementID("textBox");
						WindowElement e = new TextBox(to!wstring(id), id, c);
						ecs.appendEvent(new ObjectPlacementEvent(id, e));
						placementMode = PlacementMode.NULL;
						windowElements[id] = e; 
						windowData.addWindowElement("TextBox",id,to!wstring(id),c);
						break;

					default: break;
				}
				updateElementList();
				placementX = 0;
				placementY = 0;
			}else{
				placementX = x;
				placementY = y;
			}
		}
	}
	public void updateElementList(){
		import PixelPerfectEngine.system.etc;
		wstring[2][] e = windowData.getElements();
		ewh.componentList.clearData();
		ListBoxItem[] newItems;
		newItems.length = e.length;
		for(int i ; i < e.length ; i++){
			newItems[i] = new ListBoxItem(e[i]);
		}
		//writeln(newItems);
		ewh.componentList.updateColumns(newItems);
	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		if(placementMode != PlacementMode.NULL){
			
		}
	}
	public void onQuit(){
		onExit = true;
	}
	public void controllerRemoved(uint ID){}
	public void controllerAdded(uint ID){}
	public void actionEvent(Event event){
		writeln(event.source,", ", event.subsource);
		switch(event.source){
			case "exit":
				onExit=true;
				break;
			case "prop":
				if(event.type == EventType.TEXTINPUT){
					try{
						ListBoxItem lbi = cast(ListBoxItem)event.aux;
						windowData.editElementAttribute(selectedElement, to!string(lbi.getText(0)), event.text);
						if(windowElements.get(selectedElement, null)){
							switch(lbi.getText(0)){
								case "Coordinate:top":
									windowElements[selectedElement].position.top = to!int(event.text);
									break;
								case "Coordinate:left":
									windowElements[selectedElement].position.left = to!int(event.text);
									break;
								case "Coordinate:bottom":
									windowElements[selectedElement].position.bottom = to!int(event.text);
									break;
								case "Coordinate:right":
									windowElements[selectedElement].position.right = to!int(event.text);
									break;
								case "name":
									windowElements[to!string(event.text)] = windowElements[selectedElement];
									windowElements.remove(selectedElement);
									selectedElement = to!string(event.text);
									updateElementList();
									break;
								case "text":
									windowElements[selectedElement].setText(event.text);
									break;
								default:
									break;
							}
							windowElements[selectedElement].draw();
							ewh.dw.draw();
						}else{
							switch(lbi.getText(0)){
								case "width":
									ewh.dw.setWidth(to!int(event.text));
									break;
								case "height":
									ewh.dw.setHeight(to!int(event.text));
									break;
								case "title":
									ewh.dw.setTitle(event.text);
									break;
								default:
									break;
							}
							
						}
					}catch(Exception e){
						writeln(e);
					}
				}
				break;
			case "load":
				ewh.addWindow(new FileDialog("Load Window"w, "loadDialog", this, [FileDialog.FileAssociationDescriptor("SDLang file"w, ["*.sdl"])], "./", false));
				break;
			case "loadDialog":
				try{
					windowData = new WindowData(event.path);
					ewh.closeWindow(ewh.dw);
					windowElements = windowData.deserialize(event.path ~ event.filename);
					updateElementList();
					ewh.addWindow(ewh.dw);
					ewh.dw.relMove(0,16);
				}catch(Exception e){
					writeln(e);
				}
				break;
			case "save":
				if(windowData.filename.length){
					windowData.serialize(windowData.filename);
				}else{
					ewh.addWindow(new FileDialog("Save Window"w, "saveDialog", this, [FileDialog.FileAssociationDescriptor("SDLang file"w, ["*.sdl"])], "./", true));
				}
				break;
			case "saveAs":
				ewh.addWindow(new FileDialog("Save Window"w, "saveDialog", this, [FileDialog.FileAssociationDescriptor("SDLang file"w, ["*.sdl"])], "./", true));
				break;
			case "saveDialog":
				try{
					windowData.serialize(event.path ~ event.filename);
				}catch(Exception e){
					writeln(e);
				}
				break;
			case "export":
				ewh.addWindow(new FileDialog("Export to D file"w, "exportDialog", this, [FileDialog.FileAssociationDescriptor("D file"w, ["*.d"])], "./", true));
				break;
			case "exportDialog":
				try{
					windowData.exportToDLangFile(event.path ~ event.filename);
				}catch(Exception e){
					writeln(e);
				}
				break;
			case "new":
				break;
			case "Button":
				placementMode = PlacementMode.Button;
				break;
			case "Label":
				placementMode = PlacementMode.Label;
				break;
			case "TextBox":
				placementMode = PlacementMode.TextBox;
				break;
			case "ListBox":
				placementMode = PlacementMode.ListBox;
				break;
			case "HSlider":
				placementMode = PlacementMode.HSlider;
				break;
			case "VSlider":
				placementMode = PlacementMode.VSlider;
				break;
			case "RadioButtonGroup":
				placementMode = PlacementMode.RadioButtonGroup;
				break;
			case "CheckBox":
				placementMode = PlacementMode.CheckBox;
				break;
			case "MenuBar":
				placementMode = PlacementMode.MenuBar;
				break;
			default:
				
				break;
		}
	}
}

public enum PlacementMode : ubyte{
	NULL			=	0,
	Button			=	1,
	SmallButton		=	2,
	TextBox			=	3,
	ListBox			=	4,
	CheckBox		=	5,
	RadioButtonGroup	=	6,
	VSlider			=	7,
	HSlider			=	8,
	MenuBar			=	9,
	Label			=	10,
}

/**
 * Use the main function to construct your class. Make sure you call the loop outside the constructor for readability, to follow Object-Oriented paradigms, also this enables
 * the GC to clean up certain stuff not needed after the initialization.
 */
int main(string[] argv){
	initialzeSDL();
	SDL_SetHint(SDL_HINT_WINDOWS_DISABLE_THREAD_NAMING, "1");
	
	mainApp = new MainApplication();
    if(argv.length > 1){
		
	}
	mainApp.whereTheMagicHappens();
    return 0;
}

static MainApplication mainApp;