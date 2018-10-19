/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.window module
 */

module PixelPerfectEngine.concrete.window;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
import PixelPerfectEngine.graphics.layers;

public import PixelPerfectEngine.concrete.elements;
public import PixelPerfectEngine.concrete.stylesheet;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.inputHandler;

import std.algorithm.mutation;
import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.datetime;

/**
 * Basic window. All other windows are inherited from this class.
 */
public class Window : ElementContainer{
	protected WindowElement[] elements, mouseC, keyboardC, scrollC;
	protected wstring title;
	protected WindowElement draggedElement;
	public IWindowHandler parent;
	//public Bitmap16Bit[int] altStyleBrush;
	public BitmapDrawer output;
	public int header;//, sizeX, sizeY;
	protected int moveX, moveY;
	protected bool fullUpdate;
	protected string[] extraButtons;
	public Coordinate position;
	public StyleSheet customStyle;
	public static StyleSheet defaultStyle;
	public static void delegate() onDrawUpdate;
	/**
	 * If the current window doesn't contain a custom StyleSheet, it gets from it's parent.
	 */
	public StyleSheet getStyleSheet(){
		if(customStyle is null){
			if(parent is null){
				return defaultStyle;
			}
			return parent.getStyleSheet();
		}
		return customStyle;
	}
	/**
	 * Updates the output of the elements.
	 */
	public void drawUpdate(WindowElement sender){
		/*if(!fullUpdate){
			this.draw();
		}*/
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);
	}


	/**
	 * Standard constructor. "size" sets both the initial position and the size of the window.
	 * Extra buttons are handled from the StyleSheet, currently unimplemented.
	 */
	public this(Coordinate size, wstring title, string[] extraButtons = []){
		position = size;
		output = new BitmapDrawer(position.width(), position.height());
		this.title = title;
		//sizeX = position.width();
		//sizeY = position.height();
		//style = 0;
		//closeButton = 2;
		this.extraButtons = extraButtons;
	}
	/**
	 * Adds a new WindowElement with the given event properties.
	 */
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
		we.draw();
	}
	/**
	 * Removes the WindowElement if 'we' is found within its ranges, does nothing otherwise.
	 */
	public void removeElement(WindowElement we){
		int i;
		while(elements.length > i){
			if(elements[i] == we){
				elements = remove(elements, i);
			}else{
				i++;
			}
		}
		i = 0;
		while(mouseC.length > i){
			if(mouseC[i] == we){
				mouseC = remove(mouseC, i);
			}else{
				i++;
			}
		}
		i = 0;
		while(scrollC.length > i){
			if(scrollC[i] == we){
				scrollC = remove(scrollC, i);
			}else{
				i++;
			}
		}
		i = 0;
		while(keyboardC.length > i){
			if(keyboardC[i] == we){
				keyboardC = remove(keyboardC, i);
			}else{
				i++;
			}
		}
		draw();
	}
	/**
	 * Draws the window. Intended to be used by the WindowHandler.
	 */
	public void draw(){
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		output.drawFilledRectangle(0, position.width() - 1, getStyleSheet().getImage("closeButtonA").height, position.height() - 1, getStyleSheet().getColor("window"));
		int x1 = getStyleSheet().getImage("closeButtonA").width, y1 = getStyleSheet().getImage("closeButtonA").height, x2 = position.width;
		/*output.drawRectangle(x1, sizeX - 1, 0, y1, getStyleBrush(header));
		output.drawFilledRectangle(x1 + (x1/2), sizeX - 1 - (x1/2), y1/2, y1 - (y1/2), getStyleBrush(header).readPixel(x1/2, y1/2));*/

		//int headerLength = cast(int)(extraButtons.length == 0 ? position.width - 1 : position.width() - 1 - ((extraButtons.length>>2) * x1) );
		//drawing the header
		drawHeader();

		//drawing the border of the window
		output.drawLine(0, position.width() - 1, y1, y1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, 0, y1, position.height() - 1, getStyleSheet().getColor("windowascent"));
		output.drawLine(0, position.width() - 1, position.height() - 1, position.height() - 1,
				getStyleSheet().getColor("windowdescent"));
		output.drawLine(position.width() - 1, position.width() - 1, y1, position.height() - 1,
				getStyleSheet().getColor("windowdescent"));

		//output.drawText(x1+1, 1, title, getFontSet(0), 1);

		fullUpdate = true;
		foreach(WindowElement we; elements){
			we.draw();
			//output.insertBitmap(we.getPosition().xa,we.getPosition().ya,we.output.output);
		}
		fullUpdate = false;
		parent.drawUpdate(this);
		if(onDrawUpdate !is null){
			onDrawUpdate();
		}
	}
	/**
	 * Draws the header.
	 */
	protected void drawHeader(){
		output.drawFilledRectangle(0, position.width() - 1, 0, getStyleSheet().getImage("closeButtonA").height - 1,
				getStyleSheet().getColor("window"));
		output.insertBitmap(0,0,getStyleSheet().getImage("closeButtonA"));
		const int x1 = getStyleSheet().getImage("closeButtonA").width, y1 = getStyleSheet().getImage("closeButtonA").height;
		int x2 = position.width;
		int headerLength = cast(int)(extraButtons.length == 0 ? position.width() - 1 : position.width() - 1 -
				((extraButtons.length>>1) * x1));
		foreach(s ; extraButtons){
			x2 -= x1;
			output.insertBitmap(x2,0,getStyleSheet().getImage(s));
		}
		output.drawLine(x1, headerLength, 0, 0, getStyleSheet().getColor("windowascent"));
		output.drawLine(x1, x1, 0, y1 - 1, getStyleSheet().getColor("windowascent"));
		output.drawLine(x1, headerLength, y1 - 1, y1 - 1, getStyleSheet().getColor("windowdescent"));
		output.drawLine(headerLength, headerLength, 0, y1 - 1, getStyleSheet().getColor("windowdescent"));
		output.drawText(x1,(y1-getStyleSheet().getFontset("default").getSize())/2,title,getStyleSheet().getFontset("default"),
				1);
	}
	public void setTitle(wstring s){
		title = s;
		drawHeader;
	}
	public wstring getTitle(){
		return title;
	}
	/**
	 * Detects where the mouse is clicked, then it either passes to an element, or tests whether the close button,
	 * an extra button was clicked, also tests for the header, which creates a drag event for moving the window.
	 */
	public void passMouseEvent(int x, int y, int state, ubyte button){
		if(state == ButtonState.PRESSED){
			if(getStyleSheet.getImage("closeButtonA").width > x && getStyleSheet.getImage("closeButtonA").height > y && button == MouseButton.LEFT){
				close();
				return;
			}else if(getStyleSheet.getImage("closeButtonA").height > y){
				if(y > position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length)){
					y -= position.width - (getStyleSheet.getImage("closeButtonA").width * extraButtons.length);
					extraButtonEvent(y / getStyleSheet.getImage("closeButtonA").width, button, state);
					return;
				}
				parent.moveUpdate(this);
				return;
			}
			//x -= position.xa;
			//y -= position.ya;

			foreach(WindowElement e; mouseC){
				if(e.getPosition().left < x && e.getPosition().right > x && e.getPosition().top < y && e.getPosition().bottom > y){
					e.onClick(x - e.getPosition().left, y - e.getPosition().top, state, button);
					draggedElement = e;

					return;
				}
			}
		}else{
			if(draggedElement){
				draggedElement.onClick(x - draggedElement.getPosition().left, y - draggedElement.getPosition().top, state, button);
				draggedElement = null;
			}
		}
	}
	/**
	 * Passes a mouseDragEvent if the user clicked on an element, held down the button, and moved the mouse.
	 */
	public void passMouseDragEvent(int x, int y, int relX, int relY, ubyte button){
		if(draggedElement){
			draggedElement.onDrag(x, y, relX, relY, button);
		}
	}
	/**
	 * Passes a mouseMotionEvent if the user moved the mouse.
	 */
	public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button){

	}
	/**
	 * Closes the window by calling the WindowHandler's closeWindow function.
	 */
	public void close(){
		parent.closeWindow(this);
	}
	/**
	 * Passes the scroll event to the element where the mouse pointer currently stands.
	 */
	public void passScrollEvent(int wX, int wY, int x, int y){
		foreach(WindowElement e; scrollC){
			if(e.getPosition().left < wX && e.getPosition().right > wX && e.getPosition().top < wX && e.getPosition().bottom > wY){

				e.onScroll(x, y, wX, wY);
				return;
			}
		}
	}
	/**
	 * Called if an extra button was pressed.
	 */
	public void extraButtonEvent(int num, ubyte button, int state){

	}
	/**
	 * Passes a keyboard event.
	 */
	public void passKeyboardEvent(wchar c, int type, int x, int y){

	}
	/**
	 * Adds a WindowHandler to the window.
	 */
	public void addParent(IWindowHandler wh){
		parent = wh;
	}
	public void getFocus(){

	}
	public void dropFocus(){

	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return Coordinate(sender.position.left + position.left, sender.position.top + position.top, sender.position.right + position.right, sender.position.bottom + position.bottom);
	}
	/**
	* Moves the window to the exact location.
	*/
	public void move(int x, int y){
		parent.moveWindow(x, y, this);
		position.move(x,y);
	}
	/**
	* Moves the window by the given values.
	*/
	public void relMove(int x, int y){
		parent.relMoveWindow(x, y, this);
		position.relMove(x,y);
	}
	/**
	 * Sets the height of the window, also issues a redraw.
	 */
	public void setHeight(int y){
		position.bottom = position.top + y;
		draw();
	}
	/**
	 * Sets the width of the window, also issues a redraw.
	 */
	public void setWidth(int x){
		position.right = position.left + x;
		draw();
	}
	/**
	 * Sets the size of the window, also issues a redraw.
	 */
	public void setSize(int x, int y){
		position.right = position.left + x;
		position.bottom = position.top + y;
		draw();
	}
}

