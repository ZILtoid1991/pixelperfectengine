module converterdialog;

import std.conv;
import std.stdio;

import windowing.window;
import windowing.elements;

import map.mapload;

import system.etc;
import system.inputHandler;

import graphics.bitmap;
import graphics.layers;

import extbmp.extbmp;

import converter;
/**
 *Creates a window for converting external bitmaps for the engine's native format 
 */
public class ConverterDialog : Window, ActionListener{
	private ListBox imageList, fileList, animationList, frameList;
	private string[] filenames;
	private string importFileName,animationSelection;
	private Label[string] labels;
	private InputHandler inputHandler;
	public ExtendibleBitmap[] files;
	private ISpriteLayer32Bit viewer;
	private Bitmap32Bit preview;
	private int imageSelection, frameSelection;

	private bool previewModeOn;
	ExtendibleBitmap selection;
	public this(InputHandler inputhandler, MapHandler mh = null, ExtendibleBitmap[] documentFiles = null){
		this(Coordinate(0,0,640,480), "XMP Converter Toolkit");
		this.inputHandler = inputhandler;
		files = documentFiles;
		Button [] buttons;
		if(mh !is null){
			filenames = mh.getAllFilenames();
			//fileList = new ListBox("fileList",Coordinate(4,20,204,101), [ListBoxColumn("Filename",filenames)], [256], 15);
		}else{
			labels["0x00"] = new Label("Path:", "", Coordinate(4,20,204,40));
			labels["path"] = new Label("n/a", "path", Coordinate(4,40,204,60));
		}
		buttons ~= new Button("New File","newfile", Coordinate(210,20,294,39));
		buttons ~= new Button("Load File","loadfile", Coordinate(210,40,294,59));
		buttons ~= new Button("Save File","savefile", Coordinate(210,60,294,79));
		buttons ~= new Button("Rem File","removefile", Coordinate(210,60,294,79));
		imageList = new ListBox("imageList",Coordinate(4,104,204,304),[ListBoxColumn("BitmapID",[""]),ListBoxColumn("Bitdepth",[""]),ListBoxColumn("Format",[""]),ListBoxColumn("PalMode",[""])], [128,64,64,80], 15);
		buttons ~= new Button("Import New","inportnew", Coordinate(210,110,294,129));
		buttons ~= new Button("Imp Multi","inportmultiple", Coordinate(210,130,294,149));
		buttons ~= new Button("Export As","exportas", Coordinate(210,150,294,169));
		buttons ~= new Button("Remove","remove", Coordinate(210,170,294,189));
		buttons ~= new Button("Preview","preview", Coordinate(210,190,294,209));
		animationList = new ListBox("animationList", Coordinate(300,20,500,120),[ListBoxColumn("AnimID",[""]),ListBoxColumn("Frames",[""])], [128,80], 15);
		buttons ~= new Button("New Anim","newAnim", Coordinate(506,20,590,39));
		buttons ~= new Button("Edit","animProp", Coordinate(506,40,590,59));
		//buttons ~= new Button("Save File","savefile", Coordinate(506,60,590,79));
		buttons ~= new Button("Rem Anim","removeAnim", Coordinate(506,60,590,79));
		frameList = new ListBox("frameList", Coordinate(300,122,500,304),[ListBoxColumn("Num",[""]),ListBoxColumn("ImageID",[""]),ListBoxColumn("Dur",[""])],[40,128,64], 15);
		buttons ~= new Button("Add Frame","addFrame", Coordinate(506,130,590,149));
		buttons ~= new Button("Edit","editFr", Coordinate(506,150,590,169));
		buttons ~= new Button("Remove","removeFr", Coordinate(506,170,590,189));

		foreach(Button e; buttons){
			addElement(e, EventProperties.MOUSE);
			e.al ~= this;
		}
		foreach(WindowElement e; labels){
			addElement(e, EventProperties.MOUSE);
		}
		addElement(imageList, EventProperties.MOUSE);
		addElement(animationList, EventProperties.MOUSE);
		addElement(frameList, EventProperties.MOUSE);
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){
		/*switch(source){
			case "fileList":
				selection = files[value];
				//imageList.updateColumns([ListBoxColumn("BitmapID",selection.bitmapID),ListBoxColumn("Bitdepth",selection.bitdepth),ListBoxColumn("Format",selection.format),ListBoxColumn("PalMode",selection.paletteMode)]);
				break;
			case "newfile":
				// create new filedialog to save the new file to the given location
				FileDialog fileDialog = new FileDialog("Create new XMP file", "xmpfiledialog", this, [".xmp"], null, inputHandler, true);
				break;
			case "xmpfiledialog":
				ExtendibleBitmap newFile = new ExtendibleBitmap();
				string fileName = to!string(message);
				newFile.saveFile(fileName);
				fileList ~= newFile;
				filenames ~= fileName;
				break;
			default: break;
		}*/
	}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		//writeln(event.path);
		switch(event.subsource){
			case "filedialog":
				switch(event.source){
					case "xmpfiledialog":
						ExtendibleBitmap newFile = new ExtendibleBitmap();
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						newFile.saveFile(fileName);
						if(files is null){
							selection = newFile;
							labels["path"].setText(to!wstring(fileName));
						}else{
							files ~= newFile;
							filenames ~= fileName;
							selection = newFile;
						}

						break;
					case "xmpLoad":
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						newFile.saveFile(fileName);
						if(files is null){
							selection = newFile;
							labels["path"].setText(to!wstring(fileName));
						}else{
							files ~= newFile;
							filenames ~= fileName;
							selection = newFile;
						}
						break;
					case "importfile":
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						//Bitmap32Bit bmp = importBitmapFromFile(fileName);
						ImportDialog id = new ImportDialog(inputHandler);
						parent.addWindow(id);
						break;
					default: break;
				}
				break;
			case "impDial":
				switch(event.value){
					case 0:
						Bitmap32Bit bmp = importBitmapFromFile(importFileName);
						selection.addBitmap(cast(void[])bmp.getRawdata(),bmp.getX,bmp.getY,"32bit",to!string(event.text),"ARGB");
						break;
					default: break;
				}
				break;
			default:
				switch(event.source){
					case "newfile":
						// create new filedialog to save the new file to the given location
						FileDialog fileDialog = new FileDialog("Create new XMP file", "xmpfiledialog", this, ["*.xmp"], ".\\", inputHandler, true);
						parent.addWindow(fileDialog);
						break;
					case "loadfile":
						FileDialog fileDialog = new FileDialog("Load XMP file", "xmpload", this, ["*.xmp"], ".\\", inputHandler, false);
						parent.addWindow(fileDialog);
						break;
					case "preview":
						if(previewModeOn){
							previewModeOn = false;
							viewer.removeSprite(0);
						}else{
							previewModeOn = true;
							//set sprite for preview mode

							viewer.addSprite(preview, 0, 0, 0);
						}
						break;
					case "inportnew":
						FileDialog fileDialog = new FileDialog("Import PNG/TGA/BMP", "importfile", this, null, ".\\", inputHandler);
						parent.addWindow(fileDialog);
						break;
					case "imageList":
						if(!selection.isEmpty){
							imageSelection = event.value;
							//update image information
						}
						break;
					default: break;
				}
				break;
		}
	}
	private void updateFileList(){

	}
	private void updateImageList(){
		wstring[] IDs = stringArrayConv(selection.getIDs());
		wstring[] bt = stringArrayConv(selection.bitdepth), form = stringArrayConv(selection.format), pm = stringArrayConv(selection.paletteMode);

		imageList.updateColumns([ListBoxColumn("BitmapID",[IDs]),ListBoxColumn("Bitdepth",[bt]),ListBoxColumn("Format",[form]),ListBoxColumn("PalMode",[pm])]);
	}
	private void updateAnimationList(){
		wstring[] IDs, frames;
		foreach(s; selection.animData.byKey){
			IDs ~= to!wstring(s);
			frames ~= to!wstring(selection.animData[s].ID.length);
		}
		animationList.updateColumns([ListBoxColumn("AnimID",[IDs]),ListBoxColumn("Frames",[frames])]);
	}
	private void updateFrameList(){
		wstring[] num, IDs, dur;
		for(int i ; i < selection.animData[selection].ID.length ; i++){
			num ~= to!wstring(i);
			ID ~= to!wstring(selection.animData[selection].ID[i]);
			dur ~= to!wstring(selection.animData[selection].duration[i]);
		}
		[ListBoxColumn("Num",[""]),ListBoxColumn("ImageID",[""]),ListBoxColumn("Dur",[""])];
	}
	private void createNewFile(){

	}
	private void loadFile(){

	}
	private void saveFile(){

	}
	private void removeFile(){

	}
	private void importNewImage(){

	}
	private void importMultiImage(){

	}
	private void exportAs(){

	}
	private void removeFromFile(){

	}
}

