/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.elements module
 */

module PixelPerfectEngine.concrete.elements;

import PixelPerfectEngine.graphics.bitmap;
public import PixelPerfectEngine.graphics.draw;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.inputHandler;
import std.algorithm;
import std.stdio;
import std.conv;
import PixelPerfectEngine.concrete.stylesheet;

/**
 * All Window elements inherit from this class. Provides basic interfacing with containers.
 */
abstract class WindowElement{
	//public ActionListener[] al;
	protected dstring text;
	protected string source;
	///DO NOT MODIFY IT EXTERNALLY! Contains the position of the element.
	public Coordinate position;
	///Contains the output of the drawing functions
	public BitmapDrawer output;
	///Points to the container for two-way communication
	public ElementContainer elementContainer;
	public StyleSheet customStyle;
	protected bool state;

	public static InputHandler inputHandler;	///Common input handler, must be set upon program initialization
	public static PopUpHandler popUpHandler;	///Common pop-up handler
	public static StyleSheet styleSheet;		///Basic stylesheet, all elements default to this if no alternative found

	public static void delegate() onDraw;		///Called when drawing is finished

	public void delegate(Event ev) onMouseLClickRel;	///Called on left mouseclick released
	public void delegate(Event ev) onMouseRClickRel;	///Called on right mouseclick released
	public void delegate(Event ev) onMouseMClickRel;	///Called on middle mouseclick released
	public void delegate(Event ev) onMouseHover;		///Called if mouse is on object
	public void delegate(Event ev) onMouseMove;			///Called if mouse is moved on object
	public void delegate(Event ev) onMouseLClickPre;	///Called on left mouseclick pressed
	public void delegate(Event ev) onMouseRClickPre;	///Called on right mouseclick pressed
	public void delegate(Event ev) onMouseMClickPre;	///Called on middle mouseclick pressed

	public void onClick(int offsetX, int offsetY, int state, ubyte button){

	}
	public void onDrag(int x, int y, int relX, int relY, ubyte button){

	}

	public void onScroll(int x, int y, int wX, int wY){

	}

	@property @nogc @safe nothrow public int getX(){
		return position.width;
	}
	@property @nogc @safe nothrow public int getY(){
		return position.height;
	}
	@property @nogc @safe nothrow public Coordinate getPosition(){
		return position;
	}
	/**
	 * Updates the output. Every subclass must override it.
	 */
	public abstract void draw();

	/+protected void invokeActionEvent(int type, int value, wstring message = ""){
		foreach(ActionListener a; al){
			if(a)
				a.actionEvent(new Event(source, null, null, null, text, value, type));
		}
	}

	protected void invokeActionEvent(Event e) {
		foreach(ActionListener a; al){
			if(a)
				a.actionEvent(e);
		}
	}+/
	/*private Bitmap16Bit getBrush(int style){
		return altStyleBrush.get(style, elementContainer.getStyleBrush(style));
	}*/
	public @nogc dstring getText(){
		return text;
	}
	public void setText(dstring s){
		text = s;
		elementContainer.clearArea(this);
		draw();

	}

	public StyleSheet getAvailableStyleSheet(){
		if(customStyle !is null){
			return customStyle;
		}
		return styleSheet;
	}

	public void setCustomStyle(StyleSheet s){
		customStyle = s;
	}
	/**
	 * Enables (b = true) or disables (b = false) the element. All element is enabled by default.
	 */
	@nogc public void setState(bool b){
		state = !b;
	}
	/**
	 * Gets the state of the element.
	 */
	@nogc public bool getState(){
		return !state;
	}
	/**
	 * Returns the source string.
	 */
	@property public string getSource(){
		return source;
	}
}

public class Button : WindowElement{
	private bool isPressed;
	public bool enableRightButtonClick;
	public bool enableMiddleButtonClick;
	public this(dstring text, string source, Coordinate coordinates){
		position = coordinates;
		//sizeX = coordinates.width();
		//sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//brushPressed = 1;
		//draw();
	}
	public override void draw(){
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width(), position.height());
		if(isPressed){
			output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("windowinactive"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
		}else{
			output.drawFilledRectangle(1, position.width()-1, 1,position.height()-1, getAvailableStyleSheet().getColor("window"));
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
		}

		output.drawColorText(position.width/2, position.height/2, text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"), FontFormat.HorizCentered | FontFormat.VertCentered);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT && enableRightButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID && enableMiddleButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}

	}
}

public class SmallButton : WindowElement{
	private string iconPressed, iconUnpressed;
	private bool isPressed;
	public bool enableRightButtonClick;
	public bool enableMiddleButtonClick;
	public int brushPressed, brushNormal;

	public this(string iconPressed, string iconUnpressed, string source, Coordinate coordinates){
		position = coordinates;

		//this.text = text;
		this.source = source;
		this.iconPressed = iconPressed;
		this.iconUnpressed = iconUnpressed;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		brushPressed = 1;
		//draw();
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.width()-1, 0,position.height()-1, 0);
		if(isPressed){
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage(iconPressed));
		}else{
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage(iconUnpressed));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT && enableRightButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID && enableMiddleButtonClick){
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				isPressed = true;
				draw();
				//invokeActionEvent(EventType.CLICK, -1);
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				isPressed = false;
				draw();
				//invokeActionEvent(EventType.CLICK, 0);
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}

	}
}

public class Label : WindowElement{
	public this(dstring text, string source, Coordinate coordinates){
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//draw();
	}
	public override void draw(){
		//writeln(elementContainer);
		output = new BitmapDrawer(position.width, position.height);
		output.drawColorText(0, 0, text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"), 0);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	/*public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(state == ButtonState.PRESSED)
			invokeActionEvent(EventType.CLICK, 0);
	}*/
	public override void setText(dstring s) {
		output.destroy();
		output = new BitmapDrawer(position.width, position.height);
		super.setText(s);
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}

	}
}

public class TextBox : WindowElement, TextInputListener{
	private bool enableEdit, insert;
	private uint pos;
	//public int brush, textpos;
	//public TextInputHandler tih;
	public void delegate(Event ev) onTextInput;

	public this(dstring text, string source, Coordinate coordinates){
		position = coordinates;
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		//inputHandler.addTextInputListener(source, this);
		//insert = true;
		//draw();
	}

