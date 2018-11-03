module editor;

import types;
import serializer;
import editorEvents;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.system.inputHandler;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.raster;
import PixelPerfectEngine.graphics.outputScreen;

import conv = std.conv;

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

	public void initGUI(){
		output.drawFilledRectangle(0, rasterX, 0, rasterY, 0x0005);

		PopUpMenuElement[] menuElements;
		menuElements ~= new PopUpMenuElement("file", "FILE");

		menuElements[0] ~= new PopUpMenuElement("new", "New window", "Ctrl + N");
		menuElements[0] ~= new PopUpMenuElement("load", "Load window", "Ctrl + L");
		menuElements[0] ~= new PopUpMenuElement("save", "Save window", "Ctrl + S");
		menuElements[0] ~= new PopUpMenuElement("saveAs", "Save window as", "Ctrl + Shift + S");
		menuElements[0] ~= new PopUpMenuElement("saveTemp", "Export window as D code", "Ctrl + Shift + I");
		menuElements[0] ~= new PopUpMenuElement("exit", "Exit application", "Alt + F4");

		menuElements ~= new PopUpMenuElement("edit", "EDIT");

		menuElements[1] ~= new PopUpMenuElement("undo", "Undo", "Ctrl + Z");
		menuElements[1] ~= new PopUpMenuElement("redo", "Redo", "Ctrl + Shift + Z");
		menuElements[1] ~= new PopUpMenuElement("copy", "Copy", "Ctrl + C");

		menuElements ~= new PopUpMenuElement("elements", "ELEMENTS");

		menuElements[2] ~= new PopUpMenuElement("Label", "Label", "Ctrl + F1");
		menuElements[2] ~= new PopUpMenuElement("Button", "Button", "Ctrl + F2");
		menuElements[2] ~= new PopUpMenuElement("TextBox", "TextBox", "Ctrl + F3");
		menuElements[2] ~= new PopUpMenuElement("ListBox", "ListBox", "Ctrl + F4");
		menuElements[2] ~= new PopUpMenuElement("CheckBox", "CheckBox", "Ctrl + F5");
		menuElements[2] ~= new PopUpMenuElement("RadioButtonGroup", "RadioButtonGroup", "Ctrl + F6");
		menuElements[2] ~= new PopUpMenuElement("MenuBar", "MenuBar", "Ctrl + F7");
		menuElements[2] ~= new PopUpMenuElement("HSlider", "HSlider", "Ctrl + F3");
		menuElements[2] ~= new PopUpMenuElement("VSlider", "VSlider", "Ctrl + F3");

		menuElements ~= new PopUpMenuElement("help", "HELP");

		menuElements[3] ~= new PopUpMenuElement("helpFile", "Content", "F1");
		menuElements[3] ~= new PopUpMenuElement("about", "About");

		MenuBar mb = new MenuBar("menubar",Coordinate(0,0,rasterX - 1,16),menuElements);
		addElement(mb, EventProperties.MOUSE);

		objectList = new ListBox("objectList", Coordinate(644,20,rasterX - 5,238), [], new ListBoxHeader(["Name"w,"Type"w],[128,128]),16);
		propList = new ListBox("propList", Coordinate(644,242,rasterX - 5,477), [], new ListBoxHeader(["Prop"w,"Val"w],[128,128]),16,true);
		addElement(objectList, EventProperties.MOUSE | EventProperties.SCROLL);
		addElement(propList, EventProperties.MOUSE | EventProperties.SCROLL);

		foreach(WindowElement we; elements){
			we.draw();
		}
		mb.onMouseLClickPre = &ie.menuEvent;
	}

	public override StyleSheet getStyleSheet(){
		return defaultStyle;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
		//we.al ~= this;
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

	public override void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}

	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
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

