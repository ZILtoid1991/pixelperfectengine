/*
 *Copyright (C) 2015, by Laszlo Szeremi under the Boost license.
 *
 *VDP Engine, windowing.elements module
 */

module windowing.elements;

import graphics.bitmap;
import graphics.draw;
import system.etc;
import system.inputHandler;
import std.algorithm;
import std.stdio;
import std.conv;

abstract class WindowElement{
	public ActionListener[] al;
	private wstring text;
	private string source;
	private Coordinate position;
	private int sizeX, sizeY;
	public int font;
	public BitmapDrawer output;
	public Bitmap16Bit[int] altStyleBrush;
	public ElementContainer elementContainer;
	public static InputHandler inputHandler;
	
	public void onClick(int offsetX, int offsetY, int type = 0){
		
	}
	public void onKey(char c, int type){
		
	}
	public void onScroll(int x, int y, int wX, int wY){
		
	}
	public int getX(){
		return sizeX;
	}
	public int getY(){
		return sizeY;
	}
	public Coordinate getPosition(){
		return position;
	}
	/*
	 * Updates the output.
	 */
	public void draw(){
		
	}
	
	private void invokeActionEvent(int type, int value, wstring message = ""){
		foreach(ActionListener a; al){
			a.actionEvent(source, type, value, message);
			a.actionEvent(new Event(source, null, null, null, text, value, type));
		}
	}
	private Bitmap16Bit getBrush(int style){
		return altStyleBrush.get(style, elementContainer.getStyleBrush(style));
	}
	public wstring getText(){
		return text;
	}
	public void setText(wstring s){
		text = s;
		draw;
	}
}

public class Button : WindowElement{
	
	private bool isPressed;
	public int brushPressed, brushNormal;
	
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
		brushPressed = 1;
		//draw();
	}
	public override void draw(){
		output.drawFilledRectangle(0, position.getXSize()-1, 0,position.getYSize()-1, 154);
		if(isPressed){
			/*output.drawRectangle(0, sizeX, 0, sizeY, getBrush(brushNormal));
			 int x = getBrush(brushNormal).getX() / 2, y = getBrush(brushNormal).getY() / 2;
			 output.drawFilledRectangle(x, sizeX - 1 - x, y, sizeY - 1 - y, getBrush(brushNormal).readPixel(x, y));*/
			output.drawLine(0, position.getXSize()-1, 0, 0, 145);
			output.drawLine(0, 0, 0, position.getYSize()-1, 145);
			output.drawLine(0, position.getXSize()-1, position.getYSize()-1, position.getYSize()-1, 158);
			output.drawLine(position.getXSize()-1, position.getXSize()-1, 0, position.getYSize()-1, 158);
		}else{
			/*output.drawRectangle(0, sizeX, 0, sizeY, getBrush(brushPressed));
			 int x = getBrush(brushNormal).getX() / 2, y = getBrush(brushNormal).getY() / 2;
			 output.drawFilledRectangle(x, sizeX - 1 - x, y, sizeY - 1 - y, getBrush(brushNormal).readPixel(x, y));*/
			output.drawLine(0, position.getXSize()-1, 0, 0, 158);
			output.drawLine(0, 0, 0, position.getYSize()-1, 158);
			output.drawLine(0, position.getXSize()-1, position.getYSize()-1, position.getYSize()-1, 145);
			output.drawLine(position.getXSize()-1, position.getXSize()-1, 0, position.getYSize()-1, 145);
		}
		
		output.drawText(sizeX/2, sizeY/2, text, elementContainer.getFontSet(font));
		elementContainer.drawUpdate(this);
	}
	public void onClick(int offsetX, int offsetY, int type = 0){
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
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	public override void draw(){
		//writeln(elementContainer);
		output.drawText(0, 0, text, elementContainer.getFontSet(font), 1);
		elementContainer.drawUpdate(this);
	}
	public void onClick(int offsetX, int offsetY, int type = 0){
		if(type == 0)
			invokeActionEvent(EventType.CLICK, 0);
	}
}

