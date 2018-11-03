module serializer;

import sdlang;
import editor;
import types;
import PixelPerfectEngine.graphics.common;
import std.utf;

public class WindowSerializer{
	Tag root;
	string filename;
	public this(){
		root = new Tag(null, null);
	}
	public this(string filename){
		this.filename = filename;
	}
	public void store(string filename){
		this.filename = filename;
		store();
	}
	public void store(){

	}
	public void deserialize(DummyWindow dw, Editor e){

	}
	public void generateDCode(string output){

	}
	public Value[] editValue(string target, string property, Value[] val){
		Value[] result;
		foreach(t0; root.tags){
			if(t0.getValue!string() == target){
				result = t0.getTagValues(property);
				t0.getTag(property).values = val;
				return result;
			}
		}
		return result;
	}
	public Value[] getValue(string target, string property){
		foreach(t0; root.tags){
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
	public Value[] editWindowValue(string property, Value[] val){
		Value[] result = root.getTag("Window").getTag(property).values;
		root.getTag("Window").getTag(property).values = val;
		return result;
	}
	public Value[] getWindowValue(string property, Value[] val){
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
			case ElementType.ListBox:
				t1 = new Tag(root, null, "ListBox", [Value(name)]);
				new Tag(t1, "header", "text", [Value("col0"), Value("col1")]);
				new Tag(t1, "header", "width", [Value(64), Value(64)]);
				new Tag(t1, null, "rowHeight", [Value(16)]);
				return;
			case ElementType.RadioButtonGroup:
				t1 = new Tag(root, null, "RadioButtonGroup", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				new Tag(t1, null, "rowHeight", [Value(16)]);
				new Tag(t1, null, "options", [Value("opt0"), Value("opt1")]);
				return;
			case ElementType.CheckBox:
				t1 = new Tag(root, null, "CheckBox", [Value(name)]);
				new Tag(t1, null, "text", [Value(name)]);
				return;
			case ElementType.HSlider:
				t1 = new Tag(root, null, "HSlider", [Value(name)]);
				return;
			case ElementType.VSlider:
				t1 = new Tag(root, null, "VSlider", [Value(name)]);
				return;
			case ElementType.MenuBar:
				t1 = new Tag(root, null, "MenuBar", [Value(name)]);
				return;
			default:
				return;
		}
		new Tag(t1, null, "source", [Value(name)]);
		new Tag(t1, "position", "left", [Value(initPos.left)]);
		new Tag(t1, "position", "top", [Value(initPos.top)]);
		new Tag(t1, "position", "right", [Value(initPos.right)]);
		new Tag(t1, "position", "bottom", [Value(initPos.bottom)]);
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