public class DummyWindow : Window{
	Editor ed;
	public this(Coordinate coordinates, wstring name, Editor ed){
		super(coordinates, name);
		this.ed = ed;
	}
	override public void passMouseEvent(int x,int y,int state,ubyte button) {
		//super.passMouseEvent(x,y,state,button);
		if(button == MouseButton.LEFT){
			ed.placementEvent(x,y,state);
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

}

public class Editor : SystemEventListener{
	EditorWindowHandler ewh;
	DummyWindow dw;
	SpriteLayer sprtL;
	Raster mainRaster;
	OutputScreen outScrn;
	InputHandler inputH;
	bool onExit;
	int x0, y0;
	ElementType typeSel;
	UndoableStack eventStack;
	WindowElement[string] elements;

	static string[ElementType] nameBases;
	public this(){
		import PixelPerfectEngine.system.systemUtility;
		sprtL = new SpriteLayer(LayerRenderingMode.COPY);
		outScrn = new OutputScreen("WindowMaker for PPE/Concrete",1696,960);
		mainRaster = new Raster(848,480,outScrn);
		mainRaster.addLayer(sprtL,0);
		typeSel = ElementType.NULL;

		ewh = new EditorWindowHandler(1696,960,848,480,sprtL, this);
		mainRaster.palette = [Color(0x00,0x00,0x00,0x00),	//transparent
	Color(0xFF,0xFF,0xFF,0xFF),		//normaltext
	Color(0xFF,0x77,0x77,0x77),		//window
	Color(0xFF,0xCC,0xCC,0xCC),		//windowascent
	Color(0xFF,0x33,0x33,0x33),		//windowdescent
	Color(0xff,0x22,0x22,0x22),		//windowinactive
	Color(0xff,0xff,0x00,0x00),		//selection
	Color(0xFF,0x77,0x77,0xFF),		//WHAascent
	Color(0xFF,0x00,0x00,0x77),		//WHAdescent
	Color(0xFF,0x00,0x00,0xDD),		//WHAtop
	Color(0xFF,0x00,0x00,0xFF),
	Color(0xFF,0x00,0x00,0x7F),
	Color(0xFF,0x22,0x22,0x22),
	Color(0xFF,0x22,0x22,0x22),		//secondarytext
	Color(0xFF,0x7F,0x7F,0x7F),
	Color(0xFF,0x00,0x00,0x00)];
		INIT_CONCRETE(ewh);
		inputH = new InputHandler();
		inputH.sel ~= this;
		inputH.ml ~= ewh;
		ewh.initGUI();
		dw = new DummyWindow(Coordinate(0,16,640,480), "New Window"w, this);
		ewh.addWindow(dw);
		eventStack = new UndoableStack(10);
		wserializer = new WindowSerializer();
		dwtarget = dw;
		editorTarget = this;
	}
	static this(){
		nameBases[ElementType.Label] = "label";
		nameBases[ElementType.Button] = "button";
		nameBases[ElementType.SmallButton] = "smallButton";
		nameBases[ElementType.TextBox] = "textBox";
		nameBases[ElementType.ListBox] = "listBox";
		nameBases[ElementType.RadioButtonGroup] = "radioButtonGroup";
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
	public void placementEvent(int x, int y, int state){
		if(typeSel != ElementType.NULL){
			if(state == ButtonState.PRESSED){
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
						we = new Label(conv.to!wstring(s),s,c);
						break;
					case ElementType.Button:
						s = getNextName("button");
						we = new Button(conv.to!wstring(s),s,c);
						break;
					case ElementType.TextBox:
						s = getNextName("textBox");
						we = new TextBox(conv.to!wstring(s),s,c);
						break;
					case ElementType.ListBox:
						s = getNextName("listBox");
						we = new ListBox(s,c,[], new ListBoxHeader(["col0", "col1"],[40,40]), 16);
						break;
					case ElementType.CheckBox:
						s = getNextName("textBox");
						we = new CheckBox(conv.to!wstring(s),s,c);
						break;
					case ElementType.RadioButtonGroup:
						s = getNextName("radioButtonGroup");
						we = new RadioButtonGroup(conv.to!wstring(s),s,c,["opt0", "opt1"],16,0);
						break;
					case ElementType.MenuBar:
						s = getNextName("menuBar");
						we = new MenuBar(s,c,[new PopUpMenuElement("menu0","menu0")]);
						break;
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
			}
		}
	}

	public void selectEvent(WindowElement we){

	}

	public void menuEvent(Event ev){
		switch(ev.source){
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
			case "RadioButtonGroup":
				typeSel = ElementType.RadioButtonGroup;
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
}
