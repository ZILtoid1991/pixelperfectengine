module PixelPerfectEngine.concrete.eventChainSystem;
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
	public UndoableEvent[] events;
	protected size_t currentPos, currentCap, maxLength;

	public this(size_t maxElements) @safe pure nothrow{
		maxLength = maxElements;
		events.length = maxElements;
	}
	/**
	 * Adds an event to the top of the stack. If there are any undone events, they'll be lost. Bottom event is always lost.
	 */
	public void addToTop(UndoableEvent e){
		events = e ~ events[currentPos..$-1];
		events.length = maxLength;
		e.redo;
		currentPos = 0;
	}
	/**
	 * Undos top event.
	 */
	public void undo(){
		if(currentPos < events.length){
			if(events[currentPos]){
				events[currentPos].undo;
				currentPos++;
			}
		}
	}
	/**
	 * Redos top event.
	 */
	public void redo() {
		if(currentPos >= 0){
			if(events[currentPos]){
				currentPos--;
				events[currentPos].redo;
			}
		}
	}
	/**
	 * Returns the length of the current stack
	 */
	public size_t length() {
		return events.length;
	}
}
