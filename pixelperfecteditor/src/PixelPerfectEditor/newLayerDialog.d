module newLayerDialog;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;

import std.conv;

public class NewLayerDialog : Window{ 
	RadioButtonGroup radioButtonGroup1;
	Label label1;
	Label label2;
	Label label3;
	Label label4;
	TextBox tileX;
	TextBox tileY;
	TextBox mapX;
	TextBox mapY;
	Label label5;
	TextBox layerName;
	Button button_File;
	Label label6;
	TextBox fileName;
	CheckBox checkBox_ef;
	CheckBox checkBox_ed;
	Button button_Import;
	Button button_Ok;
	NewLayerDialogListener nldl;
	this(NewLayerDialogListener nldl){
		super(Coordinate(0, 0, 305, 210), "New Layer"w);
		radioButtonGroup1 = new RadioButtonGroup("Layer Type:"w, "radioButtonGroup1", Coordinate(5, 20, 150, 100),[ "SpriteLayer"w, "TileLayer"w, ], 16, 0);
		addElement(radioButtonGroup1, EventProperties.MOUSE);
		label1 = new Label("tileX:"w, "label1", Coordinate(5, 112, 79, 130));
		addElement(label1, EventProperties.MOUSE);
		label2 = new Label("tileY:"w, "label2", Coordinate(5, 137, 60, 155));
		addElement(label2, EventProperties.MOUSE);
		label3 = new Label("mapX:"w, "label3", Coordinate(5, 162, 70, 180));
		addElement(label3, EventProperties.MOUSE);
		label4 = new Label("mapY:"w, "label4", Coordinate(5, 187, 56, 205));
		addElement(label4, EventProperties.MOUSE);
		tileX = new TextBox("8"w, "tileX", Coordinate(55, 110, 150, 130));
		addElement(tileX, EventProperties.MOUSE);
		tileY = new TextBox("8"w, "tileY", Coordinate(55, 135, 150, 155));
		addElement(tileY, EventProperties.MOUSE);
		mapX = new TextBox("256"w, "mapX", Coordinate(55, 160, 150, 180));
		addElement(mapX, EventProperties.MOUSE);
		mapY = new TextBox("256"w, "mapY", Coordinate(55, 185, 150, 205));
		addElement(mapY, EventProperties.MOUSE);
		label5 = new Label("name:"w, "label5", Coordinate(155, 20, 210, 40));
		addElement(label5, EventProperties.MOUSE);
		layerName = new TextBox("textBox1"w, "layerName", Coordinate(155, 35, 300, 55));
		addElement(layerName, EventProperties.MOUSE);
		button_File = new Button("File..."w, "button_File", Coordinate(210, 60, 300, 80));
		addElement(button_File, EventProperties.MOUSE);
		button_File.onMouseLClickRel = &button_File_onMouseLClickRel;
		label6 = new Label("file:"w, "label6", Coordinate(155, 64, 203, 80));
		addElement(label6, EventProperties.MOUSE);
		fileName = new TextBox(""w, "fileName", Coordinate(155, 85, 300, 105));
		addElement(fileName, EventProperties.MOUSE);
		checkBox_ef = new CheckBox("Use exiting file"w, "checkBox_ef", Coordinate(155, 112, 300, 130));
		addElement(checkBox_ef, EventProperties.MOUSE);
		checkBox_ed = new CheckBox("Embed data"w, "checkBox_ed", Coordinate(155, 137, 300, 155));
		addElement(checkBox_ed, EventProperties.MOUSE);
		button_Import = new Button("Import symbol data"w, "button_Import", Coordinate(155, 160, 300, 180));
		addElement(button_Import, EventProperties.MOUSE);
		button_Import.onMouseLClickRel = &button_Import_onMouseLClickRel;
		button_Ok = new Button("Ok"w, "button_Ok", Coordinate(228, 185, 300, 205));
		addElement(button_Ok, EventProperties.MOUSE);
		button_Ok.onMouseLClickRel = &button_Ok_onMouseLClickRel;
		this.nldl = nldl;
	}
	/+public deprecated void actionEvent(Event event){
		switch(event.source){
			case "button_File":
				parent.addWindow(new FileDialog("Specify map file"w, "mapFile", this, [FileDialog.FileAssociationDescriptor("PPE map binary"w,["*.mbf"]),
													FileDialog.FileAssociationDescriptor("PPE extendible map file"w,["*.xmf"])], ".\\", !checkBox_ef.value));
				break;
			case "mapFile":
				fileName.setText(to!wstring(event.path ~ '\\' ~ event.filename));
				break;
			case "button_Ok":
				switch(radioButtonGroup1.value){
					case 0:
						try{
							nldl.newSpriteLayerEvent(to!string(layerName.getText));
							close();
						}catch(Exception e){
							parent.messageWindow("Error"w,to!wstring(e.message));
						}
						break;
					case 1:
						try{
							nldl.newTileLayerEvent(to!string(layerName.getText),to!string(fileName.getText),checkBox_ed.value,checkBox_ef.value,to!int(tileX.getText),
													to!int(tileY.getText),to!int(mapX.getText),to!int(mapY.getText));
							close();
						}catch(Exception e){
							parent.messageWindow("Error"w,to!wstring(e.message));
						}
						break;
					default: break;
				}
				break;
			case "button_Import":
				
				break;
			default: break;
		}
	}+/
	private void button_File_onMouseLClickRel(Event ev){
		parent.addWindow(new FileDialog("Specify map file"w, "mapFile", &onFileDialog, [FileDialog.FileAssociationDescriptor("PPE map binary"w,["*.mbf"]),
							FileDialog.FileAssociationDescriptor("PPE extendible map file"w,["*.xmf"])], ".\\", !checkBox_ef.value));
	}
	private void onFileDialog(Event ev){
		fileName.setText(to!wstring(ev.path ~ '\\' ~ ev.filename));
	}
	private void button_Ok_onMouseLClickRel(Event ev){
		switch(radioButtonGroup1.value){
			case 0:
				try{
					nldl.newSpriteLayerEvent(to!string(layerName.getText));
					close();
				}catch(Exception e){
					parent.messageWindow("Error"w,to!wstring(e.message));
				}
				break;
			case 1:
				try{
					nldl.newTileLayerEvent(to!string(layerName.getText),to!string(fileName.getText),checkBox_ed.value,checkBox_ef.value,to!int(tileX.getText),
											to!int(tileY.getText),to!int(mapX.getText),to!int(mapY.getText));
					close();
				}catch(Exception e){
					parent.messageWindow("Error"w,to!wstring(e.message));
				}
				break;
			default: break;
		}
	}
	private void button_Import_onMouseLClickRel(Event ev){
	
	}
}

public interface NewLayerDialogListener{
	public void newTileLayerEvent(string name, string file, bool embed, bool preexisting, int tX, int tY, int mX, int mY);
	public void newSpriteLayerEvent(string name);
	public void importTileLayerSymbolData(string file);
}