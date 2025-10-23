module serializer;

import newsdlang;
import editor;
import types;
import pixelperfectengine.graphics.common;
import pixelperfectengine.concrete.elements;
import std.utf;
import std.stdio;
import std.file;
import conv = std.conv;

public class WindowSerializer {
	DLDocument root;
	string filename;
	public this(){
		root = new DLDocument(null);
		DLTag window = new DLTag("Window", null, [new DLValue("window")]);
		root.add(window);
		window.add(new DLTag("title", null, [new DLValue("New Window")]));
		window.add(new DLTag("x", "size", [new DLValue(640)]));
		window.add(new DLTag("y", "size", [new DLValue(480)]));
		window.add(new DLTag("extraButtons", null, null));
	}
	public this(string filename) {
		this.filename = filename;
	}
	public void store(string filename) {
		this.filename = filename;
		store();
	}
	public @property @nogc string getFilename() {
		return filename;
	}
	public void store() {
		import std.string : toStringz;
		string fileout = root.writeDOM();
		debug writeln(fileout);
		File filestream = File(filename, "w");
		//filestream.open();
		filestream.write(fileout);
		filestream.close();
	}
	private Box parseCoordinate(DLTag t){
		return Box(t.values[0].get!int,t.values[1].get!int,t.values[2].get!int,t.values[3].get!int);
	}
	private string parseCoordinateIntoString(DLTag t){
		return conv.to!string(t.values[0].get!int) ~ ", " ~ conv.to!string(t.values[1].get!int) ~ ", " ~
				conv.to!string(t.values[2].get!int) ~ ", " ~ conv.to!string(t.values[3].get!int);
	}
	public void deserialize(DummyWindow dw, Editor e) {
		root = readDOM(readText(filename));
		foreach(DLTag t0; root.tags) {
			string name = t0.searchValue!string(null), type = t0.name;
			// foreach (DLValue v ; t0.values) {
			// 	if (v.type == DLValueType.String) {
			// 		name = v.get!string;
			// 		break;
			// 	}
			// }
			WindowElement we;
			switch(t0.name){
				case "Label":
					we = new Label(toUTF32(t0.searchTag("text").values[0].get!string), t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "Button":
					we = new Button(toUTF32(t0.searchTag("text").values[0].get!string), t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "SmallButton":
					break;
				case "TextBox":
					we = new TextBox(toUTF32(t0.searchTag("text").values[0].get!string), t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "SmallCheckBox":
					break;
				case "CheckBox":
					we = new CheckBox(toUTF32(t0.searchTag("text").values[0].get!string), t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "SmallRadioButton":
					break;
				case "RadioButton":
					we = new RadioButton(toUTF32(t0.searchTag("text").values[0].get!string),
							t0.searchTag("source").values[0].get!string, parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "ListView":
					int[] columnWidths;
					dstring[] columnTexts;
					const int headerHeight = t0.searchTag("header").values[0].get!int;
					foreach(t1; t0.searchTag("header").tags){
						columnTexts ~= toUTF32(t1.values[0].get!string);
						columnWidths ~= t1.values[1].get!int;
					}
					we = new ListView(new ListViewHeader(headerHeight, columnWidths, columnTexts), [],
							t0.searchTag("source").values[0].get!string, parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "Window":
					dw.setTitle(toUTF32(t0.searchTag("title").values[0].get!string));
					dw.setSize(t0.searchTag("size:x").values[0].get!int,t0.searchTag("size:y").values[0].get!int);

					break;
				case "HorizScrollBar":
					we = new HorizScrollBar(t0.searchTag("maxValue").values[0].get!int, t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				case "VertScrollBar":
					we = new VertScrollBar(t0.searchTag("maxValue").values[0].get!int, t0.searchTag("source").values[0].get!string,
							parseCoordinate(t0.searchTag("position")));
					dw.addElement(we);
					break;
				default:
					break;
			}
			if (we) {
				e.elements[name] = ElementInfo(we, name, type);
			}
		}
		e.updateElementList;
	}
	public void generateDCode(string outputFile){
		string outputCode = "import pixelperfectengine.concrete.window; \n\n", windowCtor, elementCtors, typeDefs;
		foreach(DLTag t0 ; root.tags){
			string typeName = t0.name;
			switch (typeName) {
				case "Window": break;
				case "SmallRadioButton":
					elementCtors ~= "\t\t" ~ t0.values[0].get!string() ~ " = ";
					typeDefs ~= "\t" ~ "RadioButton" ~ " " ~ t0.values[0].get!string() ~ ";\n";
					break;
				case "SmallCheckBox":
					elementCtors ~= "\t\t" ~ t0.values[0].get!string() ~ " = ";
					typeDefs ~= "\t" ~ "CheckBox" ~ " " ~ t0.values[0].get!string() ~ ";\n";
					break;
				default:
					elementCtors ~= "\t\t" ~ t0.values[0].get!string() ~ " = ";
					typeDefs ~= "\t" ~ typeName ~ " " ~ t0.values[0].get!string() ~ ";\n";
					break;
			}
			switch(typeName) {
				case "Button", "Label", "TextBox", "CheckBox", "RadioButton":
					elementCtors ~= "new " ~ typeName ~ "(\"" ~ t0.searchTag("text").values[0].get!string ~ "\"d, \"" ~
							t0.searchTag("source").values[0].get!string ~ "\", Box(" ~ parseCoordinateIntoString(t0.searchTag("position")) ~
							"));\n";
					break;
				case "HorizScrollBar", "VertScrollBar":
					elementCtors ~= "new " ~ typeName ~ "(\"" ~ conv.to!string(t0.searchTag("maxValue").values[0].get!int) ~ ", \"" ~
							t0.searchTag("source").values[0].get!string ~ "\", Box(" ~ parseCoordinateIntoString(t0.searchTag("position")) ~
							"));\n";
					break;
				case "ListView":
					elementCtors ~= "new ListView(new ListViewHeader(" ~ conv.to!string(t0.searchTag("header").values[0].get!int) ~
							", ";
					string intArr = "[", strArr = "[";
					foreach (t1 ; t0.searchTag("header").tags) {
						intArr ~= conv.to!string(t1.values[1].get!int()) ~ " ,";
						strArr ~= "\"" ~ t1.values[0].get!string() ~ "\" ,";
					}
					intArr = intArr[0..$-2] ~ "]";
					strArr = strArr[0..$-2] ~ "]";
					elementCtors ~= intArr ~ ", " ~ strArr ~ "), null, \"" ~ 
							t0.searchTag("source").values[0].get!string ~ "\", Box(" ~ parseCoordinateIntoString(t0.searchTag("position"))
							~ "));\n";
					break;
				case "Window":
					outputCode ~= "public class " ~ t0.values[0].get!string() ~ " : Window {\n";
					windowCtor = "super(Box(0, 0, " ~ conv.to!string(t0.searchTag("size:x").values[0].get!int) ~ ", " ~
							conv.to!string(t0.searchTag("size:y").values[0].get!int) ~ "), \"" ~ t0.searchTag("title").values[0].get!string
							~ "\");\n";
					break;
				default:
					break;
			}
		}
		outputCode ~= typeDefs ~ "\tpublic this(){\n\t\t" ~ windowCtor ~ elementCtors ~ "\t}\n}\n";
		debug writeln(outputCode);
		File filestream = File(outputFile, "w");
		//filestream.open();
		filestream.write(outputCode);
		filestream.close();
	}
	/**
	 * Returns a complete tag for editing a tree, etc.
	 */
	public DLTag getTag(string target, string property){
		foreach(t0; root.tags){
			if(t0.values[0].get == DLVar(target)){
				return t0.searchTag(property);
			}
		}
		return null;
	}
	/** 
	 * Replaces an existing tag with a new one.
	 * Params:
	 *   target = The name of the window element, which tag must be replaced.
	 *   property = The name of the property Tag.
	 *   newTag = The new tag to be used in the place of the old
	 * Returns: The old tag as a backup.
	 */
	public DLTag replaceTag(string target, string property, DLTag newTag) {
		foreach(DLTag t0; root.tags){
			if(t0.values[0].get == DLVar(target)){
				DLTag oldTag = t0.searchTag(property);
				oldTag.removeFromParent();
				t0.add(newTag);
				return oldTag;
			}
		}
		return null;
	}
	/**
	 * Edits the value of an element.
	 * For MenuBar PopUpMenu trees, use the getTag function instead.
	 */
	public DLValue[] editValue(string target, string property, DLValue[] val) {
		DLValue[] result;
		foreach(DLTag t0; root.tags){
			if(t0.values[0].get == DLVar(target)){
				result = t0.searchTag(property).values;
				foreach(DLValue v ; result) v.removeFromParent();
				foreach(DLValue v ; val) t0.searchTag(property).add(v);
				return result;
			}
		}
		return result;
	}
	public DLValue[] getValue(string target, string property) {
		foreach(DLTag t0; root.tags){
			if(t0.values[0].get == DLVar(target)){
				return t0.searchTag(property).values;
			}
		}
		return null;
	}
	public string renameWindow(string name) {
		string oldname = root.searchTag("Window").values[0].get!string();
		root.searchTag("Window").values[0].set = DLVar(name);
		return oldname;
	}
	public string getWindowName() {
		return root.searchTag("Window").values[0].get!string();
	}
	public DLValue[] editWindowValue(string property, DLValue[] val){
		DLValue[] result = root.searchTag("Window").searchTag(property).values;
		foreach (DLValue v ; result) v.removeFromParent();
		foreach (DLValue v ; val) root.searchTag("Window").searchTag(property).add(v);
		return result;
	}
	public DLValue[] getWindowValue(string property){
		return root.searchTag("Window").searchTag(property).values;
	}
	public void renameElement(string oldName, string newName) {
		foreach (DLTag t; root.tags) {
			if (t.values[0].get!string() == oldName) {
				t.values[0].removeFromParent;
				t.add(new DLValue(newName));
				return;
			}
		}
	}
	public void addElement(string type, string name, Box initPos) {
		foreach (DLTag t ; root.tags) {
			if (t.values[0].get == DLVar(name)) throw new ElementCollisionException("Similarly named element already exists!");
		}
		DLTag t1 = new DLTag(type, null, [new DLValue(name)]);
		root.add(t1);
		switch(type){
			case "Label", "TextBox", "RadioButton", "CheckBox":
				t1.add(new DLTag("text", null, [new DLValue(name)]));
				break;
			case "Button":
				t1.add(new DLTag("icon", null, [new DLValue("null")]));
				goto case "Label";
			case "ListView":
				DLTag t2 = new DLTag("header", null, [new DLValue(16)]);
				t2.add(new DLTag(null, null, [new DLValue("col0"), new DLValue(40)]));
				t2.add(new DLTag(null, null, [new DLValue("col1"), new DLValue(40)]));
				t1.add(t2);
				break;
			case "HorizScrollBar", "VertScrollBar":
				//new Tag(t1, null, "barLength", [Value(1)]);
				t1.add(new DLTag(null, "maxValue", [new DLValue(16)]));
				break;
			case "MenuBar":
				DLTag t2 = new DLTag("options", null, [new DLTag(null, null, [
					new DLTag("entry", null, [new DLValue("opt0"), new DLTag(null, null, [new DLValue("opt0_0")]),
						new DLTag(null, null, [new DLValue("opt0_1")])]),
					new DLTag("entry", null, [new DLValue("opt1"), new DLTag(null, null, [new DLValue("opt1_0")]),
						new DLTag(null, null, [new DLValue("opt1_1")])]),
						])]);
				break;
			default:
				break;
		}
		t1.add(new DLTag("source", null, [new DLValue(name)]));
		t1.add(new DLTag("position", null,
				[new DLValue(initPos.left), new DLValue(initPos.top), new DLValue(initPos.right), new DLValue(initPos.bottom)]));
		//debug writeln(t1);
	}
	public void addElement(DLTag tag){
		foreach(DLTag t; root.tags){
			if(t.values[0].get!string() == tag.values[0].get!string())
				throw new ElementCollisionException("Similarly named element already exists!");
		}
		root.add(tag);
	}
	public DLTag removeElement(string name){
		foreach(DLTag t; root.tags){
			if(t.values[0].get!string() == name){
				t.removeFromParent;
				return t;
			}
		}
		return null;
	}
}
class ElementCollisionException : Exception{
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
