/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, concrete.elements module
 */

module PixelPerfectEngine.concrete.elements;

import PixelPerfectEngine.graphics.bitmap;
import PixelPerfectEngine.graphics.draw;
import PixelPerfectEngine.system.etc;
import PixelPerfectEngine.system.inputHandler;
import std.algorithm;
import std.stdio;
import std.conv;
import PixelPerfectEngine.concrete.stylesheet;

abstract class WindowElement{
	public ActionListener[] al;
	protected wstring text;
	protected string source;
	public Coordinate position;
	private int sizeX, sizeY;
	//public int font;
	public BitmapDrawer output;
	//public Bitmap16Bit[int] altStyleBrush;
	public ElementContainer elementContainer;
	public StyleSheet customStyle;
	protected bool state;

	public static InputHandler inputHandler;
	public static PopUpHandler popUpHandler;
	//public static StyleSheet defaultStyle;
	
	public void onClick(int offsetX, int offsetY, int type = 0){
		
	}
	public void onKey(char c, int type){
		
	}
	public void onScroll(int x, int y, int wX, int wY){
		
	}
	@nogc public int getX(){
		return sizeX;
	}
	@nogc public int getY(){
		return sizeY;
	}
	@nogc public Coordinate getPosition(){
		return position;
	}
	/*
	 * Updates the output.
	 */
	public abstract void draw();
	
	protected void invokeActionEvent(int type, int value, wstring message = ""){
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
	}
	/*private Bitmap16Bit getBrush(int style){
		return altStyleBrush.get(style, elementContainer.getStyleBrush(style));
	}*/
	@nogc public wstring getText(){
		return text;
	}
	public void setText(wstring s){
		text = s;
		draw;
	}

	public StyleSheet getAvailableStyleSheet(){
		if(customStyle is null){
			return elementContainer.getStyleSheet();
		}
		return customStyle;
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
}

public class Button : WindowElement{
	
	private bool isPressed;
	public int brushPressed, brushNormal;
	
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
		brushPressed = 1;
		//draw();
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.width()-1, 0,position.height()-1, getAvailableStyleSheet().getColor("window"));
		if(isPressed){
			/*output.drawRectangle(0, sizeX, 0, sizeY, getBrush(brushNormal));
			 int x = getBrush(brushNormal).getX() / 2, y = getBrush(brushNormal).getY() / 2;
			 output.drawFilledRectangle(x, sizeX - 1 - x, y, sizeY - 1 - y, getBrush(brushNormal).readPixel(x, y));*/
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
		}else{
			/*output.drawRectangle(0, sizeX, 0, sizeY, getBrush(brushPressed));
			 int x = getBrush(brushNormal).getX() / 2, y = getBrush(brushNormal).getY() / 2;
			 output.drawFilledRectangle(x, sizeX - 1 - x, y, sizeY - 1 - y, getBrush(brushNormal).readPixel(x, y));*/
			output.drawLine(0, position.width()-1, 0, 0, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, 0, 0, position.height()-1, getAvailableStyleSheet().getColor("windowascent"));
			output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
			output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, getAvailableStyleSheet().getColor("windowdescent"));
		}
		
		output.drawText(sizeX/2, sizeY/2, text, getAvailableStyleSheet().getFontset("default"));
		elementContainer.drawUpdate(this);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		if(type == 0){
			isPressed = !isPressed;
			draw();
			invokeActionEvent(EventType.CLICK, isPressed);
			isPressed = !isPressed;
			draw();
		}
	}
}

public class SmallButton : WindowElement{
	private string iconPressed, iconUnpressed;
	private bool isPressed;
	public int brushPressed, brushNormal;
	
	public this(string iconPressed, string iconUnpressed, string source, Coordinate coordinates){
		position = coordinates;
		
		//this.text = text;
		this.source = source;
		this.iconPressed = iconPressed;
		this.iconUnpressed = iconUnpressed;
		output = new BitmapDrawer(sizeX, sizeY);
		brushPressed = 1;
		//draw();
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.width()-1, 0,position.height()-1, 0);
		if(isPressed){
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage("pressed"));
		}else{
			output.insertBitmap(0,0,getAvailableStyleSheet().getImage("unpressed"));
		}
		elementContainer.drawUpdate(this);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		if(type == 0){
			isPressed = !isPressed;
			draw();
			invokeActionEvent(EventType.CLICK, isPressed);
			isPressed = !isPressed;
			draw();
		}
	}
}

