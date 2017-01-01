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
public class ConverterDialog : Window, ActionListener, SheetDialogListener{
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
	public this(InputHandler inputhandler, ISpriteLayer32Bit viewer, ExtendibleMap mh = null, ExtendibleBitmap[] documentFiles = null){
		this(Coordinate(0,0,640,480), "XMP Converter Toolkit");
		this.inputHandler = inputhandler;
		this.viewer = viewer;
		files = documentFiles;
		Button [] buttons;
		if(mh !is null){
			//filenames = mh.getAllFilenames();
			//fileList = new ListBox("fileList",Coordinate(4,20,204,101), [ListBoxColumn("Filename",filenames)], [256], 15);
		}else{
			labels["0x00"] = new Label("Path:", "", Coordinate(4,20,204,40));
			labels["path"] = new Label("n/a", "path", Coordinate(4,40,204,60));
		}
		buttons ~= new Button("New File","newfile", Coordinate(210,20,294,39));
		buttons ~= new Button("Load File","loadfile", Coordinate(210,40,294,59));
		buttons ~= new Button("Save File","savefile", Coordinate(210,60,294,79));
		//buttons ~= new Button("Rem File","removefile", Coordinate(210,60,294,79));
		imageList = new ListBox("imageList",Coordinate(4,104,204,304),[ListBoxColumn("BitmapID",[""]),ListBoxColumn("Bitdepth",[""]),ListBoxColumn("Format",[""]),ListBoxColumn("PalMode",[""])], [128,64,64,80], 15);
		buttons ~= new Button("Import New","inportnew", Coordinate(210,110,294,129));
		buttons ~= new Button("Imp Multi","inportmultiple", Coordinate(210,130,294,149));
		buttons ~= new Button("Export As","exportas", Coordinate(210,150,294,169));
		buttons ~= new Button("Remove","remove", Coordinate(210,170,294,189));
		buttons ~= new Button("Preview","preview", Coordinate(210,190,294,209));
		buttons ~= new Button("Imp Pal","paletteImport", Coordinate(210,210,294,229));
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
		imageList.al ~= this;
		addElement(animationList, EventProperties.MOUSE);
		addElement(frameList, EventProperties.MOUSE);
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		//writeln(event.subsource);
		//writeln(event.source);
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
					case "xmpload":
						string fileName = event.path ;
						writeln(fileName);
						fileName ~= '\\';
						writeln(fileName);
						fileName ~= event.filename;
						writeln(fileName);
						ExtendibleBitmap newFile = new ExtendibleBitmap(fileName);
						if(files is null){
							selection = newFile;
							labels["path"].setText(to!wstring(fileName));
						}else{
							files ~= newFile;
							filenames ~= fileName;
							selection = newFile;
						}
						updateImageList();
						break;
					case "importfile":
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						//Bitmap32Bit bmp = importBitmapFromFile(fileName);
						ImportDialog id = new ImportDialog(inputHandler);
						id.al ~= this;
						parent.addWindow(id);
						break;
					case "importmulti": 
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						SpriteSheetDialog sd = new SpriteSheetDialog(this);
						parent.addWindow(sd);
						break;
					case "palettefile":
						string fileName = event.path ;
						fileName ~= '\\';
						fileName ~= event.filename;
						importFileName = fileName;
						TextInputDialog tid = new TextInputDialog(Coordinate(0,0,200,90),"palName","Import Palette","Palette ID:");
						tid.al ~= this;
						parent.addWindow(tid);
						break;
					default: break;
				}
				break;
			case "impDial":
				
