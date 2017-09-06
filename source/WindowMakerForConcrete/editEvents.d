module editEvents;

public import eventChainSystem.undoable;
public import eventChainSystem.eventChain;

import PixelPerfectEngine.concrete.elements;

import std.variant;

import main;

public class ParameterChangeEvent : UndoableEvent{
	private bool undoneStatus;
	private string parameterName, targetObj;
	private Variant oldParam, newParam;
	public this(string parameterName, string targetObj, Variant param){
		
	}
	public void undo(){
		if(!undoneStatus){
		
		}
		undoneStatus = true;
	}
	public void redo(){
		if(undoneStatus){
		
		}
		undoneStatus = false;
	}
	public bool isUndone(){
		return undoneStatus;
	}
}

public class ObjectPlacementEvent : UndoableEvent{
	private bool undoneStatus;
	private WindowElement element;
	private string ID;
	public this(string ID, WindowElement element){
		this.ID = ID;
		this.element = element;
		mainApp.ewh.dw.addElement(element, 0);
	}
	public void undo(){
		if(!undoneStatus){
			mainApp.ewh.dw.removeElement(element);
		}
		mainApp.windowElements[ID] = element;
		undoneStatus = true;
	}
	public void redo(){
		if(undoneStatus){
			mainApp.ewh.dw.addElement(element, 0);
		}
		mainApp.windowElements.remove(ID);
		undoneStatus = false;
	}
	public bool isUndone(){
		return undoneStatus;
	}
}

