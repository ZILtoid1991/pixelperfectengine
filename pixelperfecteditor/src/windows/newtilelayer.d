module windows.newtilelayer;

import pixelperfectengine.concrete.window;

import editor;

import std.conv : to;
import std.utf : toUTF8, toUTF32;
import pixelperfectengine.concrete.dialogs.filedialog;

/+import dimage.base;
import dimage.tga;
import dimage.png;+/

public class NewTileLayerDialog : Window {
	//Label label0;
	//TextBox textBox_TS;
	//Button button_TSBrowse;
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
		super(Box(0, 0, 165, 203 ), "Create New Tile Layer"d);
		//label0 = new Label("Tile source:"d, "label0", Box(5, 22, 71, 40));
		//addElement(label0);
		//textBox_TS = new TextBox("none"d, "textBox_TS", Box(5, 41, 160, 59));
		//addElement(textBox_TS);
		//button_TSBrowse = new Button("Browse"d, "button_TSBrowse", Box(70, 21, 160, 39));
		//button_TSBrowse.onMouseLClickRel = &button_TSBrowse_onClick;
		//addElement(button_TSBrowse);
		label1 = new Label("Tile Width:"d, "label1", Box(5, 22, 70, 39));
		addElement(label1);
		label2 = new Label("Tile Height:"d, "label2", Box(5, 42, 70, 59));
		addElement(label2);
		textBox_TX = new TextBox("8"d, "textBox_TX", Box(80, 21, 160, 39));
		addElement(textBox_TX);
		textBox_TY = new TextBox("8"d, "textBox_TY", Box(80, 41, 160, 59));
		addElement(textBox_TY);
		label3 = new Label("Map source:"d, "label3", Box(5, 62, 70, 79));
		addElement(label3);
		button_MSBrowse = new Button("Browse"d, "button_MSBrowse", Box(70, 61, 160, 79));
		button_MSBrowse.onMouseLClick = &button_MSBrowse_onClick;
		addElement(button_MSBrowse);
		textBox_MS = new TextBox("none"d, "textBox_MS", Box(5, 81, 160, 99));
		addElement(textBox_MS);
		checkBox_embed = new CheckBox("Embed as BASE64"d, "checkBox_embed", Box(5, 102, 160, 118));
		addElement(checkBox_embed);
		label4 = new Label("Map Width:"d, "label4", Box(5, 122, 70, 138));
		addElement(label4);
		label5 = new Label("Map Height:"d, "label5", Box(5, 142, 70, 158));
		addElement(label5);
		textBox_MX = new TextBox("64"d, "textBox_MX", Box(70, 121, 160, 139));
		addElement(textBox_MX);
		textBox_MY = new TextBox("64"d, "textBox_MY", Box(70, 141, 160, 159));
		addElement(textBox_MY);
		label6 = new Label("Layer Name:", "label6", Box(5, 162, 70, 178));
		addElement(label5);
		textBox_Name = new TextBox("64"d, "textBox_Name", Box(70, 161, 160, 179));
		addElement(textBox_Name);
		button_Create = new Button("Create"d, "button_Create", Box(70, 181, 160, 199));
		addElement(button_Create);
		button_Create.onMouseLClick = &button_Create_onClick;
		textBox_MX.setFilter(TextInputFieldType.IntegerP);
		textBox_MY.setFilter(TextInputFieldType.IntegerP);
		textBox_TX.setFilter(TextInputFieldType.IntegerP);
		textBox_TY.setFilter(TextInputFieldType.IntegerP);
	}
	/+private void button_TSBrowse_onClick(Event ev){
		parent.addWindow(new FileDialog("Import Tile Source"d, "fileDialog_TSBrowse", &fileDialog_TSBrowse_event,
				[FileDialog.FileAssociationDescriptor("All supported formats", ["*.pmp", "*.tga", "*.png"]),
					FileDialog.FileAssociationDescriptor("PPE Map file", ["*.pmp"]),
					FileDialog.FileAssociationDescriptor("TGA File", ["*.tga"]),
					FileDialog.FileAssociationDescriptor("PNG file", ["*.png"])], "./"));
	}+/
	/+private void fileDialog_TSBrowse_event(Event ev){
		textBox_TS.setText(toUTF32(ev.getFullPath));
		//Get tile data from source
	}+/
	private void button_MSBrowse_onClick(Event ev){
		handler.addWindow(new FileDialog("Import Map Source"d, "fileDialog_MSBrowse", &fileDialog_MSBrowse_event,
				[FileDialog.FileAssociationDescriptor("Extendible Map file", ["*.xmp"]),
				FileDialog.FileAssociationDescriptor("PPE Binary Map file", ["*.map"])], "./"));
	}
	private void fileDialog_MSBrowse_event(Event ev){
		FileEvent fev = cast(FileEvent)ev;
		textBox_MS.setText(toUTF32(fev.getFullPath));
	}
	private void button_Create_onClick(Event ev){
		try{
			const int mX = to!int(textBox_MX.getText.text);
			const int mY = to!int(textBox_MY.getText.text);
			const int tX = to!int(textBox_TX.getText.text);
			const int tY = to!int(textBox_TY.getText.text);
			string mS;
			if(textBox_MS.getText.text != "" && textBox_MS.getText.text != "none")
				mS = toUTF8(textBox_MS.getText.text);
			//string tS;
			/+if(textBox_TS.getText.text != "" && textBox_TS.getText.text != "none")
				tS = toUTF8(textBox_TS.getText.text);+/
			dstring name = textBox_Name.getText.text;
			editor.newTileLayer(tX, tY, mX, mY, name, mS, checkBox_embed.isChecked);
		}catch(Exception e){
			handler.message("Error!", "Cannot parse data!");
		}
		close();
	}
}
