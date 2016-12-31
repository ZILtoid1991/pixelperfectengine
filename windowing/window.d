/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, windowing.window module
 */

module windowing.window;

import graphics.bitmap;
import graphics.draw;
import graphics.layers;

public import windowing.elements;
public import windowing.stylesheet;
import system.etc;
import system.inputHandler;

import std.algorithm.mutation;
import std.stdio;
import std.conv;
import std.file;
import std.datetime;

public class Window : ElementContainer{
	private WindowElement[] elements, mouseC, keyboardC, scrollC;
	public wstring title;
	public IWindowHandler parent;
	//public Bitmap16Bit[int] altStyleBrush;
	public BitmapDrawer output;
	public int header, sizeX, sizeY;
	private int moveX, moveY;
	private bool move, fullUpdate;
	private string[] extraButtons;
	public Coordinate position;
	public StyleSheet customStyle;
	/**
	 * If the current window doesn't contain a custom StyleSheet, it gets from it's parent. 
	 */
	public StyleSheet getStyleSheet(){
		if(customStyle is null)
			return parent.getStyleSheet();
		return customStyle;
	}

	public void drawUpdate(WindowElement sender){
		/*if(!fullUpdate){ 
			this.draw();
		}*/
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}

	/*public Bitmap16Bit[wchar] getFontSet(int style){
		return parent.getFontSet(style);
	}*/
	/**
	 * Standard constructor. "size" sets both the initial position and the size of the window. 
	 * Extra buttons are handled from the StyleSheet, even numbers are unpressed, odd numbers are pressed.
	 */
	public this(Coordinate size, wstring title, string[] extraButtons = []){
		position = size;
		output = new BitmapDrawer(position.getXSize, position.getYSize);
		this.title = title;
		sizeX = position.getXSize;
		sizeY = position.getYSize;
		//style = 0;
		//closeButton = 2;
		this.extraButtons = extraButtons;
	}

	public void addElement(WindowElement we, int eventProperties){
		elements ~= we;
		we.elementContainer = this;
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

	public void draw(){

		output.drawFilledRectangle(0, position.getXSize() - 1, 0, position.getYSize() - 1, getStyleSheet().getColor("window"));
		output.insertBitmap(0,0,getStyleSheet().getImage("closeButtonA"));
		int x1 = getStyleSheet().getImage("closeButtonA").getX(), y1 = getStyleSheet().getImage("closeButtonA").getY();
		/*output.drawRectangle(x1, sizeX - 1, 0, y1, getStyleBrush(header));
		output.drawFilledRectangle(x1 + (x1/2), sizeX - 1 - (x1/2), y1/2, y1 - (y1/2), getStyleBrush(header).readPixel(x1/2, y1/2));*/

		int headerLength = extraButtons.length == 0 ? position.getXSize() - 1 : position.getXSize() - 1 - ((extraButtons.length/2) * x1) ;
		//drawing the header
		output.drawLine(x1, headerLength, 0, 0, getStyleSheet().getColor("windowascent"));
		output.drawLine(x1, x1, 0, y1 - 1, getStyleSheet().getColor("windowascent"));
		output.drawLine(x1, headerLength, y1 - 1, y1 - 1, getStyleSheet().getColor("windowdescent"));
		output.drawLine(headerLength, headerLength, 0, y1 - 1, getStyleSheet().getColor("windowdescent"));

		//drawing the border of the window
		output.drawLine(0, position.getXSize() - 1, y1, y1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, 0, y1, position.getYSize() - 1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, position.getXSize() - 1, position.getYSize() - 1, position.getYSize() - 1,  getStyleSheet().getColor("windowdescent"));
		output.drawLine(position.getXSize() - 1, position.getXSize() - 1, y1, position.getYSize() - 1, getStyleSheet().getColor("windowdescent"));

		//output.drawText(x1+1, 1, title, getFontSet(0), 1);
		output.drawText(x1, (y1-getStyleSheet().getFontset("default").getSize())/2, title, getStyleSheet().getFontset("default"),1);
		fullUpdate = true;
		foreach(WindowElement we; elements){
			we.draw();
			//output.insertBitmap(we.getPosition().xa,we.getPosition().ya,we.output.output);
		}
		fullUpdate = false;
	}

	public void passMouseEvent(int x, int y, int state = 0){
		//writeln(x, ",", y);
		if(getStyleSheet.getImage("closeButtonA").getX() > x && getStyleSheet.getImage("closeButtonA").getY() > y && state == 0){
			parent.closeWindow(this);
			return;
		}else if(getStyleSheet.getImage("closeButtonA").getY() > y && state == 0){
			/*if(state == 0 && !move){
				move = true;
				moveY = y;
			}
			if(state == 1 && move){
				move = false;
				position.move(x - moveX, y - moveY);
				parent.moveUpdate(this);
			}*/
			parent.moveUpdate(this);
		}
		//x -= position.xa;
		//y -= position.ya;
		foreach(WindowElement e; mouseC){
			if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
				e.onClick(x - e.getPosition().left, y - e.getPosition().top, state);
				return;
			}
		}

	}
	public void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){

				e.onScroll(x, y, wX, wY);
				return;
			}
		}
	}
	public void extraButtonEvent(int num){

	}
	public void passKeyboardEvent(wchar c, int type, int x, int y){

	}
	public void addParent(IWindowHandler wh){
		parent = wh;
	}
	public void getFocus(WindowElement sender){

	}
	public void dropFocus(WindowElement sender){

	}
}

