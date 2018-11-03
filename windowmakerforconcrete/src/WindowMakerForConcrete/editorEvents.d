module editorEvents;

import std.stdio;

import editor;
import serializer;
import types;
import sdlang;

public import PixelPerfectEngine.concrete.eventChainSystem;
import PixelPerfectEngine.concrete.elements;

public static DummyWindow dwtarget;
public static WindowSerializer wserializer;
public static Editor editorTarget;

public class PlacementEvent : UndoableEvent{
	private WindowElement element;
	private ElementType type;
	private string name;
	private Tag backup;
	public this(WindowElement element, ElementType type, string name){
		this.element = element;
		this.type = type;
		this.name = name;
	}
	public void redo(){
		try{
			wserializer.addElement(type, name, element.position);
			dwtarget.addElement(element, 0);
			editorTarget.elements[name] = element;
		}catch(Exception e){
			writeln(e);
		}
	}
	public void undo(){
		backup = wserializer.removeElement(name);
		dwtarget.removeElement(element);
		editorTarget.elements.remove(name);
	}
}

public class DeleteEvent : UndoableEvent{
	private string name;
	private Tag backup;
	public this(string name){
		this.name = name;
	}
	public void redo(){
		backup = wserializer.removeElement(name);
	}
	public void undo(){
		try{
			wserializer.addElement(backup);
		}catch(Exception e){
			writeln(e);
		}
	}
}

public class AttributeEditEvent : UndoableEvent{
	private Value[] oldVal, newVal;
	private string attributeName, targetName;
	public this(Value[] newVal, string attributeName, string targetName){
		this.newVal = newVal;
		this.attributeName = attributeName;
		this.targetName = targetName;
	}
	public void redo(){
		oldVal = wserializer.editValue(targetName, attributeName, newVal);
	}
	public void undo(){
		wserializer.editValue(targetName, attributeName, oldVal);
	}
}

public class WindowAttributeEditEvent : UndoableEvent{
	private Value[] oldVal, newVal;
	private string attributeName;
	public this(string attributeName, Value[] newVal){
		this.attributeName = attributeName;
		this.newVal = newVal;
	}
	public void redo(){
		oldVal = wserializer.editWindowValue(attributeName, newVal);
	}
	public void undo(){
		wserializer.editWindowValue(attributeName, oldVal);
	}
}

public class WindowRenameEvent : UndoableEvent{
	private string oldName, newName;
	public this(string newName){
		this.newName = newName;
	}
	public void redo(){
		oldName = wserializer.renameWindow(newName);
	}
	public void undo(){
		wserializer.renameWindow(oldName);
	}
}

public class RenameEvent : UndoableEvent{
	private string oldName, newName;
	public this(string oldName, string newName){
		this.oldName = oldName;
		this.newName = newName;
	}
	public void redo(){
		wserializer.renameElement(oldName, newName);
	}
	public void undo(){
		wserializer.renameElement(newName, oldName);
	}
}
