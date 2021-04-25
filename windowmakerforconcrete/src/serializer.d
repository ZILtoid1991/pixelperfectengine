module serializer;

import sdlang;
import editor;
import types;
import PixelPerfectEngine.graphics.common;
import PixelPerfectEngine.concrete.elements;
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
			switch(t0.getFullName.toString){
				case "Label":
					WindowElement we = new Label(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				case "Button":
					WindowElement we = new Button(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				case "SmallButton":
					break;
				case "TextBox":
					WindowElement we = new TextBox(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				case "CheckBox":
					WindowElement we = new CheckBox(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				case "ListView":
					int[] columnWidths;
					dstring[] columnTexts;
					const int headerHeight = t0.expectTag("header").expectValue!int();
					foreach(t1; t0.expectTag("header").tags){
						columnTexts ~= toUTF32(t1.values[0].get!string);
						columnWidths ~= t1.values[1].get!int;
					}
					WindowElement we = new ListView(new ListViewHeader(headerHeight, columnWidths, columnTexts), [], 
							t0.expectTagValue!string("source"), parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				/+case "RadioButtonGroup":
					dstring[] options;
					Value[] vals = t0.expectTag("options").values;
					foreach(v; vals){
						options ~= toUTF32(v.get!string);
					}
					WindowElement we = new RadioButtonGroup(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")), options, 16, 0);
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we,0);
					break;+/
				case "RadioButton":
					WindowElement we = new RadioButton(toUTF32(t0.expectTagValue!string("text")), t0.expectTagValue!string("source"),
							parseCoordinate(t0.expectTag("position")));
					e.elements[t0.expectValue!string()] = we;
					dw.addElement(we);
					break;
				case "Window":
					dw.setTitle(toUTF32(t0.expectTagValue!string("title")));
					dw.setSize(t0.expectTagValue!int("size:x"),t0.expectTagValue!int("size:y"));
					break;
				default:
					break;
			}
		}
		e.updateElementList;
	}
	public void generateDCode(string outputFile){
		string outputCode = "import PixelPerfectEngine.concrete.window \n\n", windowCtor, elementCtors, typeDefs;
		foreach(t0; root.all.tags){
			if(t0.getFullName.toString != "Window"){
				elementCtors ~= "\t\t" ~ t0.getValue!string() ~ " = ";
				typeDefs ~= "\t" ~ t0.name ~ " " ~ t0.getValue!string() ~ ";\n";
			}
			switch(t0.getFullName.toString){
				case "Button", "Label", "TextBox", "CheckBox", "RadioButton":
					elementCtors ~= "new " ~ t0.getFullName.toString ~ "(\"" ~ t0.getTagValue!string("text") ~ "\"d, \"" ~
							t0.getTagValue!string("source") ~ "\", Coordinate(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));\n";
					break;
				/+case "RadioButton":
					string options = "[";
					foreach(v; t0.getTagValues("options")){
						options ~= "\"" ~ v.get!string() ~ "\"d, ";
					}
					if(options != "[")
						options.length -= 2;
					options ~= "]";
					elementCtors ~= "\t\tnew RadioButton(\"" ~ t0.getTagValue!string("text") ~ "\"d, \"" ~ t0.getTagValue!string("source")
							~ "\", Coordinate(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));";
					break;+/
				case "HSlider", "VSlider":
					elementCtors ~= "\t\tnew " ~ t0.getFullName.toString ~ "(\"" ~ conv.to!string(t0.getTagValue!int("maxValue")) ~
							", " ~ conv.to!string(t0.getTagValue!int("barLength")) ~ ", " ~ t0.getTagValue!string("source") ~
							"\", Coordinate(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "));\n";
					break;
				case "OldListBox":
					string headerCtorA = "new ListBoxHeader([", headerCtorB = "], [";
					foreach(t1; t0.expectTag("header").tags){
						headerCtorA ~= "\"" ~ t1.values[0].get!string ~ "\"d, ";
						headerCtorB ~= conv.to!string(t1.values[1].get!int) ~ ", ";
					}
					headerCtorA.length -= 2;
					headerCtorB.length -= 2;
					elementCtors ~= "\t\tnew OldListBox(\"" ~ t0.getTagValue!string("source")
							~ "\", Coordinate(" ~ parseCoordinateIntoString(t0.getTag("position")) ~ "), [], " ~
							headerCtorA ~ headerCtorB ~ "]));\n";
					break;
				case "Window":
					outputCode ~= "public class " ~ t0.getValue!string() ~ " : Window {\n";
					string extraButtons;
					Tag t1 = t0.getTag("extraButtons", null);
					if(t1 !is null){
						if(t1.values.length){
							extraButtons = ", [";
							foreach(Value v; t1.values){
								extraButtons ~= v.get!string() ~ ", ";
							}
							extraButtons.length -= 2;
							extraButtons = "]";
						}
					}
					windowCtor = "super(\"" ~ t0.getTagValue!string("title") ~ "\"d, Coordinate(0, 0, " ~
							conv.to!string(t0.getTagValue!int("size:x")) ~ ", " ~ conv.to!string(t0.getTagValue!int("size:y")) ~ " )" ~
							extraButtons ~ ");\n";
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
	public void addElement(ElementType type, string name, Coordinate initPos){
		foreach(t; root.tags){
			if(t.getValue!string() == name)
				throw new ElementCollisionException("Similarly named element already exists!");
		}
		Tag t1;
		switch(type){
			case ElementType.Label:
				t1 = new Tag(root, null, "Label", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				break;
			case ElementType.Button:
				t1 = new Tag(root, null, "Button", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				new Tag(t1, null, "icon", [Value("null")]);
				break;
			case ElementType.TextBox:
				t1 = new Tag(root, null, "TextBox", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				break;
			case ElementType.ListView:
				t1 = new Tag(root, null, "OldListBox", [Value(name)]);
				Tag t2 = new Tag(t1, null, "header");
				new Tag(t2, null, null, [Value("col0"), Value(40)]);
				new Tag(t2, null, null, [Value("col1"), Value(40)]);
				break;
			case ElementType.RadioButton:
				t1 = new Tag(root, null, "RadioButton", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				break;
			case ElementType.CheckBox:
				t1 = new Tag(root, null, "CheckBox", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				break;
			case ElementType.HSlider:
				t1 = new Tag(root, null, "HSlider", [Value(name)]);
				new Tag(t1, null, "barLength", [Value(1)]);
				new Tag(t1, null, "maxValue", [Value(16)]);
				break;
			case ElementType.VSlider:
				t1 = new Tag(root, null, "VSlider", [Value(name)]);
				new Tag(t1, null, "barLength", [Value(1)]);
				new Tag(t1, null, "maxValue", [Value(16)]);
				break;
			case ElementType.MenuBar:
				t1 = new Tag(root, null, "MenuBar", [Value(name)]);
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