public class TextBox : WindowElement, TextInputListener{
	private bool enableEdit, insert;
	private uint pos;
	public int brush, textpos;
	public TextInputHandler tih;
	
	public this(wstring text, string source, Coordinate coordinates){
		position = coordinates;
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		this.text = text;
		this.source = source;
		output = new BitmapDrawer(sizeX, sizeY);
		//insert = true;
		//draw();
	}

	public void addTextInputHandler(TextInputHandler t){
		tih = t;
		t.addTextInputListener(source, this);
	}
	
	public void onClick(int offsetX, int offsetY, int type = 0){
		//writeln(0);
		if(!enableEdit && type == 0){
			invokeActionEvent(EventType.READYFORTEXTINPUT, 0);
			enableEdit = true;
			tih.startTextInput(source);
			draw();
		}
	}
	public override void draw(){
		output.drawFilledRectangle(0, sizeX - 1, 0, sizeY - 1, 154);
		output.drawRectangle(0, sizeX - 1, 0, sizeY - 1, 158);
		
		//draw cursor
		if(enableEdit){
			int x = elementContainer.getFontSet(font)['A'].getX() , y = elementContainer.getFontSet(font)['A'].getY();
			if(!insert)
				output.drawLine((x*pos) + 2, (x*pos) + 2, 2, 2 + y, 14);
			else
				output.drawFilledRectangle((x*pos) + 2, (x*(pos + 1)) + 2, 2, 2 + y, 14);
		}
		
		output.drawText(2, 2, text, elementContainer.getFontSet(font), 1);
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
		tih.stopTextInput(source);
		draw();
		invokeActionEvent(EventType.TEXTINPUT, 0, text);
	}


	public void textInputKeyEvent(uint timestamp, uint windowID, InputKey key){
		if(key == InputKey.ESCAPE || key == InputKey.ENTER){
			enableEdit = false;
			tih.stopTextInput(source);
			draw();
			invokeActionEvent(EventType.TEXTINPUT, 0, text);
		}else if(key == InputKey.BACKSPACE){
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
		}else if(key == InputKey.DELETE){
			deleteCharacter(pos + 1);
			draw();
		}else if(key == InputKey.CURSORLEFT){
			if(pos > 0){
				--pos;
				draw();
			}
		}else if(key == InputKey.CURSORRIGHT){
			if(pos < text.length){
				++pos;
				draw();
			}
		}else if(key == InputKey.INSERT){
			insert = !insert;
			draw();
		}else if(key == InputKey.HOME){
			pos = 0;
			draw();
		}else if(key == InputKey.END){
			pos = text.length;
			draw();
		}
	}
}


public class ListBox : WindowElement, ActionListener, ElementContainer{
	public ListBoxColumn[] columns;
	public int[] columnWidth;
	public int brushHeader, brush, fontHeader, rowHeight;
	public ushort selectionColor;
	private bool fullRedraw, bodyDrawn;
	private VSlider vSlider;
	private HSlider hSlider;
	private int fullX, hposition, vposition, selection, sliderX, sliderY, startY, endY;
	private BitmapDrawer textArea, headerArea;
	
