module addTiles;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.extbmp.extbmp;
import PixelPerfectEngine.map.mapload;
import PixelPerfectEngine.graphics.layers;
import PixelPerfectEngine.graphics.paletteMan;

public class LayerTypeException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}

public class AddTiles : Window{
	public enum AcceptedBMPType{
		ALL,
		Indexed4Bit,
		Indexed8Bit,
		Indexed16Bit,
		DirectColor32Bit,
	}
	private struct AddedBitmaps{
		wchar ID;
		string name;
		string type;
		string srcID;
		string palette;
	}
	private AddedBitmaps[] abList;
	ListBox listBox_Added;
	ListBox listBox_Available;
	Button button_Add;
	Button button_Remove;
	Button button_Finish;
	Button button_ABI;
	Label label1;
	Label label2;
	Label label3;
	TextBox textBox_Name;
	TextBox textBox_ID;
	Label label4;
	ExtendibleBitmap source;
	ExtendibleMap document;
	AcceptedBMPType acceptedTypes;
	int x, y, layerNum;
	ITileLayer target;
	PaletteManager palman;

	this(ExtendibleBitmap source, ExtendibleMap document, AcceptedBMPType acceptedTypes, int x, int y, int layerNum, ITileLayer target, PaletteManager palman){
		super(Coordinate(0, 0, 485, 340), "Add tiles"d);
		this.palman = palman;
		this.target = target;
		this.source = source;
		this.document = document;
		this.acceptedTypes = acceptedTypes;
		this.x = x;
		this.y = y;
		listBox_Added = new ListBox("listBox_Added",Coordinate(5, 20, 245, 225), null, new ListBoxHeader(["ID"d, "Name"d, "Type"d, "SrcID"d, "Pal"d], [32, 128, 48, 200, 80]), 16);
		addElement(listBox_Added, EventProperties.MOUSE);
		listBox_Available = new ListBox("listBox_Available",Coordinate(250, 20, 480, 225), null, new ListBoxHeader(["ID"d, "Type"d], [200, 48]), 16);
		addElement(listBox_Available, EventProperties.MOUSE);
		button_Add = new Button("Add"d, "button_Add", Coordinate(335, 230, 405, 250));
		addElement(button_Add, EventProperties.MOUSE);
		button_Add.onMouseLClickRel = &button_Add_mouseClick;
		button_Remove = new Button("Remove"d, "button_Remove", Coordinate(410, 230, 480, 250));
		addElement(button_Remove, EventProperties.MOUSE);
		button_Remove.onMouseLClickRel = &button_Remove_mouseClick;
		button_Finish = new Button("Finish"d, "button_Finish", Coordinate(410, 255, 480, 275));
		addElement(button_Finish, EventProperties.MOUSE);
		button_Finish.onMouseLClickRel = &button_Finish_mouseClick;
		button_ABI = new Button("Add by intrinsic"d, "button_ABI", Coordinate(250, 255, 405, 275));
		addElement(button_ABI, EventProperties.MOUSE);
		button_ABI.onMouseLClickRel = &button_ABI_mouseClick;
		label1 = new Label("Name:"d, "label1", Coordinate(5, 232, 66, 248));
		addElement(label1, EventProperties.MOUSE);
		label2 = new Label("ID:"d, "label2", Coordinate(5, 257, 68, 273));
		addElement(label2, EventProperties.MOUSE);
		label3 = new Label("Intrinsic: foretag####aftertag"d, "label3", Coordinate(5, 282, 400, 300));
		addElement(label3, EventProperties.MOUSE);
		textBox_Name = new TextBox("NULL"d, "textBox_Name", Coordinate(55, 230, 330, 250));
		addElement(textBox_Name, EventProperties.MOUSE);
		textBox_ID = new TextBox("0x0000"d, "textBox_ID", Coordinate(55, 255, 150, 275));
		addElement(textBox_ID, EventProperties.MOUSE);
		label4 = new Label("Start with \"[h]\" to use hex numbering system."d, "label4", Coordinate(5, 307, 479, 323));
		addElement(label4, EventProperties.MOUSE);
		getAvailableBitmaps;
	}

