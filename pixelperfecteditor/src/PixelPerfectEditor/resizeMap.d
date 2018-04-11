import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;
import std.conv;

public class ResizeMap : Window { 
	Label label1;
	Label label2;
	TextBox mX;
	TextBox mY;
	Button button_ok;
	this(int x, int y){
		super(Coordinate(0, 0, 140, 100), "Resize Map"w);
		label1 = new Label("mX:"w, "", Coordinate(5, 22, 40, 39));
		addElement(label1, EventProperties.MOUSE);
		label2 = new Label("mY:"w, "", Coordinate(5, 42, 40, 58));
		addElement(label2, EventProperties.MOUSE);
		mX = new TextBox(to!wstring(x), "mX", Coordinate(40, 20, 136, 38));
		addElement(mX, EventProperties.MOUSE);
		mY = new TextBox(to!wstring(y), "mY", Coordinate(40, 40, 136, 58));
		addElement(mY, EventProperties.MOUSE);
		button_ok = new Button("Ok"w, "button_ok", Coordinate(80, 75, 136, 95));
		addElement(button_ok, EventProperties.MOUSE);
	}
	
}