	public this(string source, Coordinate coordinates, ListBoxColumn[] columns, int[] columnWidth, int rowHeight, /*VSlider vSlider = null, HSlider = null*/){
		position = coordinates;
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		//this.text = text;
		this.source = source;
		this.rowHeight = rowHeight;
		this.columnWidth = columnWidth;
		updateColumns(columns);

		foreach(int i; columnWidth){
			fullX += i;
		}
		if(fullX < position.getXSize()){
			fullX = position.getXSize();
		}
		
		output = new BitmapDrawer(sizeX, sizeY);

		int foo = rowHeight * this.columns[0].elements.length;
		if(foo < position.getYSize())
			foo = position.getXSize;

		/*textArea = new BitmapDrawer(fullX, foo);
		headerArea = new BitmapDrawer(fullX, rowHeight);*/
		//writeln(columns[0].elements.length,',', ((position.getYSize()-16-rowHeight) / rowHeight));
		/*this.vSlider = new VSlider(columns[0].elements.length - 1, ((position.getYSize()-17-rowHeight) / rowHeight), "vslider", Coordinate(position.getXSize - 16, 0, position.getXSize, position.getYSize() - 16));
		this.hSlider = new HSlider(fullX - 16, position.getXSize() - 16, "hslider", Coordinate(0, position.getYSize() - 16, position.getXSize() - 16, position.getYSize() ));
		this.vSlider.al ~= this;
		this.vSlider.elementContainer = this;
		sliderX = vSlider.getX();


		this.hSlider.al ~= this;
		this.hSlider.elementContainer = this;
		sliderY = hSlider.getY();*/
	}
	
	public void actionEvent(string source, int type, int value, wstring message){
		draw();
	}
	public void actionEvent(string source, string subsource, int type, int value, wstring message){}
	public void actionEvent(Event event){}
	public void getFocus(WindowElement sender){}
	public void dropFocus(WindowElement sender){}
	public void drawUpdate(WindowElement sender){
		output.insertBitmap(sender.getPosition().xa,sender.getPosition().ya,sender.output.output);

		if(!fullRedraw){
			/*output.insertBitmapSlice(0,0,headerArea.output,Coordinate(vposition,0,vposition + fullX - 1, rowHeight - 1));
			output.insertBitmapSlice(0, rowHeight, textArea.output, Coordinate(vposition,hposition * rowHeight,vposition + fullX - 1 , hposition * rowHeight + (sizeY - hSlider.getPosition().getYSize) - rowHeight));*/
			elementContainer.drawUpdate(this);
		}
	}
	public Bitmap16Bit getStyleBrush(int style){
		return elementContainer.getStyleBrush(style);
	}
	public Bitmap16Bit[wchar] getFontSet(int style){
		return elementContainer.getFontSet(style);
	}
	public void updateColumns(ListBoxColumn[] lbc){
		columns = lbc;
		fullX = 0;
		selection = 0;
		foreach(int i; columnWidth){
			fullX += i;
		}
		if(fullX < position.getXSize()){
			fullX = position.getXSize();
		}
		int foo2 = rowHeight * this.columns[0].elements.length;
		if(foo2 < position.getYSize())
			foo2 = position.getXSize;
		
		textArea = new BitmapDrawer(fullX, foo2);
		headerArea = new BitmapDrawer(fullX, rowHeight);

		this.vSlider = new VSlider(columns[0].elements.length - 1, ((position.getYSize()-17-rowHeight) / rowHeight), "vslider", Coordinate(position.getXSize - 16, 0, position.getXSize, position.getYSize() - 16));
		this.hSlider = new HSlider(fullX - 16, position.getXSize() - 16, "hslider", Coordinate(0, position.getYSize() - 16, position.getXSize() - 16, position.getYSize() ));
		this.vSlider.al ~= this;
		this.vSlider.elementContainer = this;
		sliderX = vSlider.getX();
		
		
		this.hSlider.al ~= this;
		this.hSlider.elementContainer = this;
		sliderY = hSlider.getY();
		bodyDrawn = false;
	}

	private void drawBody(){
		int foo;
		for(int i; i < columns.length; i++){
			int bar;
			for(int j; j < columns[i].elements.length; j++){
				//writeln(foo + 1, bar);
				textArea.drawText(foo + 1, bar, columns[i].elements[j], elementContainer.getFontSet(0), 1);

				bar += rowHeight;
			}
			foo += columnWidth[i];
			//writeln(foo, foo, 0, textArea.output.getX()-1);
			textArea.drawLine(foo, foo, 0, textArea.output.getY()-2, 158);
		}
	}