public class Label : WindowElement{
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	public override void draw(){
		//writeln(elementContainer);
		output.drawText(0, 0, text, getAvailableStyleSheet().getFontset("default"), 1);
		elementContainer.drawUpdate(this);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		if(type == 0)
			invokeActionEvent(EventType.CLICK, 0);
	}
}

public class TextBox : WindowElement, TextInputListener{
	private bool enableEdit, insert;
	private uint pos;
	public int brush, textpos;
	//public TextInputHandler tih;
	
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
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
	
	public override void onClick(int offsetX, int offsetY, int type = 0){
		//writeln(0);
		if(!enableEdit && type == 0){
			invokeActionEvent(EventType.READYFORTEXTINPUT, 0);
			enableEdit = true;
			inputHandler.startTextInput(this);
			draw();
		}
	}
	public override void draw(){
		output.drawFilledRectangle(0, sizeX - 1, 0, sizeY - 1, getAvailableStyleSheet().getColor("window"));
		output.drawRectangle(0, sizeX - 1, 0, sizeY - 1, getAvailableStyleSheet().getColor("windowascent"));
		
		//draw cursor
		if(enableEdit){
			int x = getAvailableStyleSheet().getFontset("default").letters['A'].getX() , y = getAvailableStyleSheet().getFontset("default").letters['A'].getY();
			if(!insert)
				output.drawLine((x*pos) + 2, (x*pos) + 2, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
			else
				output.drawFilledRectangle((x*pos) + 2, (x*(pos + 1)) + 2, 2, 2 + y, getAvailableStyleSheet().getColor("selection"));
		}
		
		output.drawText(2, 2, text, getAvailableStyleSheet().getFontset("default"), 1);
		elementContainer.drawUpdate(this);
	}
	
	alias onKey = WindowElement.onKey;
	public void onKey(wchar c, int type){
		
		/*if(enableEdit){
		 if(type == 0){
		 text ~= c;
		 pos++;
		 draw();
		 }else if(type == 1){
		 pos++;
		 }else if(type == 2){
		 pos--;
		 }else if(type == 3){
		 invokeActionEvent(EventType.TEXTINPUT, 0, text);
		 }else{
		 deleteCharacter(pos);
		 pos--;
		 draw();
		 }
		 }*/
	}
	private void deleteCharacter(int n){
		//text = remove(text, i);
		wstring newtext;
		for(int i; i < text.length; i++){
			if(i != n - 1){
				newtext ~= text[i];
			}
		}
		text = newtext;
	}
	public void focusGiven(){}
	public void focusLost(){}
	public void textInputEvent(uint timestamp, uint windowID, char[32] text){
		//writeln(0);
		int j = pos;
		wstring newtext;
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
		invokeActionEvent(EventType.TEXTINPUT, 0, text);
	}


	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier = 0){
		if(key == TextInputKey.ESCAPE || key == TextInputKey.ENTER){
			enableEdit = false;
			inputHandler.stopTextInput(this);
			draw();
			invokeActionEvent(EventType.TEXTINPUT, 0, text);
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
			pos = text.length;
			draw();
		}
	}
}

/**
 * Displays multiple columns of data, also provides general text input.
 */
public class ListBox : WindowElement, ActionListener, ElementContainer{
	//public ListBoxColumn[] columns;
	public ListBoxHeader header;
	public ListBoxItem[] items;
	public int[] columnWidth;
	public int selection, brushHeader, brush, fontHeader, rowHeight;
	public ushort selectionColor;
	private bool fullRedraw, bodyDrawn, enableTextInput, textInputMode, insert;
	private VSlider vSlider;
	private HSlider hSlider;
	private int fullX, hposition, vposition, sliderX, sliderY, startY, endY, selectedColumn, textPos, previousEvent;
	private BitmapDrawer textArea, headerArea;
	private Coordinate textInputArea;
	//private string editedText;
	