	~this(){
		//inputHandler.removeTextInputListener(source);
	}
	public deprecated void addTextInputHandler(TextInputHandler t){	/** DEPRECATED. Will be removed soon in favor of static input handlers. */
		/*tih = t;*/
		//inputHandler.addTextInputListener(source, this);
	}

	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
		if(!enableEdit && state == ButtonState.PRESSED && button == MouseButton.LEFT){
			//invokeActionEvent(EventType.READYFORTEXTINPUT, 0);
			enableEdit = true;
			inputHandler.startTextInput(this);
			draw();
		}
	}
	public override void draw(){
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width - 1, 0, position.height - 1, getAvailableStyleSheet().getColor("window"));
		output.drawRectangle(0, position.width - 1, 0, position.height - 1, getAvailableStyleSheet().getColor("windowascent"));

		//draw cursor
		if(enableEdit){
			const int x = getAvailableStyleSheet().getFontset("default").getTextLength(text[0..pos]) ,
					y = getAvailableStyleSheet().getFontset("default").getSize;
			if(!insert){
				output.drawLine(x + 2, x + 2, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
			}else{
				const int x0 = pos == text.length ? x + getAvailableStyleSheet().getFontset("default").chars[' '].xadvance :
						getAvailableStyleSheet().getFontset("default").getTextLength(text[0..pos + 1]);
				output.drawFilledRectangle(x + 2, x0 + 2, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
			}
		}

		output.drawColorText(2, 2, text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"), 0);
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}

	private void deleteCharacter(int n){
		//text = remove(text, i);
		dstring newtext;
		for(int i; i < text.length; i++){
			if(i != n - 1){
				newtext ~= text[i];
			}
		}
		text = newtext;
	}
	public void textInputEvent(uint timestamp, uint windowID, dstring text){
		//writeln(0);
		int j = pos;
		dstring newtext;
		for(int i ; i < pos ; i++){
			newtext ~= this.text[i];
		}
		for(int i ; i < 32 ; i++){
			if(text[i] == 0){
				break;
			}
			else{
				newtext ~= text[i];
				pos++;
				if(insert){
					j++;
				}
			}
		}
		for( ; j < this.text.length ; j++){
			newtext ~= this.text[j];
		}
		this.text = newtext;
		draw();
	}

	public void dropTextInput(){
		enableEdit = false;
		//inputHandler.stopTextInput(source);
		draw();
		//invokeActionEvent(EventType.TEXTINPUT, 0, text);
		if(onTextInput !is null)
			onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT));
	}


	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		if(key == TextInputKey.ESCAPE || key == TextInputKey.ENTER){
			enableEdit = false;
			inputHandler.stopTextInput(this);
			draw();
			//invokeActionEvent(EventType.TEXTINPUT, 0, text);
			if(onTextInput !is null){
				onTextInput(new Event(source, null, null, null, text, 0, EventType.TEXTINPUT));
			}
		}else if(key == TextInputKey.BACKSPACE){
			if(pos > 0){
				deleteCharacter(pos);
				pos--;
				draw();
			}
			/*if(pos > 0){
			 if(pos == text.length){
			 text.length--;
			 pos--;

			 }
			 }*/
		}else if(key == TextInputKey.DELETE){
			deleteCharacter(pos + 1);
			draw();
		}else if(key == TextInputKey.CURSORLEFT){
			if(pos > 0){
				--pos;
				draw();
			}
		}else if(key == TextInputKey.CURSORRIGHT){
			if(pos < text.length){
				++pos;
				draw();
			}
		}else if(key == TextInputKey.INSERT){
			insert = !insert;
			draw();
		}else if(key == TextInputKey.HOME){
			pos = 0;
			draw();
		}else if(key == TextInputKey.END){
			pos = cast(uint)text.length;
			draw();
		}
	}
}

/**
 * Displays multiple columns of data, also provides general text input.
 */
public class ListBox : WindowElement, ElementContainer{
	//public ListBoxColumn[] columns;
	public ListBoxHeader header;
	public ListBoxItem[] items;
	public int[] columnWidth;
	public int selection, brushHeader, brush, fontHeader;
	public ushort selectionColor;
	private bool fullRedraw, bodyDrawn, enableTextInput, textInputMode, insert, dragMid;
	private VSlider vSlider;
	private HSlider hSlider;
	private Slider dragSld;
	private int fullX, hposition, vposition, sliderX, sliderY, startY, endY, selectedColumn, textPos, previousEvent;
	private BitmapDrawer textArea, headerArea;
	private Coordinate textInputArea;
	public void delegate(Event ev) onTextInput;
	public void delegate(Event ev) onItemSelect;
	public void delegate(Event ev) onScrolling;

	public this(string source, Coordinate coordinates, ListBoxItem[] items, ListBoxHeader header, int rowHeight,
			bool enableTextInput = false){
		this(source, coordinates, items, header, enableTextInput);
	}

	public this(string source,Coordinate coordinates,ListBoxItem[] items,ListBoxHeader header,bool enableTextInput=false){
		position = coordinates;
		this.source = source;
		//this.rowHeight = rowHeight;
		this.items = items;
		this.header = header;
		updateColumns();

		foreach(int i; columnWidth){
			fullX += i;
		}
		if(fullX < position.width()){
			fullX = position.width();
		}

		output = new BitmapDrawer(position.width, position.height);


		this.enableTextInput = enableTextInput;
		//inputHandler.addTextInputListener(source, this);

	}

