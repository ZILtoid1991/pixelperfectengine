module eventChainSystem.undoable;

public interface UndoableEvent{
	public void undo();
	public void redo();
	public bool isUndone();
}