	public this(string source, Coordinate coordinates, ListBoxItem[] items, ListBoxHeader header, int rowHeight, bool enableTextInput = false){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		//this.text = text;
		this.source = source;
		this.rowHeight = rowHeight;
		this.items = items;
		this.header = header;
		updateColumns();

		foreach(int i; columnWidth){
			fullX += i;
		}
		if(fullX < position.width()){
			fullX = position.width();
		}
		
		output = new BitmapDrawer(sizeX, sizeY);

		int foo = rowHeight * this.items.length;
		if(foo < position.height())
			foo = position.width();
		this.enableTextInput = enableTextInput;
		//inputHandler.addTextInputListener(source, this);
		
	}
	/*~this(){
		if(!(inputHandler is null))
			inputHandler.removeTextInputListener(source);
	}*/
	public void actionEvent(Event event){
		if(event.source == "textInput"){
			items[selection].setText(selectedColumn, event.text);
			invokeActionEvent(new Event(source, null, null, null, event.text, selection,EventType.TEXTINPUT, items[selection]));
			updateColumns();
			draw();
		}else{
			draw();
		}
	}
	public void getFocus(WindowElement sender){}
	public void dropFocus(WindowElement sender){}
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
	/*public Bitmap16Bit getStyleBrush(int style){
		return elementContainer.getStyleBrush(style);
	}*/
	/*public Bitmap16Bit[wchar] getFontSet(int style){
		return elementContainer.getFontSet(style);
	}*/
	public void updateColumns(ListBoxItem[] items){
		this.items = items;
		updateColumns();
		draw();
	}
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
		
		fullX = header.getFullWidth();
		selection = 0;
		
		if(fullX < position.width()){
			fullX = position.width();
		}
		int foo2 = rowHeight * this.items.length;
		if(foo2 < position.height())
			foo2 = position.height();
		
		textArea = new BitmapDrawer(fullX, foo2);
		headerArea = new BitmapDrawer(fullX, rowHeight);