/**
 * Standard text input form for various applications.
 */
public class TextInputDialog : Window{
	//public ActionListener[] al;
	private TextBox textInput;
	private string source;
	public void function(wstring text) textOutput;
	/**
	 * Creates a TextInputDialog. Auto-sizing version is not implemented yet.
	 */
	public this(Coordinate size, string source, wstring title, wstring message, wstring text = ""){
		super(size, title);
		Label msg = new Label(message, "null", Coordinate(8, 20, size.width()-8, 39));
		addElement(msg, EventProperties.MOUSE);

		textInput = new TextBox(text, "textInput", Coordinate(8, 40, size.width()-8, 59));
		addElement(textInput, EventProperties.MOUSE);

		Button ok = new Button("Ok","ok", Coordinate(size.width()-48,65,size.width()-8,84));
		ok.onMouseLClickRel = &button_onClick;
		addElement(ok,EventProperties.MOUSE);
		this.source = source;
	}

	public void button_onClick(Event ev){
		if(textOutput !is null){
			textOutput(textInput.getText);
		}

		close();

	}
}
/**
 * Default dialog for simple messageboxes.
 */
public class DefaultDialog : Window{
	private string source;
	public void delegate(Event ev) output;

	public this(Coordinate size, string source, wstring title, wstring[] message, wstring[] options = ["Ok"], string[] values = ["close"]){
		this(size, title);
		//generate text
		this.source = source;
		int x1, x2, y1 = 20, y2 = getStyleSheet.drawParameters["TextSpacingTop"] + getStyleSheet.drawParameters["TextSpacingBottom"]
								+ getStyleSheet.getFontset(getStyleSheet.fontTypes["Label"]).letters[' '].height;
		//Label msg = new Label(message[0], "null", Coordinate(5, 20, size.width()-5, 40));
		//addElement(msg, EventProperties.MOUSE);

		//generate buttons

		x1 = size.width() - 10;
		Button[] buttons;
		int button1 = size.height - getStyleSheet.drawParameters["WindowBottomPadding"];
		int button2 = button1 - getStyleSheet.drawParameters["ComponentHeight"];
		for(int i; i < options.length; i++){
			x2 = x1 - ((getStyleSheet().getFontset("default").getTextLength(options[i]) + 16));
			buttons ~= new Button(options[i], values[i], Coordinate(x2, button2, x1, button1));
			buttons[i].onMouseLClickRel = &actionEvent;
			addElement(buttons[i], EventProperties.MOUSE);
			x1 = x2;
		}
		//add labels
		for(int i; i < message.length; i++){
			Label msg = new Label(message[i], "null", Coordinate(getStyleSheet.drawParameters["WindowLeftPadding"],
								y1, size.width()-getStyleSheet.drawParameters["WindowRightPadding"], y1 + y2));
			addElement(msg, EventProperties.MOUSE);
			y1 += y2;
		}
	}

