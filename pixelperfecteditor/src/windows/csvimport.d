module windows.csvimport;

import pixelperfectengine.concrete.window; 

import csvconv;

public class CSVImportWindow : Window {
	Label label_width;
	Label label_height;
	TextBox textBox_width;
	TextBox textBox_height;
	Button button_import;
	string filename;
	public this (string filename) {
		super(Box(0, 0, 155, 80), "Import Tiled CSV Map");
		label_width = new Label("Width:"d, "label0", Box(5, 20, 90, 40));
		label_height = new Label("Height:"d, "label0", Box(5, 40, 90, 60));
		textBox_width = new TextBox(""d, "textBox0", Box(90, 20, 150, 38));
		textBox_width.allowedChars = TextBox.INTEGER_POS;
		textBox_height = new TextBox(""d, "textBox0", Box(90, 40, 150, 58));
		textBox_height.allowedChars = TextBox.INTEGER_POS;
		button_import = new Button("Import"d, "button0", Box(90, 60, 150, 78));
		this.filename = filename;
	}
	private void button_import_onClick(Event ev) {
		
	}
}
