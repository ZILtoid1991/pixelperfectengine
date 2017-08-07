module editEvents;

import eventChainSystem.undoable;

import std.variant;

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