module windowDataLoader;

import sdlang;
import app;
import PixelPerfectEngine.graphics.common;

import std.conv;
import std.variant;
import std.utf;
import std.stdio;
import elementTypes;
import PixelPerfectEngine.concrete.elements;

public enum AttributeType{
	INTEGER,
	ASCIISTRING,
	UTFSTRING,
	FLOAT,
	MULTISTRING,
	MULTIUTFSTRING,
	LISTBOXELEMENT,
	MENUBARELEMENT,
}

public class WindowData {
	private Tag root; /// Stores all the data
	public string filename, windowName;
	public this(){
		root = new Tag();
		Tag t0 = new Tag(root, null, "Window");
		new Tag(t0, null, "width", [Value(640)]);
		new Tag(t0, null, "height", [Value(480 - 16)]);
		new Tag(t0, null, "title",[Value("New project")]);
		new Tag(t0, null, "name",[Value("NewWindow")]);
		new Tag(t0, null, "extraButtons");
		new Tag(t0, null, "elements");
		windowName = "NewWindow";
		//writeln(root.toSDLDocument());
	}
	public this(string filename){
		this.filename = filename;
	}
	public WindowElement[string] deserialize(string path = this.filename){
		root = parseFile(path);
		if(!root)
			throw new WindowDataException("File access error!");
		mainApp.ewh.dw = new DummyWindow(Coordinate(0, 0, root.getTag("Window").getTagValue!int("width"), root.getTag("Window").getTagValue!int("height")), toUTF16(root.getTag("Window").getTagValue!string("title")));
		windowName = root.getTag("Window").getTagValue!string("name");
		WindowElement[string] result;
		foreach(Tag t0; root.expectTag("Window").expectTag("elements").tags){
			Coordinate c = Coordinate(t0.expectTagValue!int("Coordinate:left"),t0.expectTagValue!int("Coordinate:top"),t0.expectTagValue!int("Coordinate:right"),t0.expectTagValue!int("Coordinate:bottom"));
			WindowElement we;
			switch(t0.name){
				case "Button":
					we = new Button(toUTF16(t0.expectTagValue!string("text")),t0.expectTagValue!string("source"),c);
					break;
				case "Label":
					we = new Label(toUTF16(t0.expectTagValue!string("text")),t0.expectTagValue!string("source"),c);
					break;
				case "TextBox":
					we = new TextBox(toUTF16(t0.expectTagValue!string("text")),t0.expectTagValue!string("source"),c);
					break;
				case "ListBox":
					ListBoxHeader lbh;
					wstring[] lbhStrings;
					int[] lbhWidth;
					foreach(Tag t1; t0.expectTag("header").tags){
						lbhStrings ~= toUTF16(t1.expectValue!string());
						lbhWidth ~= t1.expectValue!int();
					}
					lbh = new ListBoxHeader(lbhStrings, lbhWidth);
					we = new ListBox(t0.expectTagValue!string("source"),c, null, lbh, t0.expectTagValue!int("rowHeight"));
					break;
				case "HSlider":
					we = new HSlider(t0.expectTagValue!int("maxValue"),t0.expectTagValue!int("barLength"),t0.expectTagValue!string("source"),c);
					break;
				case "VSlider":
					we = new VSlider(t0.expectTagValue!int("maxValue"),t0.expectTagValue!int("barLength"),t0.expectTagValue!string("source"),c);
					break;
				case "RadioButtonGroup":
					wstring[] options;
					foreach(Value v1; t0.expectTag("options").values){
						options ~= toUTF16(v1.get!string());
					}
					we = new RadioButtonGroup(toUTF16(t0.expectTagValue!string("text")),t0.expectTagValue!string("source"),c,options,t0.expectTagValue!int("rowHeight"),0);
					break;
				case "CheckBox":
					we = new CheckBox(toUTF16(t0.expectTagValue!string("text")),t0.expectTagValue!string("source"),c);
					break;
				case "MenuBar":
					PopUpMenuElement[] elements = fetchMenuBarElements(t0.expectTag("elements"));
					we = new MenuBar(t0.expectTagValue!string("source"),c, elements);
					break;
				default:
					break;
			}
			result[t0.expectTagValue!string("name")] = we;
			mainApp.ewh.dw.addElement(we, 0);
		}

		return result;
	}
	/+public PopUpMenu[] fetchMenuBarElements(Tag t){
		PopUpMenu[] result;
		foreach(Tag t0; t.tags){
			if(t0.name == "popUpMenu"){
				string source = t0.expectTagValue!string("source");
				int iconWidth = t0.getTagValue!int("iconWidth");
				PopUpMenuElement[] subelements = fetchMenuBarSubelements(t0.expectTag("elements"));
				result ~= new PopUpMenu(subelements, source, iconWidth);
			}
		}
		return result;
	}+/
	public PopUpMenuElement[] fetchMenuBarElements(Tag t){
		PopUpMenuElement[] result;
		foreach(Tag t1; t.tags){
			wstring text = toUTF16(t1.expectTagValue!string("text"));
			wstring secondaryText = toUTF16(t1.getTagValue!string("secondaryText"));
			string source = t1.expectTagValue!string("source");
			PopUpMenuElement e = new PopUpMenuElement(source, text, secondaryText);
			Tag t2 = t1.getTag("elements");
			if(t2){
				e.loadSubElements(fetchMenuBarElements(t2));
			}
			result ~= e;
		}
		return result;
	}
	public void serialize(string path = this.filename){
		import std.file;
		string data = root.toSDLDocument();
		std.file.write(path, data);
	}
	public void exportToDLangFile(string path, string tab = "\t"){
		import std.file;
		string result, ctor;
		// Generate class header
		result ~= "class " ~ windowName ~ " : Window { \n";
		// Generate basic ctor for class 
		ctor ~= tab ~ "this(){" ~ "\n" ~ tab ~ tab
				~ "super(Coordinate(0, 0, " ~ to!string(root.expectTag("Window").expectTagValue!int("width")) ~ ", " ~ to!string(root.expectTag("Window").expectTagValue!int("height")) ~ "), \""
				~ root.expectTag("Window").expectTagValue!string("title") ~ "\"w);\n";
		// Add elements to the class as members, then add them to the ctor
		foreach(Tag t0; root.expectTag("Window").expectTag("elements").tags){
			string coordinate = "Coordinate(" ~ to!string(t0.expectTagValue!int("Coordinate:left")) ~ ", " ~ to!string(t0.expectTagValue!int("Coordinate:top")) ~ ", "
					~ to!string(t0.expectTagValue!int("Coordinate:right")) ~ ", " ~ to!string(t0.expectTagValue!int("Coordinate:bottom")) ~ ")";
			switch(t0.name){
				case "Label":
					result ~= tab ~ "Label " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new Label(\"" ~ t0.expectTagValue!string("text") ~ "\"w, \"" ~ t0.expectTagValue!string("source") 
							~ "\", " ~ coordinate ~ ");\n";
					break;
				case "Button":
					result ~= tab ~ "Button " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new Button(\"" ~ t0.expectTagValue!string("text") ~ "\"w, \"" ~ t0.expectTagValue!string("source") 
							~ "\", " ~ coordinate ~ ");\n";
					break;
				case "CheckBox":
					result ~= tab ~ "CheckBox " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new CheckBox(\"" ~ t0.expectTagValue!string("text") ~ "\"w, \"" ~ t0.expectTagValue!string("source") 
							~ "\", " ~ coordinate ~ ");\n";
					break;
				case "TextBox":
					result ~= tab ~ "TextBox " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new TextBox(\"" ~ t0.expectTagValue!string("text") ~ "\"w, \"" ~ t0.expectTagValue!string("source") 
							~ "\", " ~ coordinate ~ ");\n";
					break;
				case "RadioButtonGroup":
					result ~= tab ~ "RadioButtonGroup " ~ t0.expectTagValue!string("name") ~ ";\n";
					string options;
					foreach(Value v0; t0.expectTag("options").values){
						options ~= "\"" ~ v0.get!string() ~ "\"w, ";
					}
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new RadioButtonGroup(\"" ~ t0.expectTagValue!string("text") ~ "\"w, \"" ~ t0.expectTagValue!string("source") 
							~ "\", " ~ coordinate ~ ",[ " ~ options ~ "], " ~ to!string(t0.expectTagValue!int("rowHeight")) ~ ", 0);\n";
					break;
				case "ListBox":
					result ~= tab ~ "ListBox " ~ t0.expectTagValue!string("name") ~ ";\n";
					string headerStr, headerInt;
					foreach(Tag t1; t0.expectTag("header").tags){
						headerStr ~= "\"" ~ t1.values[0].get!string() ~ "\"w, ";
						headerInt ~= to!string(t1.values[1].get!int()) ~ ", ";
					}
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new ListBox(\"" ~ t0.expectTagValue!string("source") ~ coordinate ~ "null, new ListBoxHeader([" 
							~ headerStr ~ "], [" ~ headerInt ~ "]), " ~ to!string(t0.expectTagValue!int("rowHeight")) ~ ");\n";
					break;
				case "VSlider":
					result ~= tab ~ "VSlider " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new VSlider(" ~ to!string(t0.expectTagValue!int("barLength")) ~ ", " ~ to!string(t0.expectTagValue!int("maxValue")) 
							~ ", \"" ~ t0.expectTagValue!string("source") ~ "\", " ~ coordinate ~ ");\n";
					break;
				case "HSlider":
					result ~= tab ~ "HSlider " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new HSlider(" ~ to!string(t0.expectTagValue!int("barLength")) ~ ", " ~ to!string(t0.expectTagValue!int("maxValue")) 
							~ ", \"" ~ t0.expectTagValue!string("source") ~ "\", " ~ coordinate ~ ");\n";
					break;
				case "MenuBar":
					result ~= tab ~ "MenuBar " ~ t0.expectTagValue!string("name") ~ ";\n";
					ctor ~= tab ~ tab ~ t0.expectTagValue!string("name") ~ " = new MenuBar(" ~ ", \"" ~ t0.expectTagValue!string("source") ~ "\", " ~ coordinate ~ 
							generateCodeForMenubarElements(t0.expectTag("elements")) ~ ");\n";
					break;
				default:
					break;
			}
		}
		result ~= ctor ~ tab ~ "}\n}";
		write(path, result);
	}
	/**
	 * Generates the menubar elements into string
	 */
	public string generateCodeForMenubarElements(Tag t){
		if(t){
			string result = "[";
			foreach(Tag t0 ; t.tags){
				string secondaryText = t0.getTagValue!string("secondaryText", "null");
				string foo = secondaryText == "null" ? "" : "\"";
				result ~= "new PopUpMenuElement(\"" ~ t0.expectTagValue!string("source") ~ "\", \"" ~ t0.expectTagValue!string("text") ~ "\", " ~ foo ~ secondaryText ~ foo ~ "," ~
						generateCodeForMenubarElements(t0.getTag("elements")) ~ ");\n";
			}
			return result ~ "]";
		}else
			return "null";
	}
	/**
	 * Changes the title of the Window
	 */
	public void setWindowTitle(wstring s){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "title"){
						t1.values[0] = Value(toUTF8(s));
						return;
					}
				}
				return;
			}
		}
	}
	/**
	 * Adds an extrabutton
	 */
	public void addExtraButton(string s){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "extraButton"){
						t1.add(Value(s));
						return;
					}
				}
				return;
			}
		}
	}
	/**
	 * Removes an extrabutton
	 */
	public void removeExtraButton(string s){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "extraButton"){
						Value[] v;
						foreach(Value v0; t1.values){
							if(v0 != s){
								v ~= v0;
							}
						}
						t1.values = v;
						return;
					}
				}
				return;
			}
		}
	}
	/**
	 *
	 */
	public void addWindowElement(string type, string name, wstring text, Coordinate position){
		string utf8text = toUTF8(text);
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "elements"){
						Tag t2 = new Tag(t1, null, type);
						//new Tag(t2, null, "position", [Value(position.top),Value(position.left),Value(position.bottom),Value(position.right)]);
						new Tag(t2, "Coordinate", "top", [Value(position.top)]);
						new Tag(t2, "Coordinate", "left", [Value(position.left)]);
						new Tag(t2, "Coordinate", "bottom", [Value(position.bottom)]);
						new Tag(t2, "Coordinate", "right", [Value(position.right)]);
						new Tag(t2, null, "source", [Value(name)]);
						new Tag(t2, null, "name", [Value(name)]);
						switch(type){
							case "Label" , "TextBox", "CheckBox":
								new Tag(t2, null, "text", [Value(utf8text)]);
								break;
							case "Button":
								new Tag(t2, null, "text", [Value(utf8text)]);
								new Tag(t2, null, "icon", [Value("NULL")]);
								break;
							case "SmallButton":
								new Tag(t2, null, "iconPressed", [Value("NULL")]);
								new Tag(t2, null, "iconUnpressed", [Value("NULL")]);
								break;
							case "ListBox":
								new Tag(t2, null, "rowHeight", [Value(16)]);
								Tag t3 = new Tag(t2, null, "header");
								new Tag(t3, null, "column", [Value("Col0"), Value(40)]);
								new Tag(t3, null, "column", [Value("Col1"), Value(40)]);
								break;
							case "RadioButtonGroup":
								new Tag(t2, null, "text", [Value(utf8text)]);
								new Tag(t2, null, "rowHeight", [Value(16)]);
								//new Tag(t2, null, "header");
								new Tag(t2, null, "options", [Value("option0"), Value("option1")]);
								break;
							case "HSlider" , "VSlider":
								new Tag(t2, null, "maxValue", [Value(10)]);
								new Tag(t2, null, "barLength", [Value(1)]);
								break;
							case "Menubar":
								new Tag(t2, null, "elements");
								break;
							default:
								break;
						}
					}
				}
			}
		}
		writeln(root.toSDLDocument());
	}
	//template typeOf(T){
	public void editElementAttribute(string eName, string attrName, wstring value){
		if(eName == windowName){
			Tag t1 = root.expectTag("Window");
			foreach(foo; t1.namespaces){
				foreach(Tag t3; foo.tags){
					if(t3.getFullName().toString() == attrName){
						if(attrName == "title"){
							t3.values[0] = Value(toUTF8(value));
						}else if(t3.values[0].convertsTo!int()){
							t3.values[0] = Value(to!int(value));
						}else{
							t3.values[0] = Value(to!string(value));
						}
					}
				}	
			}
		}else{
			Tag t1 = root.expectTag("Window").expectTag("elements");
			foreach(Tag t2; t1.tags){
				if(t2.getTagValue!string("name") == eName){
					foreach(foo; t2.namespaces){
						foreach(Tag t3; foo.tags){
							if(t3.getFullName().toString() == attrName){
								if(attrName == "text"){
									t3.values[0] = Value(toUTF8(value));
								}else if(t3.values[0].convertsTo!int()){
									t3.values[0] = Value(to!int(value));
								}else{
									t3.values[0] = Value(to!string(value));
								}
							}
						}
					}
				}
			}
		}
	}
	//}
				
	public void removeElement(string eName){
		foreach(Tag t0; root.expectTag("Window").expectTag("elements").tags){
			if(t0.getTagValue!string("name") == eName){
				t0.remove();
				return;
			}
		}
	}
	public ElementParameter[] getElementAttributes(string eName){
		ElementParameter[] result;
		if(eName == windowName){
			Tag t1 = root.expectTag("Window");
			foreach(Tag t3; t1.tags){
				ElementParameter e = new ElementParameter();
				if(t3.getFullName().toString() != "elements"){
					e.name = to!string(t3.getFullName().toString());
					if(e.name == "title"){
						e.type = ElementValueParameter.Text;
						e.text = toUTF16(t3.getValue!string());
					}else if(t3.values.length == 1){
						if(t3.values[0].convertsTo!string()){
							e.type = ElementValueParameter.Description;
							e.text = to!wstring(t3.getValue!string());
						}else if(t3.values[0].convertsTo!int()){
							e.type = ElementValueParameter.Numeric;
							e.numeric = t3.getValue!int();
						}
					}else{
						e.type = ElementValueParameter.OpensANewWindow;
						e.text = "...";
					}
					result ~= e;
				}
			}
			return result;
		}
		
		Tag t1 = root.expectTag("Window").expectTag("elements");
		foreach(Tag t2; t1.tags){
			if(t2.getTagValue!string("name") == eName){
				foreach(foo; t2.namespaces){
					foreach(Tag t3; foo.tags){
						ElementParameter e = new ElementParameter();
						e.name = t3.getFullName().toString();
						if(e.name == "text"){
							e.type = ElementValueParameter.Text;
							e.text = toUTF16(t3.getValue!string());
						}else if(t3.values.length == 1 && (t3.getFullName().name != "options" || t3.getFullName().name != "elements" || t3.getFullName().name != "header")){
							if(t3.values[0].convertsTo!string()){
								e.type = ElementValueParameter.Description;
								e.text = to!wstring(t3.getValue!string());
							}else if(t3.values[0].convertsTo!int()){
								e.type = ElementValueParameter.Numeric;
								e.numeric = t3.getValue!int();
							}
						}else{
							e.type = ElementValueParameter.OpensANewWindow;
							e.text = "<...>";
						}
						result ~= e;
					}
				}
			}
		}
		return result;
	}
	public wstring[2][] getElements(){
		wstring[2][] result;
		wstring[2] subresult;
		subresult[0] = to!wstring(windowName);
		subresult[1] = "Window";
		result ~= subresult;
		Tag t1 = root.expectTag("Window").expectTag("elements");

		foreach(Tag t2; t1.tags){
			subresult[1] = to!wstring((t2.name));
			subresult[0] = to!wstring(t2.getTagValue!string("name"));
			result ~= subresult;
		}
		//writeln(result);
				
		return result;
	}
	private void generateStyleSheet(Tag t){
		new Tag(t, "StyleSheet", "font");
		new Tag(t, "StyleSheet", "windowAscent");
		new Tag(t, "StyleSheet", "windowDescent");
	}
}
public class WindowDataException : Exception{
	public this(string msg, string file = __FILE__, size_t line =  __LINE__, Throwable next = null) {
		super(msg, file, line, next);
	}
}