				try{
					/*Bitmap32Bit bmp = import32BitBitmapFromFile(importFileName);
					 selection.addBitmap(cast(void[])bmp.getRawdata(),bmp.getX,bmp.getY,"32bit",to!string(event.text),"ARGB");
					 updateImageList();
					 previewModeOn = true;
					 //set sprite for preview mode
					 //writeln(preview);
					 viewer.addSprite(bmp, 0, 0, 0);*/
					string bitdepth;
					switch(event.value){
						case 0: bitdepth = "8bit"; break;
						case 1: bitdepth = "16bit"; break;
						case 2: bitdepth = "32bit"; break;
						default: bitdepth = "1bit"; break;
					}
					importDirectlyToXMP(importFileName,selection,new ImportData([to!string(event.text)],bitdepth,0,0,0));

					}catch(Exception e){
						writeln(e);
					}
				break;
			case "TextInputDialog":
				switch(event.source){
					case "palName": 
						importPaletteDirectlyToXMP(importFileName,selection,to!string(event.text));
						break;
					default: break;
				}
				break;
			default:
				switch(event.source){
					case "newfile":
						// create new filedialog to save the new file to the given location
						FileDialog fileDialog = new FileDialog("Create new XMP file", "xmpfiledialog", this, ["*.xmp"], ".\\", true);
						parent.addWindow(fileDialog);
						break;
					case "loadfile":
						FileDialog fileDialog = new FileDialog("Load XMP file", "xmpload", this, ["*.xmp"], ".\\", false);
						parent.addWindow(fileDialog);
						break;
					case "savefile":
						selection.saveFile();
						break;
					case "preview":
						if(previewModeOn){
							previewModeOn = false;
							viewer.removeSprite(0);
						}else{
							previewModeOn = true;
							//set sprite for preview mode
							//writeln(preview);
							viewer.addSprite(preview, 0, 0, 0);
						}
						break;
					case "inportnew":
						FileDialog fileDialog = new FileDialog("Import PNG/TGA/BMP", "importfile", this, ["*.png","*.tga","*.bmp"], ".\\");
						parent.addWindow(fileDialog);
						break;
					case "inportmultiple":
						//parent.addWindow(new SpriteSheetDialog());
						FileDialog fileDialog = new FileDialog("Import PNG/TGA/BMP", "importmulti", this, ["*.png","*.tga","*.bmp"], ".\\");
						parent.addWindow(fileDialog);
						break;
					case "imageList":
						//if(!selection.isEmpty){
							imageSelection = event.value;
							//update image information
							//preview = new Bitmap32Bit(selection.getBitmap(imageSelection),selection.getXsize(imageSelection),selection.getYsize(imageSelection));
							//writeln(preview);
						preview = getBitmapPreview(selection,selection.bitmapID[imageSelection]);
						writeln(preview);
						//}
						break;
					case "paletteImport":
						FileDialog fileDialog = new FileDialog("Import Palette", "palettefile", this, ["*.png","*.tga","*.bmp"], ".\\");
						parent.addWindow(fileDialog);
						break;
					default: break;
				}
				break;
		}
	}
	public void SheetDialogEvent(string a, string b, int numFrom, int numOfDigits, int x, int y, int bitdepth, NumberingStyle ns){
		string bd;
		switch(bitdepth){
			case 0: bd="8bit"; break;
			case 1: bd="16bit"; break;
			case 2: bd="32bit"; break;
			default: bd="1bit"; break;
		}
		importDirectlyToXMP(importFileName,selection,new ImportData(new NamingConvention(a,b,ns,numFrom,numOfDigits),bd,x,y,0));
	}

	private void updateFileList(){

	}
	private void updateImageList(){
		wstring[] IDs = stringArrayConv(selection.getIDs());
		wstring[] bt = stringArrayConv(selection.bitdepth), form = stringArrayConv(selection.format), pm = stringArrayConv(selection.paletteMode);

		imageList.updateColumns([ListBoxColumn("BitmapID",IDs),ListBoxColumn("Bitdepth",bt),ListBoxColumn("Format",form),ListBoxColumn("PalMode",pm)]);
	}
	private void updateAnimationList(){
		wstring[] IDs, frames;
		foreach(s; selection.animData.byKey){
			IDs ~= to!wstring(s);
			frames ~= to!wstring(selection.animData[s].ID.length);
		}
		animationList.updateColumns([ListBoxColumn("AnimID",IDs),ListBoxColumn("Frames",frames)]);
	}
	private void updateFrameList(){
		/*wstring[] num, IDs, dur;
		for(int i ; i < selection.animData[selection].bitmapID.length ; i++){
			num ~= to!wstring(i);
			ID ~= to!wstring(selection.animData[selection].bitmapID[i]);
			dur ~= to!wstring(selection.animData[selection].duration[i]);
		}
		[ListBoxColumn("Num",[""]),ListBoxColumn("ImageID",[""]),ListBoxColumn("Dur",[""])];*/
	}

}

interface SheetDialogListener{
	public void SheetDialogEvent(string a, string b, int numFrom, int numOfDigits, int x, int y, int bitdepth, NumberingStyle ns);
}

