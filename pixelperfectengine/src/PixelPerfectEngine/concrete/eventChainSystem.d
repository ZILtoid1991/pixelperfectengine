module PixelPerfectEngine.concrete.eventChainSystem;

import collections.linkedlist;
/**
 * Defines an undoable event.
 */
public interface UndoableEvent{
	public void redo();	///called both when a redo command is initialized or the event is added to the stack.
	public void undo();	///called when an undo command is initialized on the stack.
}

/**
 * Implements an undoable event list with automatic handling of undo/redo commands
 */
public class UndoableStack{
	alias EventStack = LinkedList!(UndoableEvent);
	protected EventStack events;
	protected size_t currentPos, currentCap, maxLength;

	public this(size_t maxElements) @safe pure nothrow{
		maxLength = maxElements;
		//events.length = maxElements;
	}
	/**
	 * Adds an event to the top of the stack. If there are any undone events, they'll be lost. Bottom event is always lost.
	 */
	public void addToTop(UndoableEvent e){
		while(currentPos) {
			events.remove(0);
			currentPos--;
		}
		events.insertAt(e, 0);
		e.redo;
		while(events.length > maxLength) events.remove(maxLength);
	}
	/**
	 * Undos top event.
	 */
	public void undo(){
		if(currentPos < events.length){
			events[currentPos].undo;
			currentPos++;
		}
	}
	/**
	 * Redos top event.
	 */
	public void redo() {
		if(currentPos >= 0){
			currentPos--;
			events[currentPos].redo;
		}
	}
	/**
	 * Returns the length of the current stack
	 */
	public size_t length() {
		return events.length;
	}
}
