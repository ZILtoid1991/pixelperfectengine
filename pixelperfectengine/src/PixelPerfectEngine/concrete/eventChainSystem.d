module PixelPerfectEngine.concrete.eventChainSystem;
/**
 * Defines an undoable event.
 */
public interface UndoableEvent{
	public abstract void redo();	///called both when a redo command is initialized or the event is added to the stack.
	public abstract void undo();	///called when an undo command is initialized on the stack.
}

/**
 * Implements an undoable event list with automatic handling of undo/redo commands
 */
public class UndoableStack{
	private UndoableEvent[] events;
	private size_t currentPos;

	public this(size_t maxElements){
		events.length = maxElements;
	}
	/**
	 * Adds an event to the top of the stack. If there are any undone events, they'll be lost. Bottom event is also lost.
	 */
	public void addToTop(UndoableEvent e){
		if(currentPos){
			events = events[currentPos..$];
		}
		e.redo;
		for(int i = events.length - 1 ; i > 0 ; i--){
			events[i] = events[i - 1];
		}
		events[0] = e;
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
	public void redo(){
		if(currentPos > 0){
			if(events[currentPos]){
				currentPos--;
				events[currentPos].redo;
			}
		}
	}
}