	public override void draw(){
		fullRedraw = true;




		int areaX, areaY;

		vposition = vSlider.getSliderPosition();
		areaX = sizeX - vSlider.getPosition().getXSize;


		hposition = hSlider.getSliderPosition();
		areaY = sizeY - hSlider.getPosition().getYSize;

		//writeln(vposition, hposition);


		output.drawFilledRectangle(0, position.getXSize(), 0, position.getYSize(),154);
		output.drawRectangle(0, position.getXSize() - 1, 0, position.getYSize() - 1,158);


		// draw the header
		output.drawLine(0, position.getXSize() - 1, rowHeight, rowHeight, 158);
		int foo;
		for(int i; i < columnWidth.length; i++){
			headerArea.drawText(foo + 1, 0, columns[i].header, elementContainer.getFontSet(0), 1);
			foo += columnWidth[i];
			headerArea.drawLine(foo, foo, 0, rowHeight - 2, 158);
			//writeln(foo);
		}

		output.insertBitmapSlice(0,0,headerArea.output,Coordinate(hposition,0,hposition + position.getXSize() - 17, rowHeight - 1));

		//draw the selector
		if(selection - vposition >= 0 && vposition + ((position.getYSize()-17-rowHeight) / rowHeight) >= selection && columns[0].elements.length != 0)
			output.drawFilledRectangle(1, position.getXSize() - 2, rowHeight + (rowHeight * (selection - vposition)), (rowHeight * 2) + (rowHeight * (selection - vposition)), 14);

		// draw the body
		if(!bodyDrawn){
			bodyDrawn = true;
			drawBody();
		}

		//writeln(textArea.output.getX(),textArea.output.getY());
		output.insertBitmapSlice(0, rowHeight, textArea.output, Coordinate(hposition,vposition * rowHeight,hposition + position.getXSize() - 17 , vposition * rowHeight + areaY - rowHeight));

		vSlider.draw();
		hSlider.draw();

		elementContainer.drawUpdate(this);
		fullRedraw = false;
	}
	public void onClick(int offsetX, int offsetY, int type = 0){
		if(offsetX > (vSlider.getPosition().xa) && offsetY > (vSlider.getPosition().ya)){
			vSlider.onClick(offsetX - vSlider.getPosition().xa, offsetY - vSlider.getPosition().ya, type);
			return;

		}else if(offsetX > (hSlider.getPosition().xa) && offsetY > (hSlider.getPosition().ya)){
			//writeln(offsetX,',',offsetY);
			hSlider.onClick(offsetX - hSlider.getPosition().xa, offsetY - hSlider.getPosition().ya, type);
			return;
			
		}else if(offsetY > rowHeight && type == 0){
			offsetY -= rowHeight;
			//writeln(selection);
			if(selection == (offsetY / rowHeight) + vposition){
				invokeActionEvent(EventType.TEXTBOXSELECT, (offsetY / rowHeight) + vposition);
			}
			else{
				if((offsetY / rowHeight) + vposition < columns[0].elements.length){
					selection = (offsetY / rowHeight) + vposition;
					draw();
				}
			}
		}
	}
	public void onScroll(int x, int y, int wX, int wY){

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
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		this.text = text;
		this.source = source;
		brush ~= 2;
		brush ~= 3;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	
	public override void draw(){
		output.drawText(0 ,0 , text, elementContainer.getFontSet(font), 1);
		if(checked){
			output.insertBitmap(sizeX - getBrush(brush[0]).getX(), 0, getBrush(brush[0]));
		}else{
			output.insertBitmap(sizeX - getBrush(brush[1]).getX(), 0, getBrush(brush[1]));
		}
		elementContainer.drawUpdate(this);
	}
	
	public void onClick(int offsetX, int offsetY, int type = 0){
		checked = !checked;
		draw();
		invokeActionEvent(EventType.CHECKBOX, checked);
	}
}

public class RadioButtonGroup : WindowElement{
	public int iconChecked, iconUnchecked;
	private int bposition, rowSpace, buttonpos;
	public wstring[] options;
	public int[] brush;
	public ushort border, background;
	