	private void textInput(Event ev){
		items[selection].setText(selectedColumn, ev.text);
		//invokeActionEvent(new Event(source, null, null, null, event.text, selection,EventType.TEXTINPUT, items[selection]));
		if(onTextInput !is null){
			onTextInput(new Event(source, null, null, null, ev.text, selection,EventType.TEXTINPUT, items[selection]));
		}
		updateColumns();
		draw();
	}
	private void scrollHoriz(Event ev){
		draw();
		if(onScrolling !is null){
			onScrolling(ev);
		}
	}
	private void scrollVert(Event ev){
		draw();
		if(onScrolling !is null){
			onScrolling(ev);
		}
	}
	public void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().left,sender.getPosition().top,sender.output.output);

		if(!fullRedraw){
			/*output.insertBitmapSlice(0,0,headerArea.output,Coordinate(vposition,0,vposition + fullX - 1, rowHeight - 1));
			output.insertBitmapSlice(0, rowHeight, textArea.output, Coordinate(vposition,hposition * rowHeight,vposition + fullX - 1 , hposition * rowHeight + (sizeY - hSlider.getPosition().getYSize) - rowHeight));*/
			elementContainer.drawUpdate(this);
		}
	}
	public Coordinate getAbsolutePosition(WindowElement sender){
		return sender.position;
	}
	/**
	 * Updates the columns with the given data.
	 */
	public void updateColumns(ListBoxItem[] items){
		this.items = items;
		updateColumns();
		draw();
	}
	/**
	 * Updates the columns with the given data and header.
	 */
	public void updateColumns(ListBoxItem[] items, ListBoxHeader header){
		this.items = items;
		this.header = header;
		updateColumns();
		draw();
	}
	/**
	 * Clears the content of the ListBox.
	 */
	public void clearData(){
		items.length = 0;
		updateColumns();
		draw();
	}
	public void updateColumns(){
		const int rowHeight = getStyleSheet().drawParameters["ListBoxRowHeight"];
		fullX = header.getFullWidth();
		selection = 0;

		if(fullX < position.width()){
			fullX = cast(int)position.width();
		}
		int foo2 = cast(int)(rowHeight * this.items.length);
		if(foo2 < position.height())
			foo2 = position.height();

		textArea = new BitmapDrawer(fullX, foo2);
		headerArea = new BitmapDrawer(fullX, rowHeight);

		this.vSlider = new VSlider(cast(uint)items.length - 1, ((position.height()-17-rowHeight) / rowHeight), "vslider",
				Coordinate(position.width() - 16, 0, position.width(), position.height() - 16));
		this.hSlider = new HSlider(fullX - 16, position.width() - 16, "hslider", Coordinate(0, position.height() - 16,
				position.width() - 16, position.height()));
		this.vSlider.onScrolling = &scrollVert;
		this.vSlider.elementContainer = this;
		sliderX = vSlider.getX();


		this.hSlider.onScrolling = &scrollHoriz;
		this.hSlider.elementContainer = this;
		sliderY = hSlider.getY();
		bodyDrawn = false;
	}

	public StyleSheet getStyleSheet(){
		return getAvailableStyleSheet;
	}

	private void drawBody(){
		const int rowHeight = getStyleSheet().drawParameters["ListBoxRowHeight"];
		int foo;
		for(int i; i < header.getNumberOfColumns(); i++){
			int bar;
			for(int j; j < items.length; j++){
				//writeln(foo + 1, bar);
				textArea.drawColorText(foo + 1, bar, items[j].getText(i), getStyleSheet().getFontset("default"),
						getAvailableStyleSheet().getColor("normaltext"), 0);

				bar += rowHeight;
			}
			foo += header.getColumnWidth(i);

			textArea.drawLine(foo, foo, 0, textArea.output.height-2, getStyleSheet().getColor("windowascent"));
		}
	}

	public override void draw(){
		const int rowHeight = getStyleSheet().drawParameters["ListBoxRowHeight"];
		if(output.output.width != position.width || output.output.height != position.height){
			output = new BitmapDrawer(position.width(), position.height());
			bodyDrawn = false;
			updateColumns();
		}
		fullRedraw = true;
		int areaX, areaY;

		vposition = vSlider.value;
		areaX = position.width - vSlider.getPosition().width();


		hposition = hSlider.value;
		areaY = position.height - hSlider.getPosition().height();

		output.drawFilledRectangle(0, position.width(), 0, position.height(),getStyleSheet().getColor("window"));
		output.drawRectangle(0, position.width() - 1, 0, position.height() - 1,getStyleSheet().getColor("windowascent"));


		// draw the header
		// TODO: Draw the header only once!!!
		output.drawLine(0, position.width() - 1, rowHeight, rowHeight, getStyleSheet().getColor("windowascent"));
		int foo;
		for(int i; i < header.getNumberOfColumns(); i++){
			headerArea.drawColorText(foo + 1, 0, header.getText(i), getStyleSheet().getFontset("default"),
					getAvailableStyleSheet().getColor("normaltext"), 0);
			foo += header.getColumnWidth(i);
			headerArea.drawLine(foo, foo, 0, rowHeight, getStyleSheet().getColor("windowascent"));
		}

		output.insertBitmapSlice(0,0,headerArea.output,Coordinate(hposition,0,hposition + position.width() - 17,
				rowHeight - 1));

		//draw the selector
		if(selection - vposition >= 0 && vposition + ((position.height()-17-rowHeight) / rowHeight) >= selection &&
				items.length != 0)
			output.drawFilledRectangle(1, position.width() - 2, 1 + rowHeight + (rowHeight * (selection - vposition)),
					(rowHeight * 2) + (rowHeight * (selection - vposition)), getStyleSheet().getColor("selection"));

		// draw the body
		if(!bodyDrawn){
			bodyDrawn = true;
			drawBody();
		}
		//writeln(textArea.output.getX(),textArea.output.getY());
		output.insertBitmapSlice(0, rowHeight, textArea.output, Coordinate(hposition,vposition * rowHeight,hposition +
				position.width() - 17 , vposition * rowHeight + areaY - rowHeight));

		vSlider.draw();
		hSlider.draw();
		elementContainer.drawUpdate(this);

		fullRedraw = false;
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		const int rowHeight = getStyleSheet().drawParameters["ListBoxRowHeight"];
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
		if(state == ButtonState.PRESSED){
			if(button == MouseButton.LEFT){
				if(offsetX > (vSlider.getPosition().left) && offsetY > (vSlider.getPosition().top)){
					vSlider.onClick(offsetX - vSlider.getPosition().left, offsetY - vSlider.getPosition().top, state, button);
					dragSld = vSlider;
					return;

				}else if(offsetX > (hSlider.getPosition().left) && offsetY > (hSlider.getPosition().top)){
					hSlider.onClick(offsetX - hSlider.getPosition().left, offsetY - hSlider.getPosition().top, state, button);
					dragSld = hSlider;
					return;

				}else if(offsetY > rowHeight && button == MouseButton.LEFT){
					offsetY -= rowHeight;
					//writeln(selection);
					if(selection == (offsetY / rowHeight) + vposition){
						//invokeActionEvent(EventType.TEXTBOXSELECT, (offsetY / rowHeight) + vposition);
						if(!enableTextInput){
							//invokeActionEvent(new Event(source, null, null, null, null, (offsetY / rowHeight) + vposition,EventType.TEXTBOXSELECT, items[selection]));
							if(onItemSelect !is null){
								onItemSelect(new Event(source, null, null, null, null, (offsetY / rowHeight) + vposition,
										EventType.TEXTBOXSELECT, items[selection]));
							}
						}else{
							offsetX += hposition;
							selectedColumn = header.getColumnNumFromX(offsetX);
							//writeln(offsetX);
							if(selectedColumn != -1){
								if(items[selection].getTextInputType(selectedColumn) != TextInputType.DISABLE){
									text = items[selection].getText(selectedColumn);
									//invokeActionEvent(EventType.READYFORTEXTINPUT,selectedColumn);
									PopUpTextInput p = new PopUpTextInput("textInput",text,Coordinate(0,0,header.getColumnWidth(selectedColumn),20));
									p.onTextInput = &textInput;
									popUpHandler.addPopUpElement(p);
									/+textInputArea = Coordinate(header.getRangeWidth(0, selectedColumn), (selection + 1) * rowHeight /*- hposition*/,
													header.getRangeWidth(0, selectedColumn + 1), (selection + 2) * rowHeight /*- hposition*/);
									writeln(textInputArea);+/

								}/*else{*/
								if(onItemSelect !is null){
									onItemSelect(new Event(source, null, null, null, null, (offsetY / rowHeight) + vposition,
											EventType.TEXTBOXSELECT, items[selection]));
									/*}*/
								}
							}
						}
					}else{
						if((offsetY / rowHeight) + vposition < items.length){
							selection = (offsetY / rowHeight) + vposition;
							draw();
						}
					}
				}
			}else if(button == MouseButton.MID){
				dragMid = true;
			}
		}else{
			dragMid = false;
			dragSld = null;
		}
	}
	public override void onDrag(int x, int y, int relX, int relY, ubyte button){
		if(dragMid){
			hSlider.value += x;
			vSlider.value += y;
		}else if(dragSld){
			dragSld.onDrag(x,y,relX,relY,button);
		}
	}
	public override void onScroll(int x, int y, int wX, int wY){
		if(textInputMode) return;
		vSlider.onScroll(x,y,0,0);
		hSlider.onScroll(x,y,0,0);
	}
	/**
	 * Returns a line.
	 */
	public @nogc ListBoxItem readLine(int line){
		return items[line];
	}
	/**
	 * Adds a line to the bottom of the list.
	 */
	public void addLine(ListBoxItem i){
		items ~= i;
	}
	/**
	 * Inserts a line to a given point of the list.
	 */
	public void addLine(ListBoxItem i, int n){
		if(n == items.length){
			items ~= i;
		}else{
			items.length++;
			for(int j = cast(int)items.length - 1; j > n; j++){
				items[j] = items[j - 1];
			}
			items[n] = i;
		}
	}
	/**
	 * Removes a line from the list.
	 */
	public void removeLine(int n){
		items.remove(n);
	}
	public void clearArea(WindowElement sender){

	}
}
/**
 * A simple toggle button.
 */
