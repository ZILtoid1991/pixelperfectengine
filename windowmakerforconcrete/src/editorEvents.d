module editorEvents;

import std.stdio;
import std.utf : toUTF8, toUTF32;

import editor;
import serializer;
import types;
import sdlang;

public import pixelperfectengine.concrete.eventchainsystem;
import pixelperfectengine.concrete.elements;

import sdlang.token : Value;

public static DummyWindow dwtarget;
public static WindowSerializer wserializer;
public static Editor editorTarget;

public class PlacementEvent : UndoableEvent{
	private WindowElement element;
	private string type;
	private string name;
	private Tag backup;
	public this(WindowElement element, string type, string name){
		this.element = element;
		this.type = type;
		this.name = name;
	}
	public void redo(){
		try{
			wserializer.addElement(type, name, element.getPosition);
			dwtarget.addElement(element);
			editorTarget.elements[name] = ElementInfo(element, name, type);
		}catch(Exception e){
			writeln(e);
		}
		editorTarget.updateElementList;
	}
	public void undo(){
		backup = wserializer.removeElement(name);
		dwtarget.removeElement(element);
		editorTarget.elements.remove(name);
		editorTarget.updateElementList;
	}
}

public class DeleteEvent : UndoableEvent{
	private Tag backup;
	ElementInfo eleminfo;
	public this(ElementInfo eleminfo){
		this.eleminfo = eleminfo;
	}
	public void redo(){
		backup = wserializer.removeElement(eleminfo.name);
		dwtarget.removeElement(eleminfo.element);
		editorTarget.elements.remove(eleminfo.name);
		editorTarget.updateElementList;
	}
	public void undo(){
		try{
			wserializer.addElement(backup);
			dwtarget.addElement(eleminfo.element);
			editorTarget.elements[eleminfo.name] = eleminfo;
		}catch(Exception e){
			writeln(e);
		}
		editorTarget.updateElementList;
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

public class TextEditEvent : AttributeEditEvent{
	private dstring oldText, newText;
	public this(dstring newText, string targetName){
		this.newText = newText;
		this.oldText = editorTarget.elements[targetName].element.getText.text;
		super([Value(toUTF8(newText))], "text", targetName);
	}
	public override void redo(){
		super.redo;
		editorTarget.elements[targetName].element.setText(newText);
	}
	public override void undo(){
		super.undo;
		editorTarget.elements[targetName].element.setText(oldText);
	}
}

public class SourceEditEvent : AttributeEditEvent{
	//private string oldText, newText;
	public this(string newText, string targetName){
		super([Value(newText)], "source", targetName);
	}
}

public class PositionEditEvent : AttributeEditEvent{
	private Coordinate oldPos, newPos;
	public this(Coordinate newPos, string targetName){
		this.newPos = newPos;
		this.oldPos = editorTarget.elements[targetName].element.getPosition;
		super([Value(newPos.left), Value(newPos.top), Value(newPos.right), Value(newPos.bottom)], "position", targetName);
	}
	public override void redo(){
		super.redo;
		editorTarget.elements[targetName].element.setPosition(newPos);
		dwtarget.draw;
	}
	public override void undo(){
		super.undo;
		editorTarget.elements[targetName].element.setPosition(newPos);
		dwtarget.draw;
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

public class WindowRetitleEvent : WindowAttributeEditEvent{
	private dstring oldTitle, newTitle;
	public this(dstring title){
		newTitle = title;
		super("title", [Value(toUTF8(title))]);
		oldTitle = dwtarget.getTitle().text;
	}
	public override void redo(){
		dwtarget.setTitle(newTitle);
		super.redo;
	}
	public override void undo(){
		dwtarget.setTitle(oldTitle);
		super.undo;
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

public class WindowWidthChangeEvent : WindowAttributeEditEvent{
	private int oldWidth, newWidth;
	public this(int newWidth){
		this.newWidth = newWidth;
		super("size:x", [Value(newWidth)]);
		oldWidth = dwtarget.getPosition.width;
	}
	public override void redo(){
		dwtarget.setWidth(newWidth);
		super.redo;
	}
	public override void undo(){
		dwtarget.setWidth(oldWidth);
		super.undo;
	}
}

public class WindowHeightChangeEvent : WindowAttributeEditEvent{
	private int oldHeight, newHeight;
	public this(int newHeight){
		this.newHeight = newHeight;
		super("size:y", [Value(newHeight)]);
		oldHeight = dwtarget.getPosition.height;
	}
	public override void redo(){
		dwtarget.setHeight(newHeight);
		super.redo;
	}
	public override void undo(){
		dwtarget.setHeight(oldHeight);
		super.undo;
	}
}

public class RenameEvent : UndoableEvent {
	private string oldName, newName;
	private ElementInfo eleminfo, backup;
	public this(string oldName, string newName){
		this.oldName = oldName;
		this.newName = newName;
		eleminfo = editorTarget.elements[oldName];
		backup = eleminfo;
		eleminfo.name = newName;
	}
	public void redo(){
		wserializer.renameElement(oldName, newName);
		editorTarget.elements[newName] = eleminfo;
		editorTarget.elements.remove(oldName);
		editorTarget.updateElementList;
	}
	public void undo(){
		wserializer.renameElement(newName, oldName);
		editorTarget.elements[oldName] = backup;
		editorTarget.elements.remove(newName);
		editorTarget.updateElementList;
	}
}

public class MoveElemEvent : UndoableEvent {
	private Box oldPos, newPos;
	private string target;
	public this(Box newPos, Box oldPos, string target){
		this.newPos = newPos;
		this.oldPos = oldPos;
		this.target = target;
	}
	public this(Box newPos, string target){
		this.newPos = newPos;
		this.oldPos = editorTarget.elements[target].element.getPosition();
		this.target = target;
	}
	public void redo(){
		wserializer.editValue(target, "position", [Value(newPos.left), Value(newPos.top), Value(newPos.right), 
				Value(newPos.bottom)]);
		//oldPos = editorTarget.elements[target].position;
		editorTarget.elements[target].element.setPosition(newPos);
		dwtarget.draw();
	}
	public void undo(){
		wserializer.editValue(target, "position", [Value(oldPos.left), Value(oldPos.top), Value(oldPos.right), 
				Value(oldPos.bottom)]);
		editorTarget.elements[target].element.setPosition(oldPos);
		dwtarget.draw();
	}
}