	/*public this(string source, wstring title, wstring[] message, wstring[] options = ["Ok"], string[] values = ["ok"]){
		this(size, title);
	}*/

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(Event ev){
		if(ev.source == "close"){
			close();
		}else{
			if(output !is null){
				ev.subsource = source;
				output(ev);
			}
		}
	}
}
/**
 * File dialog window for opening files.
 * TODO: rewrite for new event handling system.
 */
public class FileDialog : Window{
	/**
	 * Defines file association descriptions
	 */
	public struct FileAssociationDescriptor{
		public wstring description;		/// Describes the file type. Eg. "PPE map files"
		public string[] types;			/// The extensions associated with a given file format. Eg. ["*.htm","*.html"]. First is preferred one at saving.
		/**
		 * Creates a single FileAssociationDescriptor
		 */
		public this(wstring description, string[] types){
			this.description = description;
			this.types = types;
		}
		/**
		 * Returns the types as a single string.
		 */
		public wstring getTypesForSelector(){
			wstring result;
			foreach(string s ; types){
				result ~= to!wstring(s);
				result ~= ";";
			}
			result.length--;
			return result;
		}
	}

	//private ActionListener al;
	private string source;
	private string[] pathList, driveList;
	private string directory, filename;
	private ListBox lb;
	private TextBox tb;

