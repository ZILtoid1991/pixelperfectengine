module windows.about;

import pixelperfectengine.concrete.window;
import pixelperfectengine.graphics.common;
import pixelperfectengine.system.systemutility;

immutable dstring verInfo = "0.10.0"d;

public class AboutWindow : Window {
	Label label1;
	Label label2;
	Label label3;
	Label label4;
	Label label5;
	Label label6;
	Label label7;
	Button buttonClose;
	this(){
		super(Coordinate(0, 0, 305, 185), "About"d);
		label1 = new Label("PixelPerfectEditor"d, "label1", Coordinate(5, 20, 320, 40));
		label2 = new Label("Version: "d ~ verInfo, "label2", Coordinate(5, 40, 300, 60));
		label3 = new Label("Build date: "d, "label3", Coordinate(5, 60, 300, 80));
		label4 = new Label("Engine ver.: "d ~ engineVer, "label4", Coordinate(5, 80, 300, 100));
		label5 = new Label("SDL2 ver.: "d ~ sdlVer, "label5", Coordinate(5, 100, 300, 120));
		label6 = new Label("System/OS: "d ~ osInfo, "label6", Coordinate(5, 120, 300, 140));
		label7 = new Label("Rendering method: "d ~ renderInfo, "label7", Coordinate(5, 140, 300, 160));
		buttonClose = new Button("Close"d, "buttonClose", Coordinate(231, 160, 300, 180));
		buttonClose.onMouseLClick = &buttonClose_onMouseLClickRel;
		addElement(buttonClose);
		addElement(label1);
		addElement(label2);
		addElement(label3);
		addElement(label4);
		addElement(label5);
		addElement(label6);
		addElement(label7);
	}
	private void buttonClose_onMouseLClickRel(Event ev) {
		close();

	}

}