public class CheckBox : WindowElement{
	public int iconChecked, iconUnchecked;
	private bool checked;
	public int[] brush;
	public void delegate(Event ev) onToggle;

	public this(dstring text, string source, Coordinate coordinates, bool checked = false){
		position = coordinates;
		this.text = text;
		this.source = source;
		brush ~= 2;
		brush ~= 3;
		output = new BitmapDrawer(position.width, position.height);
		this.checked = checked;
		//draw();
	}

	public override void draw(){
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawRectangle(getAvailableStyleSheet().getImage("checkBoxA").width, output.output.width - 1, 0,
				output.output.height - 1, 0x0);
		output.drawColorText(getAvailableStyleSheet().getImage("checkBoxA").width, 0, text,
				getAvailableStyleSheet().getFontset("default"), getAvailableStyleSheet().getColor("normaltext"), 0);
		if(checked){
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage("checkBoxB"));
		}else{
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage("checkBoxA"));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}

	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		/*if(state == ButtonState.PRESSED && button == MouseButton.LEFT){
			checked = !checked;
			draw();
			invokeActionEvent(EventType.CHECKBOX, checked);
		}*/
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				checked = !checked;
				draw();
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
				if(onToggle !is null){
					onToggle(new Event(source, null, null, null, null, checked ? 1 : 0, EventType.CHECKBOX));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
	}
	/**
	 * Returns the current value (whether it's checked or not) as a boolean.
	 */
	public @nogc @property bool value(){
		return checked;
	}
	/**
	 * Sets the new value (whether it's checked or not) as a boolean.
	 */
	public @property bool value(bool b){
		checked = b;
		draw();
		return checked;
	}
}
/**
 * Radio buttons, for selecting from multiple options.
 */
public class RadioButtonGroup : WindowElement{
	public int iconChecked, iconUnchecked;
	private int bposition, rowHeight, buttonpos;
	public dstring[] options;
	public int[] brush;
	public ushort border, background;
	public void delegate(Event ev) onToggle;

	public this(dstring text, string source, Coordinate coordinates, dstring[] options, int rowHeight, int buttonpos){
		this.position = coordinates;
		this.text = text;
		this.source = source;
		this.options = options;
		this.rowHeight = rowHeight;
		brush ~= 4;
		brush ~= 5;
		output = new BitmapDrawer(position.width, position.height);
		//draw();
	}

	public override void draw(){
		//output.drawFilledRectangle(0, sizeX-1, 0, sizeY-1, background);
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawRectangle(0, position.width-1, 0, position.height-1, getAvailableStyleSheet().getColor("windowascent"));
		output.drawColorText(16,0,text, getAvailableStyleSheet().getFontset("default"),
				getAvailableStyleSheet().getColor("normaltext"),1);
		for(int i; i < options.length; i++){

			output.drawColorText(16, rowHeight * (i+1),options[i],getAvailableStyleSheet().getFontset("default"),
					getAvailableStyleSheet().getColor("normaltext"),0);
			if(bposition == i){
				output.insertBitmap(1, rowHeight * (i+1),getAvailableStyleSheet.getImage("radioButtonB"));
			}else{
				output.insertBitmap(1, rowHeight * (i+1),getAvailableStyleSheet.getImage("radioButtonA"));
			}
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}

	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
				bposition = (offsetY) / 16;
				bposition--;
				draw();
				if(onToggle !is null){
					onToggle(new Event(source, null, null, null, null, bposition, EventType.RADIOBUTTON));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
	}
	public @property @nogc int value(){
		return bposition;
	}
	public @property int value(int newval){
		bposition = newval;
		draw();
		return bposition;
	}
}

abstract class Slider : WindowElement{
	public int[] brush;