public class SpriteSheetDialog : Window, ActionListener{
	private InputHandler inputHandler;
	/*public this(InputHandler inputhandler){

	}*/

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){}
}

public class ImportDialog : Window, ActionListener{
	private TextBox name;
	private RadioButtonGroup convertionMode;
	public ActionListener[] al;
	public this(InputHandler inputhandler){
		this(Coordinate(0,0,220,200), "Import settings");
		addElement(new Label("ID:","0000",Coordinate(10,20,80,40)), EventProperties.MOUSE);
		name = new TextBox("","name", Coordinate(100,20,210,40));
		name.addTextInputHandler(inputhandler);
		convertionMode = new RadioButtonGroup("Convertion Mode:","cmode",Coordinate(20,50,200,150),["None","Nearest value","Add value to palette"],16,0);
		addElement(new Button("Ok","ok",Coordinate()), EventProperties.MOUSE);
		addElement(new Button("Cancel","cancel",Coordinate()), EventProperties.MOUSE);
		addElement(name, EventProperties.MOUSE);
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		switch(event.source){
			case "ok": 
				foreach(a; al){
					a.actionEvent(new Event("impDial","impDial","","",name.getText,convertionMode.getValue,-3));

				}
				parent.closeWindow(this);
				break;
			case "cancel": parent.closeWindow(this); break;
			default: break;
		}
	}
}