	public this(wstring text, string source, Coordinate coordinates, wstring[] options, int rowSpace, int buttonpos){
		this.position = coordinates;
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
		this.text = text;
		this.source = source;
		this.options = options;
		brush ~= 4;
		brush ~= 5;
		output = new BitmapDrawer(sizeX, sizeY);
		//draw();
	}
	
	public override void draw(){
		//output.drawFilledRectangle(0, sizeX-1, 0, sizeY-1, background);
		output.drawRectangle(0, sizeX-1, 0, sizeY-1, 156);
		output.drawText(16,0,text,elementContainer.getFontSet(font),1);
		for(int i; i < options.length; i++){

			output.drawText(16, 16 * (i+1),options[i],elementContainer.getFontSet(font),1);
			if(bposition == i){
				output.insertBitmap(1, 16 * (i+1),getBrush(brush[1]));
			}else{
				output.insertBitmap(1, 16 * (i+1),getBrush(brush[0]));
			}
		}
		elementContainer.drawUpdate(this);
	}
	
	public void onClick(int offsetX, int offsetY, int type = 0){
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
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
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
		output.drawFilledRectangle(0, sizeX , 0, sizeY , 151);
		//draw upper arrow
		output.insertBitmap(0,0,elementContainer.getStyleBrush(brush[0]));
		//draw lower arrow
		output.insertBitmap(0,sizeY-elementContainer.getStyleBrush(brush[1]).getY(),elementContainer.getStyleBrush(brush[1]));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.getYSize() - (elementContainer.getStyleBrush(brush[1]).getY()*2), unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;
			int posA = to!int(sliderpos) + elementContainer.getStyleBrush(brush[1]).getY(), posB = to!int(bl + sliderpos) + elementContainer.getStyleBrush(brush[1]).getY();

			output.drawFilledRectangle(0,sizeX,posA, posB,156);
		}
		elementContainer.drawUpdate(this);
	}
	
	
	public void onClick(int offsetX, int offsetY, int type = 0){
		if(offsetY <= elementContainer.getStyleBrush(brush[1]).getY()){
			if(value != 0) value--;
		}
		else if(sizeY-elementContainer.getStyleBrush(brush[1]).getY() <= offsetY){
			if(value < maxValue - barLength) value++;
		}
		else{
			offsetY -= elementContainer.getStyleBrush(brush[1]).getY();
			double sliderlength = position.getYSize() - (elementContainer.getStyleBrush(brush[1]).getY()*2), unitlength = sliderlength/maxValue;
			int v = to!int(offsetY / unitlength);
			//value = ((sizeY - (elementContainer.getStyleBrush(brush[1]).getY() * 2)) - offsetY) * (value / maxValue);
			if(v < maxValue - barLength) value = v;
			else value = maxValue - barLength;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();

	}
	public void onScroll(int x, int y, int wX, int wY){

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
		sizeX = coordinates.getXSize();
		sizeY = coordinates.getYSize();
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
		output.drawFilledRectangle(0, sizeX , 0, sizeY , 151);
		//draw upper arrow
		output.insertBitmap(0,0,elementContainer.getStyleBrush(brush[0]));
		//draw lower arrow
		output.insertBitmap(sizeX-elementContainer.getStyleBrush(brush[1]).getX(),0,elementContainer.getStyleBrush(brush[1]));
		//draw slider
		if(maxValue > barLength){
			double sliderlength = position.getXSize() - (elementContainer.getStyleBrush(brush[1]).getX()*2), unitlength = sliderlength/maxValue;
			double sliderpos = unitlength * value, bl = unitlength * barLength;

			int posA = to!int(sliderpos) + elementContainer.getStyleBrush(brush[1]).getY(), posB = to!int(bl + sliderpos) + elementContainer.getStyleBrush(brush[1]).getY();
		
			output.drawFilledRectangle(posA, posB, 0, position.getYSize(),156);
		}
		elementContainer.drawUpdate(this);
	}
	public void onClick(int offsetX, int offsetY, int type = 0){
		if(offsetX <= elementContainer.getStyleBrush(brush[1]).getX()){
			if(value != 0) value--;
		}
		else if(sizeX-elementContainer.getStyleBrush(brush[1]).getX() <= offsetX){
			if(value < maxValue - barLength) value++;
		}
		else{
			offsetX -= elementContainer.getStyleBrush(brush[1]).getX();
			double sliderlength = position.getXSize() - (elementContainer.getStyleBrush(brush[1]).getX()*2), unitlength = sliderlength/maxValue;
			int v = to!int(offsetX / unitlength);
			if(v < maxValue - barLength) value = v;
			else value = maxValue - barLength;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();

	}
	public void onScroll(int x, int y, int wX, int wY){
		if(y == -1){
			if(value != 0) value--;
		}else if(y == 1){
			if(value < maxValue - barLength) value++;
		}
		invokeActionEvent(EventType.SLIDER, value);
		draw();
	}
}

/**
 * To create drop-down lists, menu bars, etc.
 */
public class PopUpMenu: PopUpElement{
	private wstring[] texts;
	private string[] sources;
	private string subsource;
	private uint[int] hotkeyCodes;
	private Bitmap16Bit[int] icons;
	private ElementContainer elementContainer;
	public static InputHandler inputhandler;

	public this(int columnheight, string subsource, string[] sources, wstring[] texts, uint[int] hotkeyCodes = null){

	}

	/**
	 * Use this if you want icons in your list.
	 * All the icons have to be the same exact size, otherwise it might cause exceptions.
	 */
	public this(int columnheight, string subsource, string[] sources, wstring[] texts, Bitmap16Bit[int] icons, uint[int] hotkeyCodes = null){
		
	}

	public void onClick(int x, int y){
		
	}
	public void onKey(uint keycode){
		
	}
	public void onScroll(int x, int y, int wX, int wY){
		
	}
}
public interface PopUpElement{
	public void onClick(int x, int y); 
	public void addPopUpHandler(PopUpHandler p);
}
public interface PopUpHandler{
	public void addPopUpElement(PopUpElement p);
}

/*public interface IElement{
	public void onClick();
	public Coordinate getPosition();
}*/
/**
 * For use with ListBoxes and similar types
 */
public struct ListBoxColumn{
	public wstring header;
	public wstring[] elements;
	
	this(wstring header, wstring[] elements){
		this.header = header;
		this.elements = elements;
	}

	/*this(string header, string[] elements){
		this.header = to!wstring(header);
		//this.elements = elements;
	}*/
	
	public void removeByNumber(int i){
		elements = remove(elements, i);
	}
}

public class Event{
	public string source, subsource, path, filename;
	public wstring text;
	public int value, type;
	/**
	 *If a field is unneeded, leave it blank by setting it to null.
	 */
	this(string source, string subsource, string path, string filename, wstring textinput, int value, int type){
		this.source = source;
		this.subsource = subsource;
		this.path = path;
		this.filename = filename;
		this.text = textinput;
		this.value = value;
		this.type = type;
	}
}

public interface ActionListener{
	public void actionEvent(string source, int type, int value, wstring message);
	public void actionEvent(string source, string subSource, int type, int value, wstring message);
	/// During development, I decided to move to a more "Swing-like" event system, use this instead. Better for adding new features in the future.
	public void actionEvent(Event event); 
}

public interface ElementContainer{
	public Bitmap16Bit getStyleBrush(int style);
	public Bitmap16Bit[wchar] getFontSet(int style);
	public void drawUpdate(WindowElement sender);
	public void getFocus(WindowElement sender);
	public void dropFocus(WindowElement sender);
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
	FILEDIALOGEVENT		= 6
}