	private bool save;
	private FileAssociationDescriptor[] filetypes;
	public static const string subsourceID = "filedialog";
	private int selectedType;
	public void delegate(Event ev) onFileselect;

	/**
	 * Creates a file dialog with the given parameters.
	 * File types are given in the format '*.format', later implementations will enable file type descriptions.
	 */
	public this(wstring title, string source, void delegate(Event ev) onFileselect, FileAssociationDescriptor[] filetypes, string startDir, bool save = false, string filename = ""){
		this(Coordinate(20,20,240,198), title);
		this.source = source;
		this.filetypes = filetypes;
		this.save = save;
		//al = a;
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
		buttons ~= new Button("Type","type",Coordinate(166, 130, 216, 150));
		for(int i; i < buttons.length; i++){
			buttons[i].onMouseLClickRel = &actionEvent;
			addElement(buttons[i], EventProperties.MOUSE);
		}
		//generate textbox
		tb = new TextBox(to!wstring(filename), "filename", Coordinate(4, 130, 162, 150));
		//tb.addTextInputHandler(tih);
		tb.onTextInput = &actionEvent;
		addElement(tb, EventProperties.MOUSE);
		//generate listbox

		//test parameters

		//Date format: yyyy-mm-dd hh:mm:ss
		lb = new ListBox("lb", Coordinate(4, 20, 216, 126),null, new ListBoxHeader(["Name", "Type", "Date"], [160, 40, 176]) ,15);

		addElement(lb, EventProperties.MOUSE | EventProperties.SCROLL);
		spanDir();
		//scrollC ~= lb;
		lb.onItemSelect = &actionEvent;
		detectDrive();
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	/**
	 * Iterates throught a directory for listing.
	 */
	private void spanDir(){
		pathList.length = 0;
		ListBoxItem[] items;
		foreach(DirEntry de; dirEntries(directory, SpanMode.shallow)){
			if(de.isDir){
				pathList ~= de.name;
				/*columns[0].elements ~= to!wstring(getFilenameFromPath(de.name));
				columns[1].elements ~= "<DIR>";
				columns[2].elements ~= formatDate(de.timeLastModified);*/
				items ~= new ListBoxItem([to!wstring(getFilenameFromPath(de.name)),"<DIR>",formatDate(de.timeLastModified)]);
			}
		}
		//foreach(f; filetypes){
		foreach(ft; filetypes[selectedType].types){
			foreach(DirEntry de; dirEntries(directory, ft, SpanMode.shallow)){
				if(de.isFile){
					pathList ~= de.name;
					/*columns[0].elements ~= to!wstring(getFilenameFromPath(de.name, true));
					columns[1].elements ~= to!wstring(ft);
					columns[2].elements ~= formatDate(de.timeLastModified);*/
					items ~= new ListBoxItem([to!wstring(getFilenameFromPath(de.name)),to!wstring(ft),formatDate(de.timeLastModified)]);
				}
			}
		}
		lb.updateColumns(items);
		lb.draw();

	}
	/**
	 * Standard date formatting tool.
	 */
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
		return s;
	}
	/**
	 * Detects the available drives, currently only used under windows.
	 */
	private void detectDrive(){
		version(Windows){
			driveList.length = 0;
			for(char c = 'A'; c <='Z'; c++){
				string s;
				s ~= c;
				s ~= ":\x5c";
				if(exists(s)){
					driveList ~= (s);
				}
			}
		}
		else{

		}
	}
	/**
	 * Returns the filename from the path.
	 */
	private string getFilenameFromPath(string p, bool b = false){
		size_t n, m = p.length;
		string s;
		for(size_t i ; i < p.length ; i++){
			if(std.path.isDirSeparator(p[i])){
				n = i;
			}
		}
		//n++;
		if(b){
			for(size_t i ; i < p.length ; i++){
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
	/**
	 * Called when the up button is pressed. Goes up in the folder hiearchy.
	 */
	private void up(){
		int n;
		for(int i ; i < directory.length ; i++){
			if(std.path.isDirSeparator(directory[i])){
				n = i;
			}
		}
		string newdir;
		for(int i ; i < n ; i++){
			newdir ~= directory[i];
		}
		directory = newdir;
		spanDir();

	}
	/**
	 * Displays the drives. Under Linux, it goes into the /dev/ folder.
	 */
	private void changeDrive(){
		version(Windows){
			pathList.length = 0;
			ListBoxItem[] items;
			foreach(string drive; driveList){
				pathList ~= drive;
				items ~= new ListBoxItem([to!wstring(drive),"<DIR>","N/A"]);
			}
			lb.updateColumns(items);
			lb.draw();
		}else version(Posix){
			directory = "/dev/";
			spanDir();
		}
	}
	/**
	 * Creates an action event, then closes the window.
	 */
	private void fileEvent(){
		//wstring s = to!wstring(directory);
		filename = to!string(tb.getText);
		//al.actionEvent("file", EventType.FILEDIALOGEVENT, 0, s);
		if(onFileselect !is null)
			onFileselect(new Event(source, "filedialog", directory, filename, null, 0, EventType.FILEDIALOGEVENT));
		parent.closeWindow(this);
	}

	public void actionEvent(Event event){

		if(event.subsource == "fileSelector"){
			selectedType = event.value;
			spanDir();
		}
		switch(event.source){
			case "lb":
				try{
					if(pathList.length == 0) return;
					if(isDir(pathList[event.value])){
						directory = pathList[event.value];
						spanDir();


					}else{
						filename = getFilenameFromPath(pathList[event.value]);
						tb.setText(to!wstring(filename));
					}
				}catch(Exception e){
					DefaultDialog d = new DefaultDialog(Coordinate(10,10,256,80),"null",to!wstring("Error!"), PixelPerfectEngine.system.etc.stringArrayConv([e.msg]));
					parent.addWindow(d);
				}
				break;
			case "up": up(); break;
			case "drv": changeDrive(); break;
			case "ok": fileEvent(); break;
			case "close": parent.closeWindow(this); break;
			case "type":
				PopUpMenuElement[] e;
				for(int i ; i < filetypes.length ; i++){
					e ~= new PopUpMenuElement(to!string(i),filetypes[i].description, filetypes[i].getTypesForSelector());
				}
				PopUpMenu p = new PopUpMenu(e,"fileSelector");
				p.onMouseClick = &actionEvent;
				parent.addPopUpElement(p);
				break;
			default: break;
		}
	}
}
/**
 * Handles windows as well as PopUpElements.
 */
public class WindowHandler : InputListener, MouseListener, IWindowHandler{
	private Window[] windows;
	private PopUpElement[] popUpElements;
	private int numOfPopUpElements;
	private int[] priorities;
	public int screenX, screenY, rasterX, rasterY, moveX, moveY, mouseX, mouseY;
	//public Bitmap16Bit[wchar] basicFont, altFont, alarmFont;
	public StyleSheet defaultStyle;
	//public Bitmap16Bit[int] styleBrush;
	private ABitmap background;
	private ISpriteLayer spriteLayer;
	private bool moveState, dragEventState;
	private Window windowToMove, dragEventDest;
	private PopUpElement dragEventDestPopUp;
	private ubyte lastMouseButton;

	public this(int sx, int sy, int rx, int ry,ISpriteLayer sl){
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

	/**
	 * Adds a DefaultDialog as a message box
	 */
	public void messageWindow(wstring title, wstring message, int width = 256){
		StyleSheet ss = getDefaultStyleSheet();
		wstring[] formattedMessage = ss.getFontset(ss.fontTypes["Label"]).breakTextIntoMultipleLines(message, width -
				ss.drawParameters["WindowLeftPadding"] - ss.drawParameters["WindowRightPadding"]);
		int height = cast(int)(formattedMessage.length * (ss.getFontset(ss.fontTypes["Label"]).getSize() +
				ss.drawParameters["TextSpacingTop"] + ss.drawParameters["TextSpacingBottom"]));
		height += ss.drawParameters["WindowTopPadding"] + ss.drawParameters["WindowBottomPadding"] +
				ss.drawParameters["ComponentHeight"];
		Coordinate c = Coordinate(mouseX - width / 2, mouseY - height / 2, mouseX + width / 2, mouseY + height / 2);
		addWindow(new DefaultDialog(c, null, title, formattedMessage));
	}
	public void addBackground(ABitmap b){
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
		//writeln(sender);
		dragEventState = false;
		dragEventDest = null;
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
	}
	public void keyPressed(string ID, uint timestamp, uint devicenumber, uint devicetype){

	}
	public void keyReleased(string ID, uint timestamp, uint devicenumber, uint devicetype){

	}
	public void mouseButtonEvent(uint which, uint timestamp, uint windowID, ubyte button, ubyte state, ubyte clicks, int x, int y){

		//converting the dimensions
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);
		mouseX = x;
		mouseY = y;
		//if(button == MouseButton.LEFT){
		if(state == ButtonState.PRESSED){
			if(numOfPopUpElements < 0){
				foreach(p ; popUpElements){
				if(y >= p.coordinates.top && y <= p.coordinates.bottom && x >= p.coordinates.left && x <= p.coordinates.right){
					p.onClick(x - p.coordinates.left, y - p.coordinates.top);
					return;
				}
			}
			//removeAllPopUps();
			removeTopPopUp();
			}else{
				moveX = x;
				moveY = y;
				for(int i ; i < windows.length ; i++){
					if(x >= windows[i].position.left && x <= windows[i].position.right && y >= windows[i].position.top && y <= windows[i].position.bottom){
						//if(i == 0){
						dragEventState = true;
						windows[i].passMouseEvent(x - windows[i].position.left, y - windows[i].position.top, state, button);
						if(dragEventState)
							dragEventDest = windows[i];
					/*if(windows.length !=0){
						dragEventState = true;
						dragEventDest = windows[0];
					}*/
				//return;
					//}else{
						if(i != 0){
							setWindowToTop(windows[i]);

						}
						lastMouseButton = button;
						return;
					}
				}
				passMouseEvent(x,y,state,button);

			}
		}else{
			if(moveState){
				moveState = false;
			}else if(dragEventDest){
				dragEventDest.passMouseEvent(x - dragEventDest.position.left, y - dragEventDest.position.top, state, button);
				dragEventDest = null;
			}else{
				passMouseEvent(x,y,state,button);
			}
		}
	}
	public void passMouseEvent(int x, int y, int state, ubyte button){

	}
	public void passMouseDragEvent(int x, int y, int relX, int relY, ubyte button){
	}
	public void passMouseMotionEvent(int x, int y, int relX, int relY, ubyte button){
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
		//coordinate conversion
		double xR = to!double(rasterX) / to!double(screenX) , yR = to!double(rasterY) / to!double(screenY);
		x = to!int(x * xR);
		y = to!int(y * yR);
		relX = to!int(relX * xR);
		relY = to!int(relY * yR);
		//passing mouseMovementEvent onto PopUps
		if(numOfPopUpElements < 0){
			PopUpElement p = popUpElements[popUpElements.length - 1];
			if(p.coordinates.top < y && p.coordinates.bottom > y && p.coordinates.left < x && p.coordinates.right > x){
				p.onMouseMovement(x - p.coordinates.left, y - p.coordinates.top);
				return;
			}else{
				p.onMouseMovement(-1,-1);
			}

		}
		if(state == ButtonState.PRESSED && moveState){
			windowToMove.relMove(relX, relY);
		}else if(state == ButtonState.PRESSED && dragEventDest){
			dragEventDest.passMouseDragEvent(x, y, relX, relY, lastMouseButton);
		}else{
			if(windows.length){
				windows[0].passMouseMotionEvent(x, y, relX, relY, lastMouseButton);
			}
		}
	}
	public void moveWindow(int x, int y, Window w){
		spriteLayer.relMoveSprite(whichWindow(w), x, y);

	}
	public void relMoveWindow(int x, int y, Window w){
		spriteLayer.relMoveSprite(whichWindow(w), x, y);
	}
	public void addPopUpElement(PopUpElement p){
		popUpElements ~= p;
		p.addParent(this);
		p.draw;
		p.coordinates.move(mouseX, mouseY);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.output.output,numOfPopUpElements,mouseX,mouseY);

	}
	public void addPopUpElement(PopUpElement p, int x, int y){
		popUpElements ~= p;
		p.addParent(this);
		p.draw;
		p.coordinates.move(x, y);
		numOfPopUpElements--;
		spriteLayer.addSprite(p.output.output,numOfPopUpElements, x, y);
	}
	private void removeAllPopUps(){
		for( ; numOfPopUpElements < 0 ; numOfPopUpElements++){
			spriteLayer.removeSprite(numOfPopUpElements);
		}
		popUpElements.length = 0;
	}
	private void removeTopPopUp(){

		spriteLayer.removeSprite(numOfPopUpElements++);

		popUpElements.length--;
	}
	public StyleSheet getDefaultStyleSheet(){
		return defaultStyle;
	}
	public void endPopUpSession(){
		removeAllPopUps();
	}
	public void closePopUp(PopUpElement p){

	}
	public void drawUpdate(WindowElement sender){}
	public void getFocus(WindowElement sender){}
	public void dropFocus(WindowElement sender){}
	public void drawUpdate(Window sender){
		/*int p = whichWindow(sender);
		spriteLayer.removeSprite(p);
		spriteLayer.addSprite(sender.output.output,p,sender.position);*/
	}
	/*public Coordinate getAbsolutePosition(PopUpElement sender){
		for(int i ; i < popUpElements.length ; i++){
			if(popUpElements[i] = sender){

			}
		}
		return Coordinate();
	}*/
}

public interface IWindowHandler : PopUpHandler{
	//public Bitmap16Bit[wchar] getFontSet(int style);
	public StyleSheet getStyleSheet();
	public void closeWindow(Window sender);
	public void moveUpdate(Window sender);
	public void setWindowToTop(Window sender);
	public void addWindow(Window w);
	public void moveWindow(int x, int y, Window w);
	public void relMoveWindow(int x, int y, Window w);
	public void drawUpdate(Window sender);
	public void messageWindow(wstring title, wstring message, int width = 256);
}

public enum EventProperties : uint{
	KEYBOARD		=	1,
	MOUSE			=	2,
	SCROLL			=	4
}
