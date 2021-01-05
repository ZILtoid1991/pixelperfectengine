module PixelPerfectEngine.concrete.dialogs.filedialog;

public import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.concrete.elements;
import std.datetime;
import std.conv : to;
import std.file;

/**
 * File dialog window for opening files.
 * Returns the selected filetype as an int value of the position of the types that were handled to the ctor.
 */
public class FileDialog : Window {
	/**
	 * Defines file association descriptions
	 */
	public struct FileAssociationDescriptor {
		public dstring description;		/// Describes the file type. Eg. "PPE map files"
		public string[] types;			/// The extensions associated with a given file format. Eg. ["*.htm","*.html"]. First is preferred one at saving, if no filetype is described when typing.
		/**
		 * Creates a single FileAssociationDescriptor
		 */
		public this(dstring description, string[] types){
			this.description = description;
			this.types = types;
		}
		/**
		 * Returns the types as a single string.
		 */
		public dstring getTypesForSelector(){
			dstring result;
			foreach(string s ; types){
				result ~= to!dstring(s);
				result ~= ";";
			}
			result.length--;
			return result;
		}
	}

	//private ActionListener al;
	private string source;
	private string[] pathList, driveList;
	private string directory, filename;
	private ListView lb;
	private TextBox tb;

	private bool save;
	private FileAssociationDescriptor[] filetypes;
	public static const string subsourceID = "filedialog";
	private int selectedType;
	public void delegate(Event ev) onFileselect;
	private Button button_up;
	private Button button_drv;
	private Button button_ok;
	private Button button_close;
	private Button button_type;
	public static dstring[] 	buttonTexts = ["Up", "Drive", "Save", "Load", "Close", "Type"];	///Can be changed for localization
	/**
	 * Creates a file dialog with the given parameters.
	 * File types are given in the format '*.format'.
	 */
	public this(Text title, string source, void delegate(Event ev) onFileselect, FileAssociationDescriptor[] filetypes,
			string startDir, bool save = false, string filename = "", StyleSheet customStyle = null) {
		super(Coordinate(20,20,240,198), title, null, customStyle);
		this.source = source;
		this.filetypes = filetypes;
		this.save = save;
		this.onFileselect = onFileselect;
		//al = a;
		directory = startDir;
		auto btnFrmt = getStyleSheet().getChrFormatting("button");
		button_up = new Button(new Text(buttonTexts[0], btnFrmt),"up",Coordinate(4, 154, 54, 174));
		button_up.onMouseLClick = &up;
		addElement(button_up);
		button_drv = new Button(new Text(buttonTexts[1], btnFrmt),"drv",Coordinate(58, 154, 108, 174));
		button_drv.onMouseLClick = &changeDrive;
		addElement(button_drv);
		button_ok = new Button(new Text((save ? buttonTexts[2] : buttonTexts[3]), btnFrmt),"ok",
				Coordinate(112, 154, 162, 174));
		button_ok.onMouseLClick = &fileEvent;
		addElement(button_ok);
		button_close = new Button(new Text(buttonTexts[4], btnFrmt),"close",Coordinate(166, 154, 216, 174));
		button_close.onMouseLClick = &button_close_onMouseLClickRel;
		addElement(button_close);
		button_type = new Button(new Text(buttonTexts[5], btnFrmt),"type",Coordinate(166, 130, 216, 150));
		button_type.onMouseLClick = &button_type_onMouseLClickRel;
		addElement(button_type);
		//generate textbox
		tb = new TextBox(new Text(to!dstring(filename), getStyleSheet().getChrFormatting("textBox")), "filename", 
				Coordinate(4, 130, 162, 150));
		addElement(tb);
		//generate listbox


		//Date format: yyyy-mm-dd hh:mm:ss
		/+lb = new ListBox("lb", Coordinate(4, 20, 216, 126),null, new ListBoxHeader(["Name", "Type", "Date"], [160, 40, 176]),
				15);
		lb.onItemSelect = &listBox_onItemSelect;
		addElement(lb);+/
		spanDir();
		//scrollC ~= lb;
		//lb.onItemSelect = &actionEvent;
		detectDrive();
	}
	///Ditto
	public this(dstring title, string source, void delegate(Event ev) onFileselect, FileAssociationDescriptor[] filetypes,
			string startDir, bool save = false, string filename = "", StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		this(new Text(title, getStyleSheet().getChrFormatting("windowHeader")), source, onFileselect, filetypes, startDir, 
				save, filename, customStyle);
	}
	/**
	 * Iterates throught a directory for listing.
	 */
	private void spanDir(){
		import std.utf : toUTF32;
		
		pathList.length = 0;
		ListBoxItem[] items;
		foreach(DirEntry de; dirEntries(directory, SpanMode.shallow)){
			if(de.isDir){
				pathList ~= de.name;
				/*columns[0].elements ~= to!wstring(getFilenameFromPath(de.name));
				columns[1].elements ~= "<DIR>";
				columns[2].elements ~= formatDate(de.timeLastModified);*/
				items ~= new ListBoxItem([toUTF32(getFilenameFromPath(de.name)),"<DIR>"d,formatDate(de.timeLastModified)]);
			}
		}
		//foreach(f; filetypes){
		foreach(ft; filetypes[selectedType].types){
			foreach(DirEntry de; dirEntries(directory, ft, SpanMode.shallow)){
				if(de.isFile){
					pathList ~= de.name;
					/*columns[0].elements ~= to!wstring(getFilenameFromPath(de.name, true));
					columns[1].elements ~= to!wstring(ft);
					columns[2].elements ~= formatDate(de.timeLastModified);*/
					items ~= new ListBoxItem([toUTF32(getFilenameFromPath(de.name)),toUTF32(ft),formatDate(de.timeLastModified)]);
				}
			}
		}
		lb.updateColumns(items);
		lb.draw();

	}
	/**
	 * Standard date formatting tool.
	 */
	private dstring formatDate(SysTime time){
		dstring s;
		s ~= to!dstring(time.year());
		s ~= "-";
		s ~= to!dstring(time.month());
		s ~= "-";
		s ~= to!dstring(time.day());
		s ~= " ";
		s ~= to!dstring(time.hour());
		s ~= ":";
		s ~= to!dstring(time.minute());
		s ~= ":";
		s ~= to!dstring(time.second());
		return s;
	}
	/**
	 * Detects the available drives, currently only used under windows.
	 */
	private void detectDrive(){
		version(Windows){
			driveList.length = 0;
			for(char c = 'A'; c <='Z'; c++){
				string s;
				s ~= c;
				s ~= ":\x5c";
				if(exists(s)){
					driveList ~= (s);
				}
			}
		}else{

		}
	}
	/**
	 * Returns the filename from the path.
	 */
	private string getFilenameFromPath(string p, bool b = false){
		size_t n, m = p.length;
		string s;
		for(size_t i ; i < p.length ; i++){
			if(std.path.isDirSeparator(p[i])){
				n = i;
			}
		}
		//n++;
		if(b){
			for(size_t i ; i < p.length ; i++){
				if(p[i] == '.'){
					m = i;
				}
			}
		}
		for( ; n < m ; n++){
			if(p[n] < 128 && p[n] > 31)
				s ~= p[n];
		}
		return s;
	}
	/**
	 * Called when the up button is pressed. Goes up in the folder hiearchy.
	 */
	private void up(Event ev){
		int n;
		for(int i ; i < directory.length ; i++){
			if(std.path.isDirSeparator(directory[i])){
				n = i;
			}
		}
		/+string newdir;
		for(int i ; i < n ; i++){
			newdir ~= directory[i];
		}+/
		//directory = newdir;
		directory = directory[0..n];
		spanDir();

	}
	/**
	 * Displays the drives. Under Linux, it goes into the /dev/ folder.
	 */
	private void changeDrive(Event ev){
		version(Windows){
			pathList.length = 0;
			ListBoxItem[] items;
			foreach(string drive; driveList){
				pathList ~= drive;
				items ~= new ListBoxItem([to!dstring(drive),"<DRIVE>"d,""d]);
			}
			lb.updateColumns(items);
			lb.draw();
		}else version(Posix){
			directory = "/dev/";
			spanDir();
		}
	}
	/**
	 * Creates an action event, then closes the window.
	 */
	private void fileEvent(Event ev) {
		import std.utf : toUTF8;
		//wstring s = to!wstring(directory);
		filename = toUTF8(tb.getText.text);
		//al.actionEvent("file", EventType.FILEDIALOGEVENT, 0, s);
		if(onFileselect !is null)
			onFileselect(new Event(source, "", directory, filename, null, selectedType, EventType.FILEDIALOGEVENT));
		parent.closeWindow(this);
	}
	private void event_fileSelector(Event ev) {
		selectedType = ev.value;
		spanDir();
	}
	private void button_type_onMouseLClickRel(Event ev) {
		PopUpMenuElement[] e;
		auto frmt1 = getStyleSheet().getChrFormatting("menuPri");
		auto frmt2 = getStyleSheet().getChrFormatting("menuSec");
		for(int i ; i < filetypes.length ; i++){
			e ~= new PopUpMenuElement(filetypes[i].types[0],new Text(filetypes[i].description, frmt1), 
					new Text(filetypes[i].getTypesForSelector(), frmt2));
		}
		PopUpMenu p = new PopUpMenu(e,"fileSelector");
		p.onMouseClick = &event_fileSelector;
		parent.addPopUpElement(p);
	}
	private void button_close_onMouseLClickRel(Event ev) {
		parent.closeWindow(this);
	}
	private void listBox_onItemSelect(Event ev) {
		try{
			if(pathList.length == 0) return;
			if(isDir(pathList[ev.value])){
				directory = pathList[ev.value];
				spanDir();
			}else{
				filename = getFilenameFromPath(pathList[ev.value]);
				tb.setText(new Text(to!dstring(filename), tb.getText().formatting));
			}
		}catch(Exception e){
			auto frmt1 = getStyleSheet().getChrFormatting("windowHeader");
			auto frmt2 = getStyleSheet().getChrFormatting("default");
			DefaultDialog d = new DefaultDialog(Coordinate(10,10,256,80),"null", new Text(to!dstring("Error!"), frmt1),
					[new Text(to!dstring(e.msg), frmt2)]);
			parent.addWindow(d);
		}
	}
}