	public int value, maxValue, barLength;
	public void delegate(Event ev) onScrolling;

	/**
	 * Returns the slider position. If barLenght > 1, then it returns the lower value.
	 */
	public @nogc @property int sliderPosition(){
		return value;
	}
	public @property int sliderPosition(int newval){
		if(newval < maxValue){
			value = newval;
			draw();
		}
		return value;
	}
}
/**
 * Vertical slider.
 */
public class VSlider : Slider{
	//public int[] brush;

	//private int value, maxValue, barLength;

	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;
		output = new BitmapDrawer(position.width, position.height);
		brush ~= 6;
		brush ~= 8;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width , 0, position.height , getAvailableStyleSheet.getColor("windowinactive"));
		//draw upper arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("upArrowA"));
		//draw lower arrow
		output.insertBitmap(0, position.height - getAvailableStyleSheet.getImage("downArrowA").height,getAvailableStyleSheet.getImage("downArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA")).height*2, unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;
			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("upArrowA").height, posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("upArrowA").height;

			output.drawFilledRectangle(0,position.width,posA, posB, getAvailableStyleSheet.getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}


	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
				if(offsetY <= getAvailableStyleSheet.getImage("upArrowA").height){
					if(value != 0) value--;
				}else if(position.height-getAvailableStyleSheet.getImage("upArrowA").height <= offsetY){
					if(value < maxValue - barLength) value++;
				}else{
					offsetY -= getAvailableStyleSheet.getImage("upArrowA").height;
					double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA").height*2), unitlength = sliderlength/maxValue;
					int v = to!int(offsetY / unitlength);
					//value = ((sizeY - (elementContainer.getStyleBrush(brush[1]).getY() * 2)) - offsetY) * (value / maxValue);
					if(v < maxValue - barLength) value = v;
					else value = maxValue - barLength;

				}
				draw();
				if(onScrolling !is null){
					onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}

	}
	public override void onScroll(int x, int y, int wX, int wY){

		if(x == 1){
			if(value != 0) value--;
		}else if(x == -1){
			if(value < maxValue - barLength) value++;
		}
		draw();
		if(onScrolling !is null){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
		}
	}
	override public void onDrag(int x,int y,int relX,int relY,ubyte button) {
		value+=relY;
		if(value >= maxValue - barLength)
			value = maxValue;
		else if(value < 0)
			value = 0;
		draw();
		if(onScrolling !is null){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
		}

	}
}
/**
 * Horizontal slider.
 */