public class TextInputDialog : Window, ActionListener{
	public ActionListener[] al;
	private TextBox textInput;
	private string source;

	public this(Coordinate size, string source, wstring title, wstring message, wstring text = ""){
		this(size, title);
		Label msg = new Label(message, "null", Coordinate(8, 20, size.getXSize()-8, 39));
		addElement(msg, EventProperties.MOUSE);

		textInput = new TextBox(text, "textInput", Coordinate(8, 40, size.getXSize()-8, 59));
		addElement(textInput, EventProperties.MOUSE);

		Button ok = new Button("Ok","ok", Coordinate(size.getXSize()-48,65,size.getXSize()-8,84));
		ok.al ~= this;
		addElement(ok,EventProperties.MOUSE);
		this.source = source;
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}

	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		if(event.source == "ok"){
			foreach(a; al){
				a.actionEvent(new Event(this.source, "TextInputDialog", null, null, textInput.getText(), 0, EventType.TEXTINPUT));
			}
			parent.closeWindow(this);
		}
	}
}

public class DefaultDialog : Window, ActionListener{
	public ActionListener[] al;
	private string source;

	public this(Coordinate size, string source, wstring title, wstring message, wstring[] options = ["Ok"]){
		this(size, title);
		//generate text
		//NOTE: currently only works with one line texts, later on multi-line texts will be added
		//NOTE: currently only optimized for 8 pixel wide fonts
		this.source = source;
		int x1 , x2;
		//writeln(x1,',',size.getXSize - x1);
		Label msg = new Label(message, "null", Coordinate(8, 20, size.getXSize()-8, 40));
		addElement(msg, EventProperties.MOUSE);

		//generate buttons

		x1 = size.getXSize - 10;
		Button[] buttons;
		for(int i; i < options.length; i++){
			x2 = x1 - ((options[i].length + 2) * 8);
			buttons ~= new Button(options[i], to!string(options[i]), Coordinate(x2, 40, x1, 60));
			buttons[i].al ~= this;
			addElement(buttons[i], EventProperties.MOUSE);
			x1 = x2;
		}
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}

	public void actionEvent(string source, int type, int value, wstring message){
		foreach(a; al){
			//a.actionEvent(source, this.source, type, value, message);
			a.actionEvent(new Event(source, this.source, null, null, null, 0, EventType.CLICK));
		}
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		foreach(a; al){
			//a.actionEvent(source, this.source, type, value, message);
			a.actionEvent(new Event(event.source, this.source, null, null, null, 0, EventType.CLICK));
		}
	}
}

public class FileDialog : Window, ActionListener{
	private ActionListener al;
	private string source;
	private string[] filetypes, pathList, driveList;
	private string directory, filename;
	private ListBox lb;
	private TextBox tb;
	private ListBoxColumn[] columns;
	private bool save;
	public static const string subsourceID = "filedialog";