		this.vSlider = new VSlider(items.length - 1, ((position.height()-17-rowHeight) / rowHeight), "vslider", Coordinate(position.width() - 16, 0, position.width(), position.height() - 16));
		this.hSlider = new HSlider(fullX - 16, position.width() - 16, "hslider", Coordinate(0, position.height() - 16, position.width() - 16, position.height()));
		this.vSlider.al ~= this;
		this.vSlider.elementContainer = this;
		sliderX = vSlider.getX();
		
		
		this.hSlider.al ~= this;
		this.hSlider.elementContainer = this;
		sliderY = hSlider.getY();
		bodyDrawn = false;
	}

	public StyleSheet getStyleSheet(){
		return getAvailableStyleSheet;
	}

	private void drawBody(){
		int foo;
		for(int i; i < header.getNumberOfColumns(); i++){
			int bar;
			for(int j; j < items.length; j++){
				//writeln(foo + 1, bar);
				textArea.drawText(foo + 1, bar, items[j].getText(i), getStyleSheet().getFontset("default"), 1);

				bar += rowHeight;
			}
			foo += header.getColumnWidth(i);
			
			textArea.drawLine(foo, foo, 0, textArea.output.getY()-2, getStyleSheet().getColor("windowascent"));
		}
	}
	
	public override void draw(){
		fullRedraw = true;
		/+if(textInputMode){
			/*Coordinate textArea = Coordinate((selection) * getStyleSheet().drawParameters["ListBoxRowHeight"] - hposition, header.getRangeWidth(0, selectedColumn + 1),
					(selection + 1) * getStyleSheet().drawParameters["ListBoxRowHeight"] - hposition, header.getRangeWidth(0, selectedColumn + 2));*/
			// clear the area
			output.drawFilledRectangle(textInputArea.left, textInputArea.right, textInputArea.top, textInputArea.bottom,getStyleSheet().getColor("window"));
			// draw the cursor
			int x = getAvailableStyleSheet().getFontset("default").getTextLength(text[0..textPos]);
			if(!insert){
				output.drawLine(textInputArea.left + x, textInputArea.left + x, textInputArea.top, textInputArea.bottom, getAvailableStyleSheet().getColor("selection"));
			}else{
				int spaceWidth = getAvailableStyleSheet().getFontset("default").letters[' '].getX();
				output.drawFilledRectangle(textInputArea.left + x, textInputArea.left + x + spaceWidth, textInputArea.top, textInputArea.bottom, getAvailableStyleSheet().getColor("selection"));
			}
			// redraw the new text
			output.drawText(textInputArea.left + 1, textInputArea.top, text, getAvailableStyleSheet().getFontset("default"), 1);
			elementContainer.drawUpdate(this);
		}else{+/
		int areaX, areaY;

		vposition = vSlider.getSliderPosition();
		areaX = sizeX - vSlider.getPosition().width();


		hposition = hSlider.getSliderPosition();
		areaY = sizeY - hSlider.getPosition().height();
			
		output.drawFilledRectangle(0, position.width(), 0, position.height(),getStyleSheet().getColor("window"));
		output.drawRectangle(0, position.width() - 1, 0, position.height() - 1,getStyleSheet().getColor("windowascent"));


		// draw the header
		output.drawLine(0, position.width() - 1, rowHeight, rowHeight, getStyleSheet().getColor("windowascent"));
		int foo;
		for(int i; i < header.getNumberOfColumns(); i++){
			headerArea.drawText(foo + 1, 0, header.getText(i), getStyleSheet().getFontset("default"), 1);
			foo += header.getColumnWidth(i);
			headerArea.drawLine(foo, foo, 0, rowHeight - 2, getStyleSheet().getColor("windowascent"));
		}

		output.insertBitmapSlice(0,0,headerArea.output,Coordinate(hposition,0,hposition + position.width() - 17, rowHeight - 1));

		//draw the selector
		if(selection - vposition >= 0 && vposition + ((position.height()-17-rowHeight) / rowHeight) >= selection && items.length != 0)
			output.drawFilledRectangle(1, position.width() - 2, rowHeight + (rowHeight * (selection - vposition)), (rowHeight * 2) + (rowHeight * (selection - vposition)), getStyleSheet().getColor("selection"));

		// draw the body
		if(!bodyDrawn){
			bodyDrawn = true;
			drawBody();
		}
		//writeln(textArea.output.getX(),textArea.output.getY());
		output.insertBitmapSlice(0, rowHeight, textArea.output, Coordinate(hposition,vposition * rowHeight,hposition + position.width() - 17 , vposition * rowHeight + areaY - rowHeight));

		vSlider.draw();
		hSlider.draw();
		elementContainer.drawUpdate(this);
		
		fullRedraw = false;
		//writeln(0);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		//writeln(textInputMode);
		if(offsetX > (vSlider.getPosition().left) && offsetY > (vSlider.getPosition().top)){
			vSlider.onClick(offsetX - vSlider.getPosition().left, offsetY - vSlider.getPosition().top, type);
			return;

		}else if(offsetX > (hSlider.getPosition().left) && offsetY > (hSlider.getPosition().top)){
			//writeln(offsetX,',',offsetY);
			hSlider.onClick(offsetX - hSlider.getPosition().left, offsetY - hSlider.getPosition().top, type);
			return;
			
		}else if(offsetY > rowHeight && type == 0){
			offsetY -= rowHeight;
			//writeln(selection);
			if(selection == (offsetY / rowHeight) + vposition){
				//invokeActionEvent(EventType.TEXTBOXSELECT, (offsetY / rowHeight) + vposition);
				if(!enableTextInput){
					invokeActionEvent(new Event(source, null, null, null, null, (offsetY / rowHeight) + vposition,EventType.TEXTBOXSELECT, items[selection]));
				}else{
					offsetX += hposition;
					selectedColumn = header.getColumnNumFromX(offsetX);
					//writeln(offsetX);
					if(selectedColumn != -1){
						if(items[selection].getTextInputType(selectedColumn) != TextInputType.DISABLE){
							text = items[selection].getText(selectedColumn);
							invokeActionEvent(EventType.READYFORTEXTINPUT,selectedColumn);
							PopUpTextInput p = new PopUpTextInput("textInput", text, Coordinate(0,0,header.getColumnWidth(selectedColumn),20));
							p.al ~= this;
							popUpHandler.addPopUpElement(p);
							/+textInputArea = Coordinate(header.getRangeWidth(0, selectedColumn), (selection + 1) * rowHeight /*- hposition*/, 
											header.getRangeWidth(0, selectedColumn + 1), (selection + 2) * rowHeight /*- hposition*/);
							writeln(textInputArea);+/
							
						}else{
							invokeActionEvent(new Event(source, null, null, null, null, (offsetY / rowHeight) + vposition,EventType.TEXTBOXSELECT, items[selection]));
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
	}
	public override void onScroll(int x, int y, int wX, int wY){
		if(textInputMode) return;
		vSlider.onScroll(x,y,0,0);
		hSlider.onScroll(x,y,0,0);
	}
	
}

public class CheckBox : WindowElement{
	public int iconChecked, iconUnchecked;
	private bool checked;
	public int[] brush;
	
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		brush ~= 2;
		brush ~= 3;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	
	public override void draw(){
		output.drawText(getAvailableStyleSheet().getImage("checkBoxA").getX, 0, text, getAvailableStyleSheet().getFontset("default"), 1);
		if(checked){
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage("checkBoxB"));
		}else{
			output.insertBitmap(0, 0, getAvailableStyleSheet().getImage("checkBoxA"));
		}
		elementContainer.drawUpdate(this);
	}
	
	public override void onClick(int offsetX, int offsetY, int type = 0){
		checked = !checked;
		draw();
		invokeActionEvent(EventType.CHECKBOX, checked);
	}
}

public class RadioButtonGroup : WindowElement{
	public int iconChecked, iconUnchecked;
	private int bposition, rowHeight, buttonpos;
	public wstring[] options;
	public int[] brush;
	public ushort border, background;
	
	public this(wstring text, string source, Coordinate coordinates, wstring[] options, int rowHeight, int buttonpos){
		this.position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		this.text = text;
		this.source = source;
		this.options = options;
		this.rowHeight = rowHeight;
		brush ~= 4;
		brush ~= 5;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	
	public override void draw(){
		//output.drawFilledRectangle(0, sizeX-1, 0, sizeY-1, background);
		output.drawRectangle(0, sizeX-1, 0, sizeY-1, getAvailableStyleSheet().getColor("windowascent"));
		output.drawText(16,0,text, getAvailableStyleSheet().getFontset("default"),1);
		for(int i; i < options.length; i++){

			output.drawText(16, rowHeight * (i+1),options[i],getAvailableStyleSheet().getFontset("default"),1);
			if(bposition == i){
				output.insertBitmap(1, rowHeight * (i+1),getAvailableStyleSheet.getImage("radioButtonB"));
			}else{
				output.insertBitmap(1, rowHeight * (i+1),getAvailableStyleSheet.getImage("radioButtonA"));
			}
		}
		elementContainer.drawUpdate(this);
	}
	
	public override void onClick(int offsetX, int offsetY, int type = 0){
		bposition = (offsetY) / 16;
		bposition--;
		draw();
		invokeActionEvent(EventType.RADIOBUTTON, bposition);
	}
	public int getValue(){
		return bposition;
	}
}

abstract class Slider : WindowElement{
	public int[] brush;
	
	public int value, maxValue, barLength;
	
	/*
	 * Returns the slider position. If barLenght > 1, then it returns the lower value.
	 */
	public int getSliderPosition(){
		return value;
	}
}

public class VSlider : Slider{
	//public int[] brush;
	
	//private int value, maxValue, barLength;
	
	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;
		output = new BitmapDrawer(sizeX, sizeY);
		brush ~= 6;
		brush ~= 8;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		output.drawFilledRectangle(0, sizeX , 0, sizeY , getAvailableStyleSheet.getColor("windowinactive"));
		//draw upper arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("upArrowA"));
		//draw lower arrow
		output.insertBitmap(0, sizeY - getAvailableStyleSheet.getImage("downArrowA").getY(),getAvailableStyleSheet.getImage("downArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA")).getY()*2, unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;
			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("upArrowA").getY(), posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("upArrowA").getY();

			output.drawFilledRectangle(0,sizeX,posA, posB, getAvailableStyleSheet.getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
	}
	
	
	public override void onClick(int offsetX, int offsetY, int type = 0){
		if(offsetY <= getAvailableStyleSheet.getImage("upArrowA").getY()){
			if(value != 0) value--;

		}
		else if(sizeY-getAvailableStyleSheet.getImage("upArrowA").getY() <= offsetY){
			if(value < maxValue - barLength) value++;

		}
		else{
			offsetY -= getAvailableStyleSheet.getImage("upArrowA").getY();
			double sliderlength = position.height() - (getAvailableStyleSheet.getImage("upArrowA").getY()*2), unitlength = sliderlength/maxValue;
			int v = to!int(offsetY / unitlength);
			//value = ((sizeY - (elementContainer.getStyleBrush(brush[1]).getY() * 2)) - offsetY) * (value / maxValue);
			if(v < maxValue - barLength) value = v;
			else value = maxValue - barLength;

		}

		invokeActionEvent(EventType.SLIDER, value);
		draw();

	}
	public override void onScroll(int x, int y, int wX, int wY){

		if(x == 1){
			if(value != 0) value--;
		}else if(x == -1){
			if(value < maxValue - barLength) value++;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();

	}
}

public class HSlider : Slider{
	public this(int maxValue, int barLenght, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.width();
		sizeY = coordinates.height();
		//this.text = text;
		this.source = source;
		this.maxValue = maxValue;
		this.barLength = barLenght;
		//writeln(barLenght,',',maxValue);
		output = new BitmapDrawer(sizeX, sizeY);
		brush ~= 14;
		brush ~= 16;
		//brush ~= 10;
		//draw();
	}
	public override void draw(){
		//draw background
		//Bitmap16Bit sliderStyle = elementContainer.getStyleBrush(brush[2]);
		//ushort backgroundColor = sliderStyle.readPixel(0,0), sliderColor = sliderStyle.readPixel(1,0);
		output.drawFilledRectangle(0, sizeX , 0, sizeY , getAvailableStyleSheet().getColor("windowinactive"));
		//draw left arrow
		output.insertBitmap(0,0,getAvailableStyleSheet.getImage("leftArrowA"));
		//draw right arrow
		output.insertBitmap(sizeX - getAvailableStyleSheet.getImage("rightArrowA").getX(),0,getAvailableStyleSheet.getImage("rightArrowA"));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.width() - (getAvailableStyleSheet.getImage("rightArrowA").getX()*2), unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;

			int posA = to!int(sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").getY(), posB = to!int(bl + sliderpos) + getAvailableStyleSheet.getImage("rightArrowA").getY();
		
			output.drawFilledRectangle(posA, posB, 0, position.height(),getAvailableStyleSheet().getColor("windowascent"));
		}
		elementContainer.drawUpdate(this);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		if(offsetX <= getAvailableStyleSheet.getImage("rightArrowA").getX()){
			if(value != 0) value--;
		}
		else if(sizeX-getAvailableStyleSheet.getImage("rightArrowA").getX() <= offsetX){
			if(value < maxValue - barLength) value++;
		}
		else{
			offsetX -= getAvailableStyleSheet.getImage("rightArrowA").getX();
			double sliderlength = position.width() - (elementContainer.getStyleSheet.getImage("rightArrowA").getX()*2), unitlength = sliderlength/maxValue;
			int v = to!int(offsetX / unitlength);
			if(v < maxValue - barLength) value = v;
			else value = maxValue - barLength;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();

	}
	public override void onScroll(int x, int y, int wX, int wY){
		if(y == -1){
			if(value != 0) value--;
		}else if(y == 1){
			if(value < maxValue - barLength) value++;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();
	}
}

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
		Fontset f = ss.getFontset("default");
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
			output.drawText(x, ss.drawParameters["MenuBarVertPadding"],m.text,f,1);
			x += f.getTextLength(m.text) + ss.drawParameters["MenuBarHorizPadding"];
			output.drawLine(x, x, 0, position.height() - 1, ss.getColor("MenuBarSeparatorColor"));
			x += ss.drawParameters["MenuBarHorizPadding"];
		}
		output.drawLine(0, 0, 0, position.height()-1, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, 0, 0, ss.getColor("windowascent"));
		output.drawLine(0, position.width()-1, position.height()-1, position.height()-1, ss.getColor("windowdescent"));
		output.drawLine(position.width()-1, position.width()-1, 0, position.height()-1, ss.getColor("windowdescent"));
		elementContainer.drawUpdate(this);
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		
		if(offsetX < usedWidth){
			for(int i = menuWidths.length - 1 ; i >= 0 ; i--){
				if(menuWidths[i] < offsetX){
					PopUpMenu p = new PopUpMenu(menus[i].getSubElements(), menus[i].source);
					p.al = al;
					Coordinate c = elementContainer.getAbsolutePosition(this);
					popUpHandler.addPopUpElement(p, c.left + menuWidths[i], position.height());
					return;
				}
			}
		}
	}
	
}

public abstract class PopUpElement{
	public ActionListener[] al;
	public BitmapDrawer output;
	public static InputHandler inputhandler;
	public Coordinate coordinates;
	public StyleSheet customStyle;
	protected PopUpHandler parent;
	protected string source;
	protected wstring text;

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
		return parent.getStyleSheet();
	}
	protected void invokeActionEvent(Event e){
		foreach(ActionListener a; al){
			//a.actionEvent(source, type, value, message);
			//writeln(a);
			a.actionEvent(e);
		}
	}
}

/**
 * To create drop-down lists, menu bars, etc.
 */
public class PopUpMenu : PopUpElement{
	//private wstring[] texts;
	//private string[] sources;
	
	//private uint[int] hotkeyCodes;
	//private Bitmap16Bit[int] icons;
	private int minwidth, width, height, iconWidth, select;
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
			int y0 = (height / elements.length) * select;
			int y1 = (height / elements.length) + y0;
			output.drawFilledRectangle(1, width - 1, y0 + 1, y1 + 1, ss.getColor("selection"));
		}

		
		int y = 1 + ss.drawParameters["PopUpMenuVertPadding"];
		foreach(e; elements){
			if(e.secondaryText !is null){
				output.drawColorText(width - ss.drawParameters["PopUpMenuHorizPadding"] - 1, y, e.secondaryText, ss.getFontset("default"), ss.getColor("PopUpMenuSecondaryTextColor"), 2);
			}
			output.drawText(ss.drawParameters["PopUpMenuHorizPadding"] + iconWidth, y, e.text, ss.getFontset("default"), 1);
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
		
	}
	public override void onClick(int offsetX, int offsetY, int type = 0){
		offsetY /= height / elements.length;
		if(elements[offsetY].source == "\\submenu\\"){
			PopUpMenu m = new PopUpMenu(elements[offsetY].subElements, this.source, elements[offsetY].iconWidth);
			m.al = al;
			parent.addPopUpElement(m);
			//parent.closePopUp(this);
		}else{
			invokeActionEvent(new Event(elements[offsetY].source, source, null, null, null, offsetY, EventType.CLICK));
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
	public wstring text, secondaryText;
	protected Bitmap16Bit icon;
	private PopUpMenuElement[] subElements;
	private ushort keymod;
	private int keycode;
	public int iconWidth;

	public this(string source, wstring text, wstring secondaryText = null, Bitmap16Bit icon = null, int iconWidth = 0){
		this.source = source;
		this.text = text;
		this.secondaryText = secondaryText;
		this.icon = icon; 
		this.iconWidth = iconWidth;
	}
	public Bitmap16Bit getIcon(){
		return icon;
	}
	public void setIcon(Bitmap16Bit icon){
		this.icon = icon;
	}
	public PopUpMenuElement[] getSubElements(){
		return subElements;
	}
	public PopUpMenuElement opIndex(size_t i){
		return subElements[i];
	}
	public PopUpMenuElement opIndexAssign(PopUpMenuElement value, size_t i){
		subElements[i] = value;
		return value;
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
	public this(string source, wstring text, Coordinate coordinates){
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
			int x = getStyleSheet().getFontset("default").letters['A'].getX() , y = getStyleSheet().getFontset("default").letters['A'].getY();
			if(!insert)
				output.drawLine((x*textPos) + 2, (x*textPos) + 2, 2, 2 + y, getStyleSheet().getColor("selection"));
			else
				output.drawFilledRectangle((x*textPos) + 2, (x*(textPos + 1)) + 2, 2, 2 + y, getStyleSheet().getColor("selection"));
		}
		
		output.drawText(2, 2, text, getStyleSheet().getFontset("default"), 1);
		//elementContainer.drawUpdate(this);
		//parent.drawUpdate(this);
	}
	private void deleteCharacter(int n){
		//text = remove(text, i);
		wstring newtext;
		for(int i; i < text.length; i++){
			if(i != n - 1){
				newtext ~= text[i];
			}
		}
		text = newtext;
	}
	public void textInputEvent(uint timestamp, uint windowID, char[32] text){
		int j = textPos;
		wstring newtext;
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
				invokeActionEvent(new Event(source, null, null, null, text, text.length, EventType.TEXTINPUT));
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
				textPos = text.length;
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
	//public void drawUpdate(PopUpElement sender);
	//public StyleSheet getDefaultStyleSheet();

}

/**
 * Defines the header of a ListBox.
 */
public class ListBoxHeader{
	private wstring[] text;
	private int[] width;
	private uint[] textInputType;
	private int iconColumn;
	public this(wstring[] text, int[] width, int iconColumn = 0){
		this.width = width;
		this.text = text;
		this.iconColumn = iconColumn; 
	}
	/// Returns the number of columns before drawing
	@nogc public int getNumberOfColumns(){
		return this.text.length;
	}
	/// Returns the text at the given point
	@nogc public wstring getText(int i){
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
 * Defines an item in the row of a ListBox. Passed through the Event class
 */
 public class ListBoxItem{
	private wstring[] text;
	private uint[] textInputType;	///If value or array is null, the ListBoxHeader's textInputType is referred
	private Bitmap16Bit icon;	/// If used, replaces the texts in the column defined by the ListBoxHeader, otherwise defaults to the text.
	public this(wstring[] text, Bitmap16Bit icon = null, uint[] textInputType = null){
		this.text = text;
		this.icon = icon;
		this.textInputType = textInputType;
	}
	public this(wstring[] text, uint[] textInputType){
		this.text = text;
		this.icon = null;
		this.textInputType = textInputType;
	}
	/// Returns the text at the given column
	@nogc public wstring getText(int column){
		return text[column];
	}
	/// Sets the text in the given column
	@nogc public void setText(int column, wstring text){
		this.text[column] = text;
	}
	/// Returns the icon
	public Bitmap16Bit getIcon(){
		return icon;
	}
	/// Returns the input type of the given column. Refer to ListBoxHeader if return value = TextInputType.NULL
	@nogc public uint getTextInputType(int column){
		return textInputType[column];
	}
	public override string toString(){
		wstring result;
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
	public wstring text;
	public int value, type;
	public Object aux;
	/**
	 *If a field is unneeded, leave it blank by setting it to null.
	 */
	this(string source, string subsource, string path, string filename, wstring textinput, int value, int type, Object aux = null){
		this.source = source;
		this.subsource = subsource;
		this.path = path;
		this.filename = filename;
		this.text = textinput;
		this.value = value;
		this.type = type;
		this.aux = aux;
	}
}

public interface ActionListener{
	/**
	 * Invoked mostly by WindowElements, Dialogs, and PopUpElements. Used to run the code and pass the eventdata.
	 */
	public void actionEvent(Event event); 
}

public interface ElementContainer : StyleSheetContainer{
	public Coordinate getAbsolutePosition(WindowElement sender);
}

public interface StyleSheetContainer{
	public StyleSheet getStyleSheet();
	
	public void drawUpdate(WindowElement sender);
	
}

public interface Focusable{
	public void focusGiven();
	public void focusLost();
}

public enum EventType{
	READYFORTEXTINPUT	=-1,
	CLICK 				= 0,
	TEXTINPUT			= 1,
	SLIDER				= 2,
	TEXTBOXSELECT		= 3,
	CHECKBOX			= 4,
	RADIOBUTTON			= 5,
	FILEDIALOGEVENT		= 6,

}