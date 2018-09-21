module editorEvents;

import editor;

import PixelPerfectEngine.concrete.eventChainSystem;
import PixelPerfectEngine.concrete.elements;

public class PlacementEvent : UndoableEvent{
	public static DummyWindow target;
	private WindowElement element;
	public this(WindowElement element){
		this.element = element;
	}
	public void redo(){
		target.addElement(element, 0);
	}
	public void undo(){
		target.removeElement(element);
	}
}

public class AttributeEditEvent : UndoableEvent{
	public void redo(){
		
	}
	public void undo(){
		
	}
}