	public this(wstring title, string source, ActionListener a, string[] filetypes, string startDir, bool save = false, string filename = ""){
		this(Coordinate(20,20,240,198), title);
		this.source = source;
		this.filetypes = filetypes;
		this.save = save;
		al = a;
		directory = startDir;
		//generate buttons
		Button[] buttons;
		buttons ~= new Button("Up","up",Coordinate(4, 154, 54, 174));
		buttons ~= new Button("Drive","drv",Coordinate(58, 154, 108, 174));
		if(save)
			buttons ~= new Button("Save","ok",Coordinate(112, 154, 162, 174));
		else
			buttons ~= new Button("Load","ok",Coordinate(112, 154, 162, 174));
		buttons ~= new Button("Close","close",Coordinate(166, 154, 216, 174));
		for(int i; i < buttons.length; i++){
			buttons[i].al ~= this;
			addElement(buttons[i], EventProperties.MOUSE);
		}
		//generate textbox
		tb = new TextBox(to!wstring(filename), "filename", Coordinate(4, 130, 162, 150));
		//tb.addTextInputHandler(tih);
		tb.al ~= this;
		addElement(tb, EventProperties.MOUSE);
		//generate listbox

		//test parameters

		//writeln(dirEntries(startDir, SpanMode.shallow));


		columns ~= ListBoxColumn("Name", ["aaa","aaa","aaa","aaa","aaa","aaa","aaa"]);
		columns ~= ListBoxColumn("Type", ["bbb","bbb","bbb","bbb","aaa","aaa","aaa"]);
		//Date format: yyyy-mm-dd hh:mm:ss
		columns ~= ListBoxColumn("Date", ["yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss","yyyy-mm-dd hh:mm:ss"]);
		spanDir();

		//writeln(pathList);

		//VSlider vsl = new VSlider(20,5,"sld",Coordinate(200,20,216,124));
		//addElement(vsl, EventProperties.MOUSE);
		//HSlider hsl = new HSlider(200,48,"vsld",Coordinate(4, 108, 200, 124));
		//addElement(hsl, EventProperties.MOUSE);
		lb = new ListBox("lb", Coordinate(4, 20, 216, 126),columns ,[160, 40, 176] ,15);
		addElement(lb, EventProperties.MOUSE | EventProperties.SCROLL);
		//scrollC ~= lb;
		lb.al ~= this;
		detectDrive();
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}

	private void spanDir(){
		pathList.length = 0;
		columns[0].elements.length = 0;
		columns[1].elements.length = 0;
		columns[2].elements.length = 0;
		foreach(DirEntry de; dirEntries(directory, SpanMode.shallow)){
			if(de.isDir){
				pathList ~= de.name;
				columns[0].elements ~= to!wstring(getFilenameFromPath(de.name));
				columns[1].elements ~= "<DIR>";
				columns[2].elements ~= formatDate(de.timeLastModified);
			}
		}
		foreach(ft; filetypes){
			foreach(DirEntry de; dirEntries(directory, ft, SpanMode.shallow)){
				if(de.isFile){
					pathList ~= de.name;
					columns[0].elements ~= to!wstring(getFilenameFromPath(de.name, true));
					columns[1].elements ~= to!wstring(ft);
					columns[2].elements ~= formatDate(de.timeLastModified);
			}
			}
		}


	}

	private wstring formatDate(SysTime time){
		wstring s;
		s ~= to!wstring(time.year());
		s ~= "-";
		s ~= to!wstring(time.month());
		s ~= "-";
		s ~= to!wstring(time.day());
		s ~= " ";
		s ~= to!wstring(time.hour());
		s ~= ":";
		s ~= to!wstring(time.minute());
		s ~= ":";
		s ~= to!wstring(time.second());
		//writeln(s);
		return s;
	}

	private void detectDrive(){
		driveList.length = 0;
		for(char c = 'A'; c <='Z'; c++){
			string s;
			s ~= c;
			s ~= ":\x5c";
			if(exists(s)){
				driveList ~= (s);
			}
		}
		//writeln(driveList);
	}

