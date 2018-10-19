module newConverterDialog;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;


public class ImportDialog : Window {
	Label label1;
	TextBox bitmapID;
	TextBox paletteID;
	Label label2;
	CheckBox chkBPal;
	RadioButtonGroup radioButtonGroup1;
	Button buttonOk;
	Button buttonClose;
	this(){
		super(Coordinate(0, 0, 225, 225), "Import bitmap"w);
		label1 = new Label("ID:"w, "label1", Coordinate(5, 22, 70, 40));
		bitmapID = new TextBox(""w, "bitmapID", Coordinate(80, 20, 220, 40));
		paletteID = new TextBox("default"w, "paletteID", Coordinate(80, 45, 220, 65));
		label2 = new Label("Palette:"w, "label2", Coordinate(5, 47, 75, 65));
		chkBPal = new CheckBox("Import palette from file"w, "chkBPal", Coordinate(5, 70, 220, 90));
		radioButtonGroup1 = new RadioButtonGroup("radioButtonGroup1"w, "radioButtonGroup1", Coordinate(5, 95, 220, 195),[ "option0"w, "option1"w], 16, 0);
		buttonOk = new Button("Ok"w, "buttonOk", Coordinate(145, 200, 220, 220));
		buttonClose = new Button("Close"w, "buttonClose", Coordinate(65, 200, 135, 220));
	}


}
