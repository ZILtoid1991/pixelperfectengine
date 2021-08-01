module windows.resizemap;

import pixelperfectengine.concrete.window;
import pixelperfectengine.graphics.common;
import pixelperfectengine.map.mapformat;
import std.conv;
import document;

public class ResizeMap : Window {
	Label label1;
	Label label2;
	Label label3;
	Label label4;
	CheckBox checkBox_repeat;
	RadioButtonGroup origin;
	RadioButton[9] originSelectors;
	Panel originPanel;
	TextBox mX;
	TextBox mY;
	TextBox offsetX;
	TextBox offsetY;
	Button button_ok;
	int x, y, targetLayer;
	MapDocument targetDoc;
	this(MapDocument targetDoc) {
		import pixelperfectengine.graphics.layers : ITileLayer;
		super(Coordinate(0, 0, 195, 120), "Resize Map");
		targetLayer = targetDoc.selectedLayer;
		ITileLayer layer = cast(ITileLayer)targetDoc.mainDoc.layeroutput[targetLayer];
		x = layer.getMX;
		y = layer.getMY;
		
		this.targetDoc = targetDoc;
		label1 = new Label("mX:", "", Coordinate(5, 22, 80, 38));
		addElement(label1);
		label2 = new Label("mY:", "", Coordinate(5, 42, 80, 58));
		addElement(label2);
		label3 = new Label("offsetX:", "", Coordinate(5, 62, 80, 78));
		addElement(label3);
		label4 = new Label("offsetY:", "", Coordinate(5, 82, 80, 98));
		addElement(label4);
		checkBox_repeat = new CheckBox("Pattern repeat", "repeat", Coordinate(5, 102, 135, 118));
		addElement(checkBox_repeat);
		mX = new TextBox(to!dstring(x), "mX", Coordinate(80, 20, 135, 38));
		addElement(mX);
		mX.onTextInput = &checkTextInput;
		mY = new TextBox(to!dstring(y), "mY", Coordinate(80, 40, 135, 58));
		addElement(mY);
		mY.onTextInput = &checkTextInput;
		offsetX = new TextBox("0", "offsetX", Coordinate(80, 60, 135, 78));
		addElement(offsetX);
		offsetX.onTextInput = &checkTextInput;
		offsetY = new TextBox("0", "offsetY", Coordinate(80, 80, 135, 98));
		addElement(offsetY);
		offsetY.onTextInput = &checkTextInput;
		button_ok = new Button("Ok", "button_ok", Coordinate(140, 102, 193, 118));
		addElement(button_ok);
		button_ok.onMouseLClick = &button_ok_onClick;
		originPanel = new Panel("Origin:", "", Coordinate(140, 20, 193, 92));
		addElement(originPanel);
		origin = new RadioButtonGroup();
		for(int iy ; iy < 3 ; iy++) {
			for(int ix ; ix < 3 ; ix++) {
				const Coordinate rbPos = Coordinate(143 + (16*ix), 40 + (16*iy), 143 + 16 + (16*ix), 40 + 16 + (16*iy));
				RadioButton rb = new RadioButton("radioButtonB", "radioButtonA",to!string(ix) ~ to!string(iy), rbPos, origin);
				originSelectors[ix + (iy * 3)] = rb;
				originPanel.addElement(rb);
			}
		}
		origin.latch(originSelectors[0]);
	}
	private void checkTextInput(Event ev) {
		import std.string : isNumeric;
		WindowElement src = cast(WindowElement)ev.sender;
		dstring str = src.getText.text;
		if(str[$-1] == '%') str = str[0..$-1];
		if(!isNumeric(str)) {
			switch (src.getSource) {
				case "mX":
					mX.setText(to!dstring(x));
					break;
				case "mY":
					mY.setText(to!dstring(y));
					break;
				case "offsetX":
					offsetX.setText("0");
					break;
				case "offsetY":
					offsetY.setText("0");
					break;
				default:
					debug assert(0, "Wrong source value");
					else break;
			}
			handler.message("Invalid data!", "Please enter numeric values with optional \'%\' symbol at the end!");
		}
	}
	private void button_ok_onClick(Event ev) {
		import editorevents : ResizeTileMapEvent;
		int calcMValue(int offset, int oldSize, int newSize) @safe pure nothrow @nogc {
			return offset + (newSize/2 - oldSize/2);
		}
		int calcRValue(int offset, int oldSize, int newSize) @safe pure nothrow @nogc {
			return offset + (newSize - oldSize);
		}
		int oX = to!int(offsetX.getText.text), oY = to!int(offsetY.getText.text);
		//int tX = to!int(this.mX.getText.text), tY = to!int(this.mY.getText.text);
		int tX, tY;
		if(offsetX.getText.text[$-1] == '%') 
			tX = cast(int)(x * (to!double(offsetX.getText.text[0..$-1]) / 100.0));
		else tX = to!int(mX.getText.text);
		if(offsetY.getText.text[$-1] == '%') 
			tX = cast(int)(y * (to!double(offsetY.getText.text[0..$-1]) / 100.0));
		else tY = to!int(mY.getText.text);
		switch(origin.value[0]) {
			case '1':
				oX = calcMValue(oX,x,tX);
				break;
			case '2':
				oX = calcRValue(oX,x,tX);
				break;
			default: break;
		}
		switch(origin.value[1]) {
			case '1':
				oY = calcMValue(oY,y,tY);
				break;
			case '2':
				oY = calcRValue(oY,y,tY);
				break;
			default: break;
		}
		ResizeTileMapEvent rtme = new ResizeTileMapEvent([x, y, oX, oY, tX, tY], targetDoc, targetLayer, 
				checkBox_repeat.isChecked);
		targetDoc.events.addToTop(rtme);
		targetDoc.outputWindow.updateRaster();
		this.close();
	}
}