import PixelPerfectEngine.concrete.window;

import editor;

import std.conv : to;
import std.utf : toUTF8, toUTF32;
/+import dimage.base;
import dimage.tga;
import dimage.png;+/

public class NewTileLayerDialog : Window {
	Label label0;
	TextBox textBox_TS;
	Button button_TSBrowse;
	Label label1;
	Label label2;
	TextBox textBox_TX;
	TextBox textBox_TY;
	Label label3;
	Button button_MSBrowse;
	TextBox textBox_MS;
	CheckBox checkBox_embed;
	Label label4;
	Label label5;
	Label label6;
	TextBox textBox_Name;
	TextBox textBox_MX;
	TextBox textBox_MY;
	Button button_Create;
	Editor editor;
	public this(Editor editor){
		this.editor = editor;
		super(Coordinate(0, 0, 165, 244 ), "Create New Tile Layer"d);
		label0 = new Label("Tile source:"d, "label0", Coordinate(5, 22, 71, 40));
		addElement(label0);
		textBox_TS = new TextBox("none"d, "textBox_TS", Coordinate(5, 41, 160, 59));
		addElement(textBox_TS);
		button_TSBrowse = new Button("Browse"d, "button_TSBrowse", Coordinate(70, 21, 160, 39));
		button_TSBrowse.onMouseLClickRel = &button_TSBrowse_onClick;
		addElement(button_TSBrowse);
		label1 = new Label("Tile Width:"d, "label1", Coordinate(5, 62, 70, 79));
		addElement(label1);
		label2 = new Label("Tile Height:"d, "label2", Coordinate(5, 82, 70, 99));
		addElement(label2);
		textBox_TX = new TextBox("8"d, "textBox_TX", Coordinate(80, 61, 160, 79));
		addElement(textBox_TX);
		textBox_TY = new TextBox("8"d, "textBox_TY", Coordinate(80, 81, 160, 99));
		addElement(textBox_TY);
		label3 = new Label("Map source:"d, "label3", Coordinate(5, 102, 70, 118));
		addElement(label3);
		button_MSBrowse = new Button("Browse"d, "button_MSBrowse", Coordinate(70, 101, 160, 119));
		button_TSBrowse.onMouseLClickRel = &button_TSBrowse_onClick;
		addElement(button_MSBrowse);
		textBox_MS = new TextBox("none"d, "textBox_MS", Coordinate(5, 121, 160, 139));
		addElement(textBox_MS);
		checkBox_embed = new CheckBox("Embed as BASE64"d, "checkBox_embed", Coordinate(5, 142, 160, 160));
		addElement(checkBox_embed);
		label4 = new Label("Map Width:"d, "label4", Coordinate(5, 162, 70, 178));
		addElement(label4);
		label5 = new Label("Map Height:"d, "label5", Coordinate(5, 182, 70, 198));
		addElement(label5);
		textBox_MX = new TextBox("64"d, "textBox_MX", Coordinate(70, 161, 160, 179));
		addElement(textBox_MX);
		textBox_MY = new TextBox("64"d, "textBox_MY", Coordinate(70, 181, 160, 199));
		addElement(textBox_MY);
		label6 = new Label("Layer Name:", "label6", Coordinate(5, 202, 70, 218));
		addElement(label5);
		textBox_Name = new TextBox("64"d, "textBox_Name", Coordinate(70, 201, 160, 219));
		addElement(textBox_Name);
		button_Create = new Button("Create"d, "button_Create", Coordinate(70, 221, 160, 239));
		addElement(button_Create);
		button_Create.onMouseLClickRel = &button_Create_onClick;
	}
	private void button_TSBrowse_onClick(Event ev){
		parent.addWindow(new FileDialog("Import Tile Source"d, "fileDialog_TSBrowse", &fileDialog_TSBrowse_event,
				[FileDialog.FileAssociationDescriptor("All supported formats", ["*.pmp", "*.tga", "*.png"]),
					FileDialog.FileAssociationDescriptor("PPE Map file", ["*.pmp"]),
					FileDialog.FileAssociationDescriptor("TGA File", ["*.tga"]),
					FileDialog.FileAssociationDescriptor("PNG file", ["*.png"])], "./"));
	}
	private void fileDialog_TSBrowse_event(Event ev){
		textBox_TS.setText(toUTF32(ev.getFullPath));
		//Get tile data from source
	}
	private void button_MSBrowse_onClick(Event ev){
		parent.addWindow(new FileDialog("Import Map Source"d, "fileDialog_MSBrowse", &fileDialog_MSBrowse_event,
				[FileDialog.FileAssociationDescriptor("PPE Map file", ["*.pmp"]),
				FileDialog.FileAssociationDescriptor("PPE Binary Map file", ["*.map"])], "./"));
	}
	private void fileDialog_MSBrowse_event(Event ev){
		textBox_MS.setText(toUTF32(ev.getFullPath));
	}
	private void checkTextBoxInput(Event ev){
		import PixelPerfectEngine.system.etc : isInteger;
		WindowElement we = cast(WindowElement)ev.sender;
		if(!isInteger(we.getText)){
			parent.messageWindow("Input error!", "Not a numeric value!");

			we.setText("0");
		}
	}
	private void button_Create_onClick(Event ev){
		try{
			const int mX = to!int(textBox_MX.getText);
			const int mY = to!int(textBox_MY.getText);
			const int tX = to!int(textBox_TX.getText);
			const int tY = to!int(textBox_TY.getText);
			string mS;
			if(textBox_MS.getText != "" && textBox_MS.getText != "none")
				mS = toUTF8(textBox_MS.getText);
			string tS;
			if(textBox_TS.getText != "" && textBox_TS.getText != "none")
				tS = toUTF8(textBox_TS.getText);
			dstring name = textBox_Name.getText;
			editor.newTileLayer(tX, tY, mX, mY, name, mS, tS, checkBox_embed.value);
		}catch(Exception e){
			parent.messageWindow("Error!", "Cannot parse data!");
		}
		close();
	}
}