public class HSlider : Slider{
	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;
		//writeln(barLenght,',',maxValue);
		output = new BitmapDrawer(position.width, position.height);
		brush ~= 14;
		brush ~= 16;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		if(output.output.width != position.width || output.output.height != position.height)
			output = new BitmapDrawer(position.width, position.height);
		output.drawFilledRectangle(0, position.width , 0, position.height , getAvailableStyleSheet().getColor("windowinactive"));
		//draw left arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("leftArrowA"));
		//draw right arrow
		output.insertBitmap(position.width - getAvailableStyleSheet.getImage("rightArrowA").width,0,getAvailableStyleSheet.getImage("rightArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.width() - (getAvailableStyleSheet.getImage("rightArrowA").width*2), unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;

			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").height, posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").height;

			output.drawFilledRectangle(posA, posB, 0, position.height(),getAvailableStyleSheet().getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int state, ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
				if(offsetX <= getAvailableStyleSheet.getImage("rightArrowA").width){
					if(value != 0) value--;
				}
				else if(position.width-getAvailableStyleSheet.getImage("rightArrowA").width <= offsetX){
					if(value < maxValue - barLength) value++;
				}
				else{
					offsetX -= getAvailableStyleSheet.getImage("rightArrowA").width;
					double sliderlength = position.width() - (elementContainer.getStyleSheet.getImage("rightArrowA").width*2), unitlength = sliderlength/maxValue;
					int v = to!int(offsetX / unitlength);
					if(v < maxValue - barLength) value = v;
					else value = maxValue - barLength;
				}
				draw();
				if(onScrolling !is null){
					onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
	}
	public override void onScroll(int x, int y, int wX, int wY){
		if(y == -1){
			if(value != 0) value--;
		}else if(y == 1){
			if(value < maxValue - barLength) value++;
		}
		draw();
		if(onScrolling.ptr){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
		}
	}
	override public void onDrag(int x,int y,int relX,int relY,ubyte button) {
		value+=relX;
		if(value >= maxValue - barLength)
			value = maxValue;
		else if(value < 0)
			value = 0;
		draw();
		if(onScrolling.ptr){
			onScrolling(new Event(source, null, null, null, null, value, EventType.SLIDER));
		}
	}

}
/**
 * Menubar containing menus in a tree-like structure.
 */
public class MenuBar: WindowElement{
	private PopUpMenuElement[] menus;
	//private wstring[] menuNames;
	private int[] menuWidths;
	//private PopUpHandler popUpHandler;
	private int select, usedWidth;
	public this(string source, Coordinate position, PopUpMenuElement[] menus){
		this.source = source;
		this.position = position;
		//this.popUpHandler = popUpHandler;
		this.menus = menus;
		select = -1;
	}
	public override void draw() {
		StyleSheet ss = getAvailableStyleSheet();
		Fontset!Bitmap8Bit f = ss.getFontset("default");
		if (output is null){
			usedWidth = 1;
			output = new BitmapDrawer(position.width(),position.height());
			foreach(m ; menus){
				menuWidths ~= usedWidth;
				usedWidth += f.getTextLength(m.text) + (ss.drawParameters["MenuBarHorizPadding"] * 2);

			}
			output.drawFilledRectangle(0, position.width(), 0, position.height(), ss.getColor("window"));
		}else{
			output.drawFilledRectangle(0, usedWidth, 0, position.height(), ss.getColor("window"));
		}
		if(select != -1){

		}
		int x = ss.drawParameters["MenuBarHorizPadding"] + 1;
		foreach(m ; menus){
			output.drawColorText(x, ss.drawParameters["MenuBarVertPadding"],m.text,f,ss.getColor("normaltext"),0);
			x += f.getTextLength(m.text) + ss.drawParameters["MenuBarHorizPadding"];
			//output.drawLine(x, x, 0, position.height() - 1, ss.getColor("MenuBarSeparatorColor"));
			x += ss.drawParameters["MenuBarHorizPadding"];
		}
		output.drawLine(0, 0, 0, position.height()-1, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, 0, 0, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, ss.getColor("windowdescent"));
		output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, ss.getColor("windowdescent"));
		elementContainer.drawUpdate(this);
		if(onDraw !is null){
			onDraw();
		}
	}
	private void redirectIncomingEvents(Event ev){
		if(onMouseLClickPre !is null){
			onMouseLClickPre(ev);
		}
	}
	override public void onClick(int offsetX,int offsetY,int state,ubyte button){
		if(button == MouseButton.RIGHT){
			if(state == ButtonState.PRESSED){
				if(onMouseRClickPre !is null){
					onMouseRClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseRClickRel !is null){
					onMouseRClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else if(button == MouseButton.MID){
			if(state == ButtonState.PRESSED){
				if(onMouseMClickPre !is null){
					onMouseMClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseMClickRel !is null){
					onMouseMClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}else{
			if(state == ButtonState.PRESSED){
				if(onMouseLClickPre !is null){
					onMouseLClickPre(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}else{
				if(onMouseLClickRel !is null){
					onMouseLClickRel(new Event(source, null, null, null, null, button, EventType.CLICK));
				}
			}
		}
		//writeln(onMouseLClickPre);
		if(offsetX < usedWidth && button == MouseButton.LEFT && state == ButtonState.PRESSED){
			for(int i = cast(int)menuWidths.length - 1 ; i >= 0 ; i--){
				if(menuWidths[i] < offsetX){
					PopUpMenu p = new PopUpMenu(menus[i].getSubElements(), menus[i].source);
					//p.al = al;
					p.onMouseClick = onMouseLClickPre;//&redirectIncomingEvents;
					Coordinate c = elementContainer.getAbsolutePosition(this);
					popUpHandler.addPopUpElement(p, c.left + menuWidths[i], position.height());
					return;
				}
			}
		}

	}

}
/**
 * For creating pop-up elements like menus.
 */
public abstract class PopUpElement{
	//public ActionListener[] al;
	public BitmapDrawer output;
	public static InputHandler inputhandler;
	public static StyleSheet styleSheet;
	public Coordinate coordinates;
	public StyleSheet customStyle;
	protected PopUpHandler parent;
	protected string source;
	protected dstring text;
	/*public void delegate(Event ev) onMouseLClickRel;
	public void delegate(Event ev) onMouseRClickRel;
	public void delegate(Event ev) onMouseMClickRel;
	public void delegate(Event ev) onMouseHover;
	public void delegate(Event ev) onMouseMove;
	public void delegate(Event ev) onMouseLClickPre;
	public void delegate(Event ev) onMouseRClickPre;
	public void delegate(Event ev) onMouseMClickPre;*/

	public static void delegate() onDraw;
	public void delegate(Event ev) onMouseClick;

	public abstract void draw();

	public void onClick(int offsetX, int offsetY, int type = 0){

	}
	public void onScroll(int x, int y, int wX, int wY){

	}
	public void onMouseMovement(int x, int y){

	}
	public void addParent(PopUpHandler p){
		parent = p;
	}

	protected StyleSheet getStyleSheet(){
		if(customStyle !is null){
			return customStyle;
		}
		if(styleSheet !is null){
			return styleSheet;
		}
		return parent.getStyleSheet();
	}
	/*protected void invokeActionEvent(Event e){
		foreach(ActionListener a; al){
			//a.actionEvent(source, type, value, message);
			//writeln(a);
			a.actionEvent(e);
		}
	}*/
}

/**
 * To create drop-down lists, menu bars, etc.
 */
public class PopUpMenu : PopUpElement{
	//private wstring[] texts;
	//private string[] sources;

	//private uint[int] hotkeyCodes;
	protected Bitmap8Bit[int] icons;
	protected int minwidth, width, height, iconWidth, select;
	PopUpMenuElement[] elements;

	public this(PopUpMenuElement[] elements, string source, int iconWidth = 0){
		this.elements = elements;
		this.source = source;
		this. iconWidth = iconWidth;
		select = -1;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		if(output is null){

			minwidth = (ss.drawParameters["PopUpMenuVertPadding"] * 2) + ss.drawParameters["PopUpMenuMinTextSpace"] + iconWidth;
			width = minwidth;
			foreach(e; elements){
				int newwidth = ss.getFontset("default").getTextLength(e.text~e.secondaryText) + iconWidth;
				if(newwidth > width){
					width = newwidth;
				}
				height += ss.getFontset("default").getSize() + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
			}
			width += (ss.drawParameters["PopUpMenuHorizPadding"] * 2) + ss.drawParameters["PopUpMenuMinTextSpace"];
			height += ss.drawParameters["PopUpMenuVertPadding"] * 2;
			output = new BitmapDrawer(width, height);
			coordinates = Coordinate(0, 0, width, height);
		}
		output.drawFilledRectangle(0,width - 1,0,height - 1,ss.getColor("window"));

		if(select > -1){
			int y0 = cast(int)((height / elements.length) * select);
			int y1 = cast(int)((height / elements.length) + y0);
			output.drawFilledRectangle(1, width - 1, y0 + 1, y1 + 1, ss.getColor("selection"));
		}


		int y = 1 + ss.drawParameters["PopUpMenuVertPadding"];
		foreach(e; elements){
			if(e.secondaryText !is null){
				output.drawColorText(width - ss.drawParameters["PopUpMenuHorizPadding"] - 1, y, e.secondaryText,
						ss.getFontset("default"), ss.getColor("PopUpMenuSecondaryTextColor"), FontFormat.RightJustified);
			}
			output.drawColorText(ss.drawParameters["PopUpMenuHorizPadding"] + iconWidth, y, e.text, ss.getFontset("default"),
					ss.getColor("normaltext"), 0);
			if(e.getIcon() !is null){
				output.insertBitmap(ss.drawParameters["PopUpMenuHorizPadding"], y, e.getIcon());
			}
			y += ss.getFontset("default").getSize() + (ss.drawParameters["PopUpMenuVertPadding"] * 2);
		}

		//output.drawRectangle(1,1,height-1,width-1,ss.getColor("windowascent"));
		output.drawLine(0,0,0,height-1,ss.getColor("windowascent"));
		output.drawLine(0,width-1,0,0,ss.getColor("windowascent"));
		output.drawLine(0,width-1,height-1,height-1,ss.getColor("windowdescent"));
		output.drawLine(width-1,width-1,0,height-1,ss.getColor("windowdescent"));
		if(onDraw !is null){
			onDraw();
		}
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		offsetY /= height / elements.length;
		if(elements[offsetY].source == "\\submenu\\"){
			PopUpMenu m = new PopUpMenu(elements[offsetY].subElements, this.source, elements[offsetY].iconWidth);
			m.onMouseClick = onMouseClick;
			//parent.getAbsolutePosition()
			parent.addPopUpElement(m, coordinates.left + width, coordinates.top + offsetY * cast(int)(height / elements.length));
			//parent.closePopUp(this);
		}else{
			//invokeActionEvent(new Event(elements[offsetY].source, source, null, null, null, offsetY, EventType.CLICK));
			if(onMouseClick !is null)
				onMouseClick(new Event(elements[offsetY].source, source, null, null, null, offsetY, EventType.CLICK));
			parent.endPopUpSession();
			//parent.closePopUp(this);
		}

	}
	public override void onMouseMovement(int x , int y) {
		if(x == -1){
			if(select != -1){
				select = -1;
				draw;
			}
		}else{
			y /= height / elements.length;
			if(y < elements.length){
				select = y;
			}
			draw();
		}
	}

}
/**
* Defines a single MenuElement, also can contain multiple subelements.
*/
public class PopUpMenuElement{
	public string source;
	public dstring text, secondaryText;
	protected Bitmap8Bit icon;
	private PopUpMenuElement[] subElements;
	private ushort keymod;
	private int keycode;
	public int iconWidth;

	public this(string source, dstring text, dstring secondaryText = null, Bitmap8Bit icon = null, int iconWidth = 0){
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.icon = icon;
		this.iconWidth = iconWidth;
	}
	public this(string source, dstring text, dstring secondaryText, PopUpMenuElement[] subElements){
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.subElements = subElements;
		/+this.icon = icon;
		this.iconWidth = iconWidth;+/
	}
	public this(string source, dstring text, dstring secondaryText, PopUpMenuElement[] subElements, Bitmap8Bit icon = null,
			int iconWidth = 0){
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.subElements = subElements;
		/+this.icon = icon;
		this.iconWidth = iconWidth;+/
	}
	public Bitmap8Bit getIcon(){
		return icon;
	}
	public void setIcon(Bitmap8Bit icon){
		this.icon = icon;
	}
	public PopUpMenuElement[] getSubElements(){
		return subElements;
	}
	public void loadSubElements(PopUpMenuElement[] e){
		subElements = e;
	}
	public PopUpMenuElement opIndex(size_t i){
		return subElements[i];
	}
	public PopUpMenuElement opIndexAssign(PopUpMenuElement value, size_t i){
		subElements[i] = value;
		return value;
	}
	public PopUpMenuElement opOpAssign(string op)(PopUpMenuElement value){
		static if(op == "~"){
			subElements ~= value;
			return value;
		}else static assert("Operator " ~ op ~ " not supported!");
	}
	public size_t getLength(){
		return subElements.length;
	}
	public void setLength(int l){
		subElements.length = l;
	}

}
/**
 * Text input in pop-up fashion.
 */
public class PopUpTextInput : PopUpElement, TextInputListener{
	protected bool enableEdit, insert;
	protected int textPos;
	public void delegate(Event ev) onTextInput;

	public this(string source, dstring text, Coordinate coordinates){
		this.source = source;
		this.text = text;
		this.coordinates = coordinates;
		enableEdit = true;
		output = new BitmapDrawer(coordinates.width, coordinates.height);
		inputhandler.startTextInput(this);
	}
	public override void draw(){
		output.drawFilledRectangle(0, coordinates.width - 1, 0, coordinates.height - 1, getStyleSheet().getColor("window"));
		output.drawRectangle(0, coordinates.width - 1, 0, coordinates.height - 1, getStyleSheet().getColor("windowascent"));

		//draw cursor
		if(enableEdit){
			const int x = getStyleSheet().getFontset("default").getTextLength(text[0..textPos]) ,
					y = getStyleSheet().getFontset("default").getSize;
			if(!insert){
				output.drawLine(x + 2, x + 2, 2, 2 + y, getStyleSheet().getColor("selection"));
			}else{
				const int x0 = textPos == text.length ? x + getStyleSheet().getFontset("default").chars[' '].xadvance :
						getStyleSheet().getFontset("default").getTextLength(text[0..textPos + 1]);
				output.drawFilledRectangle(x + 2, x0 + 2, 2, 2 + y, getStyleSheet().getColor("selection"));
			}
		}

		output.drawColorText(2, 2, text, getStyleSheet().getFontset("default"), getStyleSheet().getColor("normaltext"), 0);

		if(onDraw !is null){
			onDraw();
		}
	}
	private void deleteCharacter(int n){
		//text = remove(text, i);
		dstring newtext;
		for(int i; i < text.length; i++){
			if(i != n - 1){
				newtext ~= text[i];
			}
		}
		text = newtext;
	}
	public void textInputEvent(uint timestamp, uint windowID, dstring text){
		int j = textPos;
		dstring newtext;
		for(int i ; i < textPos ; i++){
			newtext ~= this.text[i];
		}
		for(int i ; i < 32 ; i++){
			if(text[i] == 0){
				break;
			}
			else{
				newtext ~= text[i];
				textPos++;
				if(insert){
					j++;
				}
			}
		}
		for( ; j < this.text.length ; j++){
			newtext ~= this.text[j];
		}
		this.text = newtext;
		draw();
	}
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		switch(key){
			case TextInputKey.ESCAPE:
				inputhandler.stopTextInput(this);
				/*draw();
				invokeActionEvent(EventType.TEXTINPUT, 0, text);*/
				break;
			case TextInputKey.ENTER:
				inputhandler.stopTextInput(this);
				//invokeActionEvent(new Event(source, null, null, null, text, text.length, EventType.TEXTINPUT));
				if(onTextInput !is null)
					onTextInput(new Event(source, null, null, null, text, cast(int)text.length, EventType.TEXTINPUT));
				break;
			case TextInputKey.BACKSPACE:
				if(textPos > 0){
					deleteCharacter(textPos);
					textPos--;
					draw();
				}
				break;
			case TextInputKey.DELETE:
				deleteCharacter(textPos + 1);
				draw();
				break;
			case TextInputKey.CURSORLEFT:
				if(textPos > 0){
					--textPos;
					draw();
				}
				break;
			case TextInputKey.CURSORRIGHT:
				if(textPos < text.length){
					++textPos;
					draw();
				}
				break;
			case TextInputKey.INSERT:
				insert = !insert;
				draw();
				break;
			case TextInputKey.HOME:
				textPos = 0;
				draw();
				break;
			case TextInputKey.END:
				textPos = cast(int)text.length;
				draw();
				break;
			default:
				break;

		}
	}
	public void dropTextInput(){
		parent.endPopUpSession();
		//inputHandler.stopTextInput(source);
		/*draw();
		invokeActionEvent(EventType.TEXTINPUT, 0, text);*/
	}
}

public interface PopUpHandler : StyleSheetContainer{
	public void addPopUpElement(PopUpElement p);
	public void addPopUpElement(PopUpElement p, int x, int y);
	public void endPopUpSession();
	public void closePopUp(PopUpElement p);
	//public Coordinate getAbsolutePosition(PopUpElement sender);
	//public void drawUpdate(PopUpElement sender);
	//public StyleSheet getDefaultStyleSheet();

}

/**
 * Defines the header of a ListBox.
 */
public class ListBoxHeader{
	private dstring[] text;
	private int[] width;
	private uint[] textInputType;
	private int iconColumn;
	public this(dstring[] text, int[] width, int iconColumn = 0){
		this.width = width;
		this.text = text;
		this.iconColumn = iconColumn;
	}
	/// Returns the number of columns before drawing
	@nogc public int getNumberOfColumns(){
		return cast(int)this.text.length;
	}
	/// Returns the text at the given point
	@nogc public dstring getText(int i){
		return text[i];
	}
	/// Returns the width of the column
	@nogc public int getColumnWidth(int i){
		return width[i];
	}
	/// Sets the width of the column
	@nogc public void setRowWidth(int i, int x){
		width[i] = x;
	}
	/// Returns the number of column that contains the icon
	@nogc public int getIconColumn(){
		return iconColumn;
	}
	/// Returns the whole width of the header
	@nogc public int getFullWidth(){
		int result;
		foreach(int i; width){
			result += i;
		}
		return result;
	}
	/// Returns the column number from width, or -1 if x can't fit into any range
	@nogc public int getColumnNumFromX(int x){
		int result = -1;
		if(width[0] > x) return 0;
		for(int i = 1; i < width.length; i++){
			if(width[i - 1] <= x || width[i] > x){
				result = i;
			}
		}
		return result;
	}
	/// Returns the width of the columns in a given range
	@nogc public int getRangeWidth(int begin, int end){
		int result;
		for(; begin < end ; begin++){
			result += width[begin];
		}
		return result;
	}
	/// Returns the TextInputType for the column
	@nogc public uint getTextInputType(int column){
		return textInputType[column];
	}
}
/**
 * Defines an item in the row of a ListBox. Can be passed through the Event class
 */
 public class ListBoxItem{
	private dstring[] text;
	private uint[] textInputType;	///If value or array is null, the ListBoxHeader's textInputType is referred
	private Bitmap8Bit icon;	/// If used, replaces the texts in the column defined by the ListBoxHeader, otherwise defaults to the text.
	public this(dstring[] text, Bitmap8Bit icon = null, uint[] textInputType = null){
		this.text = text;
		this.icon = icon;
		this.textInputType = textInputType;
	}
	public this(dstring[] text, uint[] textInputType){
		this.text = text;
		this.icon = null;
		this.textInputType = textInputType;
	}
	/// Returns the text at the given column
	@nogc public dstring getText(int column){
		return text[column];
	}
	/// Sets the text in the given column
	@nogc public void setText(int column, dstring text){
		this.text[column] = text;
	}
	/// Returns the icon
	public Bitmap8Bit getIcon(){
		return icon;
	}
	/// Returns the input type of the given column. Refer to ListBoxHeader if return value = TextInputType.NULL
	@nogc public uint getTextInputType(int column){
		return textInputType[column];
	}
	public override string toString(){
		dstring result;
		foreach(ws; text)
			result ~= ws;
		return to!string(result);
	}
 }
/*
 * For use with ListBoxes and similar types. Currently left here for legacy purposes, being replaced with the classes ListBoxHeader and ListBoxElement
 *
public struct ListBoxColumn{
	public wstring header;
	public wstring[] elements;

	this(wstring header, wstring[] elements){
		this.header = header;
		this.elements = elements;
	}

	/
	public void removeByNumber(int i){
		elements = remove(elements, i);
	}
}*/

/**
 * Defines an action event in the concrete GUI.
 */
public class Event{
	public string source, subsource, path, filename;
	public dstring text;
	public int value, type;
	public Object aux;
	/**
	 *If a field is unneeded, leave it blank by setting it to null.
	 */
	this(string source, string subsource, string path, string filename, dstring textinput, int value, int type,
			Object aux = null){
		this.source = source;
		this.subsource = subsource;
		this.path = path;
		this.filename = filename;
		this.text = textinput;
		this.value = value;
		this.type = type;
		this.aux = aux;
	}
	/**
	 * Returns the full path including the filename
	 */
	public @property string getFullPath(){
		return path ~ filename;
	}
}

/+public interface ActionListener{
	/**
	 * Invoked mostly by WindowElements, Dialogs, and PopUpElements. Used to run the code and pass the eventdata.
	 */
	public void actionEvent(Event event);
}+/

public interface ElementContainer : StyleSheetContainer{
	public Coordinate getAbsolutePosition(WindowElement sender);
	public void clearArea(WindowElement sender);
}

public interface StyleSheetContainer{
	public StyleSheet getStyleSheet();
	public void drawUpdate(WindowElement sender);
}
/**
 * TODO: Use this for implement tabbing and etc.
 */
public interface Focusable{
	public void focusGiven();
	public void focusLost();
	public void tabPressed(bool reverse);
}

public enum EventType{
	CLICK 				= 0,
	TEXTINPUT			= 1,
	SLIDER				= 2,
	TEXTBOXSELECT		= 3,
	CHECKBOX			= 4,
	RADIOBUTTON			= 5,
	FILEDIALOGEVENT		= 6,

}