	private void button_Remove_mouseClick(Event e){
		import std.algorithm;
		abList.remove(e.value);
		listBox_Added.removeLine(e.value);
	}
	private void button_Add_mouseClick(Event e){
		import std.conv;
		foreach(x; abList){
			if(x.srcID == to!string(listBox_Available.readLine(listBox_Available.selection).getText(0))){
				return;
			}
		}
		AddedBitmaps ab;
		// parse ID
		try{
			int x = to!int(textBox_ID.getText);
			ab.ID = to!wchar(x);
		}catch(Exception e){

		}
		// get name
		try{
			ab.name = to!string(textBox_Name.getText);
		}catch(Exception e){

		}
		ab.srcID = to!string(listBox_Available.readLine(listBox_Available.selection).getText(0));
		ab.palette = source.getPaletteMode(ab.name);
		abList ~= ab;
		listBox_Added.addLine(new ListBoxItem([textBox_ID.getText, to!dstring(ab.name), to!dstring(ab.type), to!dstring(ab.srcID)]));
	}
	private void button_Finish_mouseClick(Event e){
		foreach(a; abList){
			document.addTileToTileSource(layerNum, a.ID, a.name, a.srcID, source.dir);
		}
		if(target.classinfo == typeid(TileLayer)){
			TileLayer t = cast(TileLayer)target;
			foreach(a; abList){
				ABitmap b;
				switch(a.type){
					case "4bit":
						b = new Bitmap4Bit(cast(ubyte[])source.getBitmap(a.srcID),x,y,palman.addPalette(source.dir~":"~a.palette,cast(Color[])source.getPalette(a.palette)));
						break;
					case "8bit":
						b = new Bitmap8Bit(source.get8bitBitmap(a.srcID),x,y,palman.addPalette(source.dir~":"~a.palette,cast(Color[])source.getPalette(a.palette)));
						break;
					case "16bit":
						b = new Bitmap16Bit(source.get16bitBitmap(a.srcID),x,y);
						break;
					case "32bit":
						b = new Bitmap32Bit(cast(Color[])(source.getBitmap(a.srcID)),x,y);
						break;
					default:
						break;
				}
				t.addTile(b,a.ID);
			}
		}else if(target.classinfo == typeid(TransformableTileLayer!Bitmap8Bit)){

		}else if(target.classinfo == typeid(TransformableTileLayer!Bitmap16Bit)){

		}else if(target.classinfo == typeid(TransformableTileLayer!Bitmap32Bit)){

		}

		close;
	}
	private void button_ABI_mouseClick(Event e){

	}
	private bool parseIntrinsic(wstring s){
		string foretag, aftertag;
		int numfieldStart = -1, numfieldEnd = -1;
		bool hex, numfieldParsed;
		if(s.length > 3){
			int i;
			if(s[0..3] == "[h]"){
				hex = true;
				i = 3;
			}
			for( ; i < s.length ; i++){
				if(s[i] == '#'){
					if(numfieldStart == -1){
						numfieldStart = i;
					}
					numfieldEnd = i;
					if(numfieldParsed){
						return false;
					}
				}else{
					if(numfieldParsed){
						aftertag ~= s[i];
					}else{
						if(numfieldEnd != -1){
							aftertag ~= s[i];
							numfieldParsed = true;
						}else{
							foretag ~= s[i];
						}
					}
				}
			}
		}
		return true;
	}
	private void getAvailableBitmaps(){
		import std.conv;
		ListBoxItem[] items;
		for(int i ; i > source.bitmapID.length ; i++){
			switch(acceptedTypes){
				case AcceptedBMPType.Indexed4Bit:
					if(x == source.getXsize(i) && y == source.getYsize(i) && source.bitdepth[i] == "4bit"){
						items ~= new ListBoxItem([to!dstring(source.bitmapID[i]), to!dstring(source.bitdepth[i])]);
					}
					break;
				case AcceptedBMPType.Indexed8Bit:
					if(x == source.getXsize(i) && y == source.getYsize(i) && source.bitdepth[i] == "8bit"){
						items ~= new ListBoxItem([to!dstring(source.bitmapID[i]), to!dstring(source.bitdepth[i])]);
					}
					break;
				case AcceptedBMPType.Indexed16Bit:
					if(x == source.getXsize(i) && y == source.getYsize(i) && source.bitdepth[i] == "16bit"){
						items ~= new ListBoxItem([to!dstring(source.bitmapID[i]), to!dstring(source.bitdepth[i])]);
					}
					break;
				case AcceptedBMPType.DirectColor32Bit:
					if(x == source.getXsize(i) && y == source.getYsize(i) && source.bitdepth[i] == "32bit"){
						items ~= new ListBoxItem([to!dstring(source.bitmapID[i]), to!dstring(source.bitdepth[i])]);
					}
					break;
				default:
					if(x == source.getXsize(i) && y == source.getYsize(i)){
						items ~= new ListBoxItem([to!dstring(source.bitmapID[i]), to!dstring(source.bitdepth[i])]);
					}
					break;
			}
		}
		listBox_Available.updateColumns(items);
	}
}