	private string getFilenameFromPath(string p, bool b = false){
		int n, m = p.length;
		string s;
		for(int i ; i < p.length ; i++){
			if(p[i] == '\x5c'){
				n = i;
			}
		}
		//n++;
		if(b){
			for(int i ; i < p.length ; i++){
				if(p[i] == '.'){
					m = i;
				}
			}
		}
		for( ; n < m ; n++){
			if(p[n] < 128 && p[n] > 31)
				s ~= p[n];
		}
		return s;
	}

	private void up(){
		int n;
		for(int i ; i < directory.length ; i++){
			if(directory[i] == '\x5c'){
				n = i;
			}
		}
		string newdir;
		for(int i ; i < n ; i++){
			newdir ~= directory[i];
		}
		directory = newdir;
		spanDir();
		lb.updateColumns(columns);
		lb.draw();
	}

	private void changeDrive(){
		pathList.length = 0;
		columns[0].elements.length = 0;
		columns[1].elements.length = 0;
		columns[2].elements.length = 0;
		foreach(string drive; driveList){
			pathList ~= drive;
			columns[0].elements ~= to!wstring(drive);
			columns[1].elements ~= "<DRV>";
			columns[2].elements ~= "N/A";
		}
		lb.updateColumns(columns);
		lb.draw();
	}

	private void fileEvent(){
		//wstring s = to!wstring(directory);
		filename = to!string(tb.getText);
		//al.actionEvent("file", EventType.FILEDIALOGEVENT, 0, s);
		al.actionEvent(new Event(source, "filedialog", directory, filename, null, 0, EventType.FILEDIALOGEVENT));
		parent.closeWindow(this);
	}

	public void actionEvent(string source, int type, int value, wstring message){
		/*if(source == "lb"){
			//writeln(value);

		}else if(source == "up"){
			up();
		}else if(source == "drv"){
			changeDrive();
		}else if(source == "ok"){
			fileEvent();
		}else if(source == "close"){
			parent.closeWindow(this);
		}*/
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		writeln(event.source);
		switch(event.source){
			case "lb":
				try{
					if(isDir(pathList[event.value])){
						directory = pathList[event.value];
						spanDir();
						lb.updateColumns(columns);
						lb.draw();
						
					}else{
						filename = getFilenameFromPath(pathList[event.value]);
						tb.setText(to!wstring(filename));
					}
				}catch(Exception e){
					writeln(e.msg);
				}
				break;
			case "up": up(); break;
			case "drv": changeDrive(); break;
			case "ok": fileEvent(); break;
			case "close": parent.closeWindow(this); break;
			default: break;
		}
	}
}

public class WindowHandler : InputListener, MouseListener, IWindowHandler{
	private Window[] windows;
	private int[] priorities;
	public int screenX, screenY, rasterX, rasterY, moveX, moveY;
	//public Bitmap16Bit[wchar] basicFont, altFont, alarmFont;
	public StyleSheet defaultStyle;
	//public Bitmap16Bit[int] styleBrush;
	private Bitmap16Bit background;
	private ISpriteLayer16Bit spriteLayer;
	private bool moveState, dragEventState;
	private Window windowToMove, dragEventDest;

	public this(int sx, int sy, int rx, int ry,ISpriteLayer16Bit sl){
		screenX = sx;
		screenY = sy;
		rasterX = rx;
		rasterY = ry;
		spriteLayer = sl;
	}

	public void addWindow(Window w){
		windows ~= w;
		w.addParent(this);
		//priorities ~= 666;
		w.draw();
		setWindowToTop(w);

		/*for(int i ; i < windows.length ; i++){
			spriteLayer.addSprite(windows[i].output.output, i, windows[i].position);
		}*/
	}

	public void addBackground(Bitmap16Bit b){
		background = b;
		spriteLayer.addSprite(background, 65536, 0, 0);
	}

	private int whichWindow(Window w){
		for(int i ; i < windows.length ; i++){
			if(windows[i] == w){
				return i;
			}
		}
		return -1;
	}

	public void setWindowToTop(Window sender){
		int s;
		foreach(Window w; windows){
			if(w == sender){
				Window ww = windows[s];
				windows[s] = windows[0];
				windows[0] = ww;
				updateSpriteOrder();
				break;
			}else{
				s++;
			}
		}

	}

	private void updateSpriteOrder(){
		for(int i ; i < windows.length ; i++){
			spriteLayer.removeSprite(i);
			spriteLayer.addSprite(windows[i].output.output, i, windows[i].position);

		}
	}

	/*public Bitmap16Bit[wchar] getFontSet(int style){
		switch(style){
			case 0: return basicFont;
			case 1: return altFont;
			case 3: return alarmFont;
			default: break;
		}
		return basicFont;

	}*/
	public StyleSheet getStyleSheet(){
		return defaultStyle;
	}
	public void closeWindow(Window sender){
		int p = whichWindow(sender);
		for(int i ; i < windows.length ; i++)
			spriteLayer.removeSprite(i);
		//spriteLayer.removeSprite(p);
		windows = remove(windows, p);

		updateSpriteOrder();
	}

	public void moveUpdate(Window sender){
		moveState = true;
		windowToMove = sender;
		//writeln(moveState);
	}
	public void keyPressed(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){

	}
	public void keyReleased(string ID, Uint32 timestamp, Uint32 devicenumber, Uint32 devicetype){

	}
	public void mouseButtonEvent(Uint32 which, Uint32 timestamp, Uint32 windowID, Uint8 button, Uint8 state, Uint8 clicks, Sint32 x, Sint32 y){

		//converting the dimensions
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);


		if(state == SDL_RELEASED && moveState){
			/*windowToMove.position.relMove(x - moveX, y - moveY);
			spriteLayer.relMoveSprite(whichWindow(windowToMove), x - moveX, y - moveY);*/
			//writeln(x - moveX, y - moveY);
			moveState = false;
		}else if(state == SDL_RELEASED && moveState){
			dragEventState = false;
		}
		else if(state == SDL_PRESSED){
			moveX = x; 
			moveY = y;

			for(int i ; i < windows.length ; i++){
				//writeln(i);
				if(x >= windows[i].position.left && x <= windows[i].position.right && y >= windows[i].position.top && y <= windows[i].position.bottom){
					if(i == 0){
						windows[0].passMouseEvent(x - windows[0].position.left, y - windows[0].position.top, 0);
						if(windows.length !=0){
							dragEventState = true;
							dragEventDest = windows[0];
						}
						return;
					}
					else{
						setWindowToTop(windows[i]);
						return;
					}
				}
			}
			passMouseEvent(x,y);
		}

	}
	public void passMouseEvent(int x, int y, int state = 0){

	}
	public void mouseWheelEvent(uint type, uint timestamp, uint windowID, uint which, int x, int y, int wX, int wY){
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		wX = to!int(wX * xR);
		wY = to!int(wY * yR);
		if(windows.length != 0)
			windows[0].passScrollEvent(wX - windows[0].position.left, wY - windows[0].position.top, y, x);
		passScrollEvent(wX,wY,x,y);
	}
	public void passScrollEvent(int wX, int wY, int x, int y){

	}
	public void mouseMotionEvent(uint timestamp, uint windowID, uint which, uint state, int x, int y, int relX, int relY){
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);
		relX = to!int(relX * xR);
		relY = to!int(relY * yR);
		if(state == SDL_PRESSED && moveState){
			windowToMove.position.relMove(relX, relY);
			spriteLayer.relMoveSprite(whichWindow(windowToMove), relX, relY);
		}else if(state == SDL_PRESSED && dragEventState){
			dragEventDest.passMouseEvent(x - dragEventDest.position.left,y - dragEventDest.position.top,-1);
		}
	}
}

public interface IWindowHandler{
	//public Bitmap16Bit[wchar] getFontSet(int style);
	public StyleSheet getStyleSheet();
	public void closeWindow(Window sender);
	public void moveUpdate(Window sender);
	public void setWindowToTop(Window sender);
	public void addWindow(Window w);
}

public enum EventProperties : uint{
	KEYBOARD		=	1,
	MOUSE			=	2,
	SCROLL			=	4
}