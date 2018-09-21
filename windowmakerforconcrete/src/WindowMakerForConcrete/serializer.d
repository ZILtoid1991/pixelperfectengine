module serializer;

import sdlang;
import editor;
import types;
import PixelPerfectEngine.graphics.common;
import std.utf;

public class WindowSerializer{
	Tag root;
	string filename;
	public this(string filename){
	
	}
	public void store(){
		
	}
	public void deserialize(DummyWindow dw){
		import PixelPerfectEngine.concrete.elements;
	}
	public void generateDCode(string output){
		
	}
	public void editValue(T)(string target, string property, string namespace = null, T value){
		
	}
	public T getValue(T)(string target, string property, string namespace = null){
	
	}
	public void removeValue(string target, string property, string namespace = null){
		
	}
	public void addElement(ElementType type, string name, Coordinate initPos){
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
			case ElementType.HScroll:
				t1 = new Tag(root, null, "HScroll", [Value(name)]);
				return;
			case ElementType.VScroll:
				t1 = new Tag(root, null, "VScroll", [Value(name)]);
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
	public void removeElement(string name){
		
	}
}