public class SpriteSheetDialog : Window, ActionListener{
	private TextBox nameA, nameB, numFrom, gridX, gridY, nOfZeros;
	private RadioButtonGroup numberingConvention, bitDepthSetter;
	//private InputHandler inputHandler;
	public SheetDialogListener sdl;
	public this(SheetDialogListener sdl){
		this.sdl = sdl;
		this(Coordinate(0,0,230,340),"Sheet import settings");
		nameA = new TextBox("","nameA",Coordinate(120,20,220,40));
		addElement(nameA,EventProperties.MOUSE);
		addElement(new Label("NameA:","reversed",Coordinate(10,20,120,40)),EventProperties.MOUSE);

		nameB = new TextBox("","nameB",Coordinate(120,50,220,70));
		addElement(nameB,EventProperties.MOUSE);
		addElement(new Label("NameB:","reversed",Coordinate(10,50,120,70)),EventProperties.MOUSE);

		numFrom = new TextBox("","numFrom",Coordinate(120,80,220,100));
		addElement(numFrom,EventProperties.MOUSE);
		addElement(new Label("NumFrom:","reversed",Coordinate(10,80,120,100)),EventProperties.MOUSE);

		gridX = new TextBox("","gridX",Coordinate(120,110,220,130));
		addElement(gridX,EventProperties.MOUSE);
		addElement(new Label("gridX:","reversed",Coordinate(10,110,120,130)),EventProperties.MOUSE);

		gridY = new TextBox("","gridY",Coordinate(120,140,220,160));
		addElement(gridY,EventProperties.MOUSE);
		addElement(new Label("gridY:","reversed",Coordinate(10,140,120,160)),EventProperties.MOUSE);

		nOfZeros = new TextBox("","nOfZeros",Coordinate(120,170,220,190));
		addElement(nOfZeros,EventProperties.MOUSE);
		addElement(new Label("NumOfZeros:","reversed",Coordinate(10,170,120,190)),EventProperties.MOUSE);

		bitDepthSetter = new RadioButtonGroup("Bitdepth:","cmode",Coordinate(10,210,110,310),["8Bit","16Bit","32Bit","1Bit"],16,0);
		addElement(bitDepthSetter,EventProperties.MOUSE);
		numberingConvention = new RadioButtonGroup("numConv:","numConv",Coordinate(120,210,220,310),["Dec","Oct","Hex"],16,0);
		addElement(numberingConvention,EventProperties.MOUSE);
		Button ok = new Button("Ok","ok",Coordinate(160,315,220,335));
		addElement(ok,EventProperties.MOUSE);
		ok.al~=this;
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		if(event.source == "ok"){
			NumberingStyle ns;
			switch(numberingConvention.getValue){
				case 0: ns = NumberingStyle.DECIMAL; break;
				case 1: ns = NumberingStyle.OCTAL; break;
				case 2: ns = NumberingStyle.HEXADECIMAL; break;
				default: break;
			}
			sdl.SheetDialogEvent(to!string(nameA.getText),to!string(nameB.getText),to!int(numFrom.getText),to!int(nOfZeros.getText),to!int(gridX.getText),to!int(gridY.getText),bitDepthSetter.getValue,ns);
			parent.closeWindow(this);
		}
	}
}

public class ImportDialog : Window, ActionListener{
	private TextBox name;
	private RadioButtonGroup bitdepthSetter;
	public ActionListener[] al;
	public this(InputHandler inputhandler){
		this(Coordinate(0,0,220,200), "Import settings");
		addElement(new Label("ID:","0000",Coordinate(10,20,80,40)), EventProperties.MOUSE);
		name = new TextBox("","name", Coordinate(100,20,210,40));
		//name.addTextInputHandler(inputhandler);
		bitdepthSetter = new RadioButtonGroup("Bitdepth:","cmode",Coordinate(20,50,200,150),["8Bit","16Bit","32Bit","1Bit"],16,0);
		Button b1 = new Button("Ok","ok",Coordinate(80,160,140,180));
		addElement(b1, EventProperties.MOUSE);
		b1.al ~= this;
		Button b2 = new Button("Cancel","cancel",Coordinate(150,160,210,180));
		addElement(b2, EventProperties.MOUSE);
		b2.al ~= this;
		addElement(bitdepthSetter, EventProperties.MOUSE);
		addElement(name, EventProperties.MOUSE);
	}

	public this(Coordinate size, wstring title){
		super(size, title);
	}
	public void actionEvent(string source, int type, int value, wstring message){}
	public void actionEvent(string source, string subSource, int type, int value, wstring message){}
	public void actionEvent(Event event){
		//writeln(event.source);
		switch(event.source){
			case "ok": 
				foreach(a; al){
					a.actionEvent(new Event("impDial","impDial","","",name.getText,bitdepthSetter.getValue,-3));

				}
				parent.closeWindow(this);
				break;
			case "cancel": parent.closeWindow(this); break;
			default: break;
		}
	}
}

