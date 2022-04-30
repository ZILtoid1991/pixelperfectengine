module serializer;

import sdlang;
import editor;
import types;
import pixelperfectengine.graphics.common;
import pixelperfectengine.concrete.elements;
import std.utf;
import std.stdio;
import conv = std.conv;

public class WindowSerializer {
	Tag root;
	string filename;
	public this(){
		root = new Tag(null, null);
		Tag window = new Tag(root, null, "Window", [Value("window")]);
		new Tag(window, null, "title", [Value("New Window")]);
		new Tag(window, "size", "x", [Value(640)]);
		new Tag(window, "size", "y", [Value(480)]);
		new Tag(window, null, "extraButtons");
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
		string fileout = root.toSDLDocument("\t",1);
		debug writeln(fileout);
		File filestream = File(filename, "w");
		//filestream.open();
		filestream.write(fileout);
		filestream.close();
	}
	private Coordinate parseCoordinate(Tag t){
		return Coordinate(t.values[0].get!int,t.values[1].get!int,t.values[2].get!int,t.values[3].get!int);
	}
	private string parseCoordinateIntoString(Tag t){
		return conv.to!string(t.values[0].get!int) ~ ", " ~ conv.to!string(t.values[1].get!int) ~ ", " ~
				conv.to!string(t.values[2].get!int) ~ ", " ~ conv.to!string(t.values[3].get!int);
	}
	public void deserialize(DummyWindow dw, Editor e) {
		root = parseFile(filename);
		foreach(t0; root.all.tags){
			string name = t0.expectValue!string(), type;
			WindowElement we;
			switch(t0.getFullName.toString){
				case "Label":
					we = new Label(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "Label";
					break;
				case "Button":
					we = new Button(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "Button";
					break;
				case "SmallButton":
					break;
				case "TextBox":
					we = new TextBox(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "TextBox";
					break;
				case "SmallCheckBox":
					break;
				case "CheckBox":
					we = new CheckBox(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "CheckBox";
					break;
				case "SmallRadioButton":
					break;
				case "RadioButton":
					we = new RadioButton(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "RadioButton";
					break;
				case "ListView":
					int[] columnWidths;
					dstring[] columnTexts;
					const int headerHeight = t0.expectTag("header").expectValue!int();
					foreach(t1; t0.expectTag("header").tags){
						columnTexts ~= toUTF32(t1.values[0].get!string);
						columnWidths ~= t1.values[1].get!int;
					}
					we = new ListView(new ListViewHeader(headerHeight, columnWidths, columnTexts), [], 
							t0.expectTagValue!string("source"), parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "ListView";
					break;
				case "Window":
					dw.setTitle(toUTF32(t0.expectTagValue!string("title")));
					dw.setSize(t0.expectTagValue!int("size:x"),t0.expectTagValue!int("size:y"));
					type = "Window";
					break;
				case "HorizScrollBar":
					we = new HorizScrollBar(t0.expectTagValue!int("maxValue"), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "HorizScrollBar";
					break;
				case "VertScrollBar":
					we = new VertScrollBar(t0.expectTagValue!int("maxValue"), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					dw.addElement(we);
					type = "VertScrollBar";
					break;
				default:
					break;
			}
			if (type != "Window") {
				e.elements[name] = ElementInfo(we, name, type);
				//e.elementTypes[name] = type;
			}
		}
		e.updateElementList;
	}
	public void generateDCode(string outputFile){
		string outputCode = "import pixelperfectengine.concrete.window; \n\n", windowCtor, elementCtors, typeDefs;
		foreach(t0; root.all.tags){
			string typeName = t0.name;
			switch (typeName) {
				case "Window": break;
				case "SmallRadioButton":
					elementCtors ~= "\t\t" ~ t0.getValue!string() ~ " = ";
					typeDefs ~= "\t" ~ "RadioButton" ~ " " ~ t0.getValue!string() ~ ";\n";
					break;
				case "SmallCheckBox":
					elementCtors ~= "\t\t" ~ t0.getValue!string() ~ " = ";
					typeDefs ~= "\t" ~ "CheckBox" ~ " " ~ t0.getValue!string() ~ ";\n";
					break;
				default:
					elementCtors ~= "\t\t" ~ t0.getValue!string() ~ " = ";
					typeDefs ~= "\t" ~ typeName ~ " " ~ t0.getValue!string() ~ ";\n";
					break;
			}
			switch(typeName){
				case "Button", "Label", "TextBox", "CheckBox", "RadioButton":
					elementCtors ~= "new " ~ typeName ~ "(\"" ~ t0.getTagValue!string("text") ~ "\"d, \"" ~
							t0.getTagValue!string("source") ~ "\", Box(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));\n";
					break;
				case "HorizScrollBar", "VertScrollBar":
					elementCtors ~= "new " ~ typeName ~ "(\"" ~ conv.to!string(t0.getTagValue!int("maxValue")) ~ ", \"" ~ 
							t0.getTagValue!string("source") ~ "\", Box(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));\n";
					break;
				case "ListView":
					elementCtors ~= "new ListView(new ListViewHeader(" ~ conv.to!string(t0.getTagValue!int("header")) ~ "16, ";
					string intArr = "[", strArr = "[";
					foreach (t1 ; t0.expectTag("header").tags) {
						intArr ~= conv.to!string(t1.getValue!int()) ~ " ,";
						strArr ~= "\"" ~ t1.getValue!string() ~ "\" ,";
					}
					intArr = intArr[0..$-2] ~ "]";
					strArr = strArr[0..$-2] ~ "]";
					elementCtors ~= intArr ~ ", " ~ strArr ~ ", null, " ~  ", \"" ~ 
							t0.getTagValue!string("source") ~ "\", Box(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));\n";
					break;
				case "Window":
					outputCode ~= "public class " ~ t0.getValue!string() ~ " : Window {\n";
					//string extraButtons;
					/+Tag t1 = t0.getTag("extraButtons", null);
					if(t1 !is null){
						if(t1.values.length){
							extraButtons = ", [";
							foreach(Value v; t1.values){
								extraButtons ~= v.get!string() ~ ", ";
							}
							extraButtons.length -= 2;
							extraButtons = "]";
						}
					}+/
					/+windowCtor = "super(\"" ~ t0.getTagValue!string("title") ~ "\"d, Box(0, 0, " ~
							conv.to!string(t0.getTagValue!int("size:x")) ~ ", " ~ conv.to!string(t0.getTagValue!int("size:y")) ~ " )" ~
							extraButtons ~ ");\n";+/
					windowCtor = "super(Box(0, 0, " ~ conv.to!string(t0.getTagValue!int("size:x")) ~ ", " ~ 
							conv.to!string(t0.getTagValue!int("size:y")) ~ "), \"" ~ t0.getTagValue!string("title") ~ "\");\n";
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
	public Tag getTag(string target, string property){
		foreach(t0; root.all.tags){
			if(t0.getValue!string() == target){
				return t0.getTag(property);
			}
		}
		return null;
	}
	/**
	 * Edits the value of an element.
	 * For MenuBar PopUpMenu trees, use the getTag function instead.
	 */
	public Value[] editValue(string target, string property, Value[] val){
		Value[] result;
		foreach(t0; root.all.tags){
			if(t0.getValue!string() == target){
				result = t0.getTagValues(property);
				t0.getTag(property).values = val;
				return result;
			}
		}
		return result;
	}
	public Value[] getValue(string target, string property){
		foreach(t0; root.all.tags){
			if(t0.getValue!string() == target){
				return t0.getTagValues(property);
			}
		}
		return null;
	}
	public string renameWindow(string name){
		string oldname = root.getTag("Window").getValue!string();
		root.getTag("Window").values[0] = Value(name);
		return oldname;
	}
	public string getWindowName(){
		return root.getTag("Window").getValue!string();
	}
	public Value[] editWindowValue(string property, Value[] val){
		Value[] result = root.getTag("Window").getTag(property).values;
		root.getTag("Window").getTag(property).values = val;
		return result;
	}
	public Value[] getWindowValue(string property){
		return root.getTag("Window").getTag(property).values;
	}
	public void renameElement(string oldName, string newName){
		foreach(t; root.tags){
			if(t.getValue!string() == oldName){
				t.values[0] = Value(newName);
				return;
			}
		}
	}
	public void addElement(string type, string name, Coordinate initPos){
		foreach(t; root.tags){
			if(t.getValue!string() == name)
				throw new ElementCollisionException("Similarly named element already exists!");
		}
		Tag t1 = new Tag(root, null, type, [Value(name)]);
		switch(type){
			case "Label", "TextBox", "RadioButton", "CheckBox":
				new Tag(t1, null, "text", [Value(name)]);
				break;
			case "Button":
				new Tag(t1, null, "icon", [Value("null")]);
				goto case "Label";
			case "ListView":
				Tag t2 = new Tag(t1, null, "header", [Value(16)]);
				new Tag(t2, null, null, [Value("col0"), Value(40)]);
				new Tag(t2, null, null, [Value("col1"), Value(40)]);
				break;
			case "HorizScrollBar", "VertScrollBar":
				//new Tag(t1, null, "barLength", [Value(1)]);
				new Tag(t1, null, "maxValue", [Value(16)]);
				break;
			case "MenuBar":
				Tag t2 = new Tag(t1, null, "options");
				Tag t3 = new Tag(t2, null, null, [Value("opt0")]);
				new Tag(t3, null, null, [Value("opt0_0")]);
				new Tag(t3, null, null, [Value("opt0_1")]);
				Tag t4 = new Tag(t2, null, null, [Value("opt1")]);
				new Tag(t4, null, null, [Value("opt1_0")]);
				new Tag(t4, null, null, [Value("opt1_1")]);
				break;
			default:
				break;
		}
		new Tag(t1, null, "source", [Value(name)]);
		new Tag(t1, null, "position", [Value(initPos.left), Value(initPos.top), Value(initPos.right), Value(initPos.bottom)]);
		//debug writeln(t1);
	}
	public void addElement(Tag tag){
		foreach(t; root.tags){
			if(t.values[0].get!string() == tag.values[0].get!string())
				throw new ElementCollisionException("Similarly named element already exists!");
		}
		root.add(tag);
	}
	public Tag removeElement(string name){
		foreach(t; root.tags){
			if(t.values[0].get!string() == name){
				t.remove;
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
