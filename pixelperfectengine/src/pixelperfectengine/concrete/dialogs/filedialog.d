module pixelperfectengine.concrete.dialogs.filedialog;

public import pixelperfectengine.concrete.window;
import pixelperfectengine.concrete.elements;
import std.datetime;
import std.conv : to;
import std.file;
import std.path;

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
	public enum Type {
		Load,
		Save,
		New,
		LoadWPath,
		SaveWPath,
		NewWPath,
	}
	private string source;
	private string[] pathList, driveList;
	private string directory, filename;
	private ListView filelist;
	private TextBox filenameInput;
	private Button filetypeSelector;

	private bool save;
	private FileAssociationDescriptor[] filetypes;
	private int selectedType;
	public void delegate(Event ev) onFileselect;
	
	/**
	 * Creates a file dialog with the given parameters.
	 * File types are given in the format '*.format'.
	 * Params: 
	 *   title = The title of the window.
	 *   source = Event source identifier.
	 *   onFileselect = The event delegate called when the file is selected. No event is generated if a file wasn't 
	 * selected.
	 *   filetypes = The list of possible selectable filetypes. First one is being selected as the default one.
	 *   startDir = Starting directory for the file dialog.
	 *   type = The type of the file dialog.
	 *   filename = The current file name.
	 *   customStyle = Can specify a custom stylesheet for this instance of a file dialog.
	 */
	public this(Text title, string source, void delegate(Event ev) onFileselect, FileAssociationDescriptor[] filetypes,
			string startDir, Type type = Type.Load, string filename = "", StyleSheet customStyle = null) {
		ISmallButton[] smallButtons;
		const int windowHeaderHeight = customStyle.drawParameters["WindowHeaderHeight"];
		const int windowElementSize = customStyle.drawParameters["WindowElementSize"];
		const int windowElementSpacing = customStyle.drawParameters["WindowElementSpacing"];
		if (customStyle is null) customStyle = getStyleSheet();
		{
			SmallButton closeButton = closeButton(customStyle);
			closeButton.onMouseLClick = &close;
			smallButtons ~= closeButton;
		}
		{
			SmallButton pathBtn = new SmallButton("dirUpButtonB", "dirUpButtonA", "path", 
					Box.bySize(0,0,windowHeaderHeight,windowHeaderHeight));
			pathBtn.onMouseLClick = &up;
			smallButtons ~= pathBtn;
		}
		{

			void addPathBtn() {
				SmallButton pathBtn = new SmallButton("pathButtonB", "pathButtonA", "path", 
						Box.bySize(0,0,windowHeaderHeight,windowHeaderHeight));
				pathBtn.onMouseLClick = &openPathSys;
				smallButtons ~= pathBtn;
			}
			void ctorfckeryworkaround() {
				SmallButton actionBtn;
				final switch (type) with (Type) {
					case Load:
						actionBtn = new SmallButton("loadButtonB", "loadButtonA", "action", 
								Box.bySize(0,0,windowHeaderHeight,windowHeaderHeight));
						break;
					case Save:
						actionBtn = new SmallButton("saveButtonB", "saveButtonA", "action", 
								Box.bySize(0,0,windowHeaderHeight,windowHeaderHeight));
						break;
					case New:
						actionBtn = new SmallButton("newButtonB", "newButtonA", "action", 
								Box.bySize(0,0,windowHeaderHeight,windowHeaderHeight));
						break;
					case LoadWPath:
						addPathBtn();
						goto case Load;
					case SaveWPath:
						addPathBtn();
						goto case Save;
					case NewWPath:
						addPathBtn();
						goto case New;
				}
				actionBtn.onMouseLClick = &fileEvent;
				smallButtons ~= actionBtn;
			}
			ctorfckeryworkaround();
		}
		
		super(Coordinate(20,20,240,198), title, smallButtons, customStyle);
		this.source = source;
		this.filetypes = filetypes;
		this.save = save;
		this.onFileselect = onFileselect;
		//al = a;
		directory = buildNormalizedPath(absolutePath(startDir));
		
		
		filenameInput = new TextBox(new Text(to!dstring(filename), getStyleSheet().getChrFormatting("textBox")), "filename", 
				Coordinate(4, 130, 162, 150));
		addElement(filenameInput);

		//generate listview
		auto hdrFrmt = getStyleSheet().getChrFormatting("ListViewHeader");
		const int headerHeight = hdrFrmt.font.size + getStyleSheet().drawParameters["ListViewRowPadding"];
		ListViewHeader lvh = new ListViewHeader(headerHeight, [160, 40, 176], [new Text("Name", hdrFrmt), 
				new Text("Type", hdrFrmt), new Text("Date", hdrFrmt)]);
		filelist = new ListView(lvh, null, "lw", Box(4, 20, 216, 126));
		addElement(filelist);
		filelist.onItemSelect = &listView_onItemSelect;
		//filetypeSelector = new Button();
		version(Windows){
			for(char c = 'A'; c <='Z'; c++){
				string s;
				s ~= c;
				s ~= ":\x5c";
				if(exists(s)){
					driveList ~= (s);
				}
			}
		}

		spanDir();
	}
	///Ditto
	/* public this(dstring title, string source, void delegate(Event ev) onFileselect, FileAssociationDescriptor[] filetypes,
			string startDir, bool save = false, string filename = "", StyleSheet customStyle = null) {
		this.customStyle = customStyle;
		this(new Text(title, getStyleSheet().getChrFormatting("windowHeader")), source, onFileselect, filetypes, startDir, 
				save, filename, customStyle);
	} */
	/**
	 * Iterates throught a directory for listing.
	 */
	private void spanDir(){
		pathList.length = 0;
		filelist.clear();
		try {
			foreach(DirEntry de; dirEntries(directory, SpanMode.shallow)){
				if(de.isDir){
					pathList ~= de.name;
					createEntry(de.name, "<DIR>", de.timeLastModified);
				}
			}

			foreach(ft; filetypes[selectedType].types){
				foreach(DirEntry de; dirEntries(directory, ft, SpanMode.shallow)){
					if(de.isFile){
						pathList ~= de.name;
						createEntry(de.name, ft, de.timeLastModified);
					}
				}
			}
		} catch (Exception e) {
			debug {
				import std.stdio : writeln;
				writeln(e);
			}
			handler.message("Directory error!", to!dstring(e.msg));
		}
		filelist.refresh();
	}
	/**
	 * Creates a single ListViewItem with the supplied data, then adds it to the ListView.
	 */
	private void createEntry(string filename, string filetype, SysTime time) {
		import std.utf : toUTF32;
		auto frmt = getStyleSheet().getChrFormatting("ListViewItem");
		const int height = frmt.font.size + getStyleSheet().drawParameters["ListViewRowPadding"];
		filelist ~= new ListViewItem(height, [new Text(toUTF32(baseName(filename)), frmt), new Text(toUTF32(filetype), frmt), 
				new Text(formatDate(time), frmt)]);
	}
	/**
	 * Creates drive entry for the ListView.
	 */
	private void createDriveEntry(dstring driveName) {
		//import std.utf : toUTF32;
		auto frmt = getStyleSheet().getChrFormatting("ListViewItem");
		const int height = frmt.font.size + getStyleSheet().drawParameters["ListViewRowPadding"];
		filelist ~= new ListViewItem(height, [new Text(driveName, frmt), new Text("<DRIVE>", frmt), 
				new Text("n/a", frmt)]);
	}
	/**
	 * Standard date formatting tool.
	 */
	private dstring formatDate(SysTime time){
		dchar[] s;
		s.reserve(24);
		s ~= to!dstring(time.year());
		s ~= '-';
		s ~= to!dstring(time.month());
		s ~= '-';
		s ~= to!dstring(time.day());
		s ~= ' ';
		s ~= to!dstring(time.hour());
		s ~= ':';
		s ~= to!dstring(time.minute());
		s ~= ':';
		s ~= to!dstring(time.second());
		return s.idup;
	}
	public override void onResize() {

	}
	
	/**
	 * Called when the up button is pressed. Goes up in the folder hiearchy.
	 */
	private void up(Event ev){
		int n;
		for(int i ; i < directory.length ; i++){
			if(isDirSeparator(directory[i])){
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
			filelist.clear();
			//ListBoxItem[] items;
			foreach(string drive; driveList){
				pathList ~= drive;
				//items ~= new ListBoxItem([to!dstring(drive),"<DRIVE>"d,""d]);
				createDriveEntry(to!dstring(drive));
			}
			filelist.refresh();
			//lb.updateColumns(items);
			//lb.draw();
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
		filename = toUTF8(filenameInput.getText.text);
		
		if(onFileselect !is null)
			onFileselect(new FileEvent(this, SourceType.DialogWindow, directory, filename, filetypes[selectedType].types[0][1..$]));
			//onFileselect(new Event(source, "", directory, filename, null, selectedType, EventType.FILEDIALOGEVENT));
		handler.closeWindow(this);
	}
	private void event_fileSelector(Event ev) {
		//selectedType = lw.value;
		import std.algorithm.searching : canFind;
		if (ev.type == EventType.Menu) {
			MenuEvent mev = cast(MenuEvent)ev;
			selectedType = cast(int)mev.itemNum;
			spanDir();
		}
	}
	private void openPathSys(Event ev) {

	}
	private void button_type_onMouseLClickRel(Event ev) {
		PopUpMenuElement[] e;
		auto frmt1 = getStyleSheet().getChrFormatting("popUpMenu");
		auto frmt2 = getStyleSheet().getChrFormatting("popUpMenuSecondary");
		for(int i ; i < filetypes.length ; i++){
			e ~= new PopUpMenuElement(filetypes[i].types[0],new Text(filetypes[i].description, frmt1), 
					new Text(filetypes[i].getTypesForSelector(), frmt2));
		}
		PopUpMenu p = new PopUpMenu(e,"fileSelector", &event_fileSelector);
		handler.addPopUpElement(p);
	}
	private void button_close_onMouseLClickRel(Event ev) {
		handler.closeWindow(this);
	}
	private void listView_onItemSelect(Event ev) {
		try {
			if(pathList.length == 0) return;
			if(isDir(pathList[filelist.value])){
				directory = pathList[filelist.value];
				spanDir();
			}else{
				filename = baseName(stripExtension(pathList[filelist.value]));
				filenameInput.setText(new Text(to!dstring(filename), filenameInput.getText().formatting));
			}
		} catch(Exception e) {
			handler.message("Error!",to!dstring(e.msg));
		}
	}
}