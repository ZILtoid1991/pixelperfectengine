module windowDataLoader;

import sdlang;
import app;
import PixelPerfectEngine.graphics.common;

import std.conv;
import std.variant;

public class WindowData {
	private Tag root; /// Stores all the data
	private string filename;
	public this(){
		
	}
	public this(string filename){
		this.filename = filename;
	}
	public DummyWindow deserialize(string path = filename){
		root = parseFile(path);
		DummyWindow result = new DummyWindow(Coordinate(0, 0, root.getTag("Window").getTag("size").values[0].get!int(), root.getTag("Window").getTag("size").values[1].get!int()), to!wstring(root.getTag("Window").getTagValue!string("title")));
		return result;
	}
	public void serialize(string path = filename){
		import std.file;
		string data = root.toSDLDocument();
		std.file.write(path, data);
	}
	public void exportToDLangFile(string path){
		
	}
	/**
	 * Resizes the Window
	 */
	public void resizeWindow(int x, int y){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "size"){
						t1.values[0] = Value(x);
						t1.values[1] = Value(y);
						return;
					}
				}
				return;
			}
		}
	}
	/**
	 * Renames the Window
	 */
	public void renameWindow(string s){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "name"){
						t1.values[0] = Value(s);
						
						return;
					}
				}
				return;
			}
		}
	}
	/**
	 * Changes the title of the Window
	 */
	public void setWindowTitle(string s){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "title"){
						t1.values[0] = Value(s);
						
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
	public void addWindowElement(string type, string name, Coordinate position){
		foreach(Tag t0; root.tags){
			if(t0.name() == "Window"){
				foreach(Tag t1; t0.tags){
					if(t1.name == "elements"){
						Tag t2 = new Tag(t1, null, type, [Value(name)]);
						new Tag(t2, null, "position", [Value(position.top),Value(position.left),Value(position.bottom),Value(position.right)]);
						new Tag(t2, null, "source", [Value(name)]);
						switch(type){
							case "Label" , "TextBox", "CheckBox":
								new Tag(t2, null, "text", [Value(name)]);
								break;
							case "Button":
								new Tag(t2, null, "text", [Value(name)]);
								new Tag(t2, null, "icon");
								break;
							case "SmallButton":
								new Tag(t2, null, "iconPressed");
								new Tag(t2, null, "iconUnpressed");
								break;
							case "ListBox":
								new Tag(t2, null, "rowHeight");
								new Tag(t2, null, "header");
								break;
							case "RadioButtonGroup":
								new Tag(t2, null, "text", [Value(name)]);
								new Tag(t2, null, "rowHeight");
								new Tag(t2, null, "header");
								new Tag(t2, null, "options");
								break;
							default:
								break;
						}
					}
				}
			}
		}
	}
}