class NewWindow : Window { 
	Label label1;
	TextBox bitmapID;
	TextBox paletteID;
	Label label2;
	CheckBox chkBPal;
	RadioButtonGroup radioButtonGroup1;
	Button buttonOk;
	Button buttonClose;
	Label label3;
	Label label4;
	TextBox textBoxX;
	TextBox textBoxY;
	this(){
		super(Coordinate(0, 0, 225, 270), "Import bitmap"w);
		label1 = new Label("ID:"w, "label1", Coordinate(5, 22, 70, 40));
		bitmapID = new TextBox(""w, "bitmapID", Coordinate(80, 20, 220, 40));
		paletteID = new TextBox("default"w, "paletteID", Coordinate(80, 45, 220, 65));
		label2 = new Label("Palette:"w, "label2", Coordinate(5, 47, 75, 65));
		chkBPal = new CheckBox("Import palette from file"w, "chkBPal", Coordinate(5, 70, 220, 90));
		radioButtonGroup1 = new RadioButtonGroup("Bitdepth"w, "radioButtonGroup1", Coordinate(5, 140, 220, 240),[ "option0"w, "option1"w, ], 16, 0);
		buttonOk = new Button("Ok"w, "buttonOk", Coordinate(145, 245, 220, 265));
		buttonClose = new Button("Close"w, "buttonClose", Coordinate(65, 245, 135, 265));
		label3 = new Label("sizeX:"w, "label3", Coordinate(5, 92, 74, 110));
		label4 = new Label("sizeY:"w, "label4", Coordinate(5, 117, 73, 135));
		textBoxX = new TextBox(""w, "textBox3", Coordinate(80, 90, 220, 110));
		textBoxY = new TextBox(""w, "textBox4", Coordinate(80, 115, 220, 135));
	}
}