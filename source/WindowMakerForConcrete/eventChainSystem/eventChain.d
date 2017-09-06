module eventChainSystem.eventChain;

import std.algorithm.mutation;

import eventChainSystem.undoable;

public class EventChainSystem{
	protected UndoableEvent[] eventList;
	protected int topEvent, maxEventNumber;
	public this(int maxEventNumber){
		this.maxEventNumber = maxEventNumber;
		topEvent = -1;
	}
	/**
	 * Undos the top event in the list indicated by the internal variable, topEvent. If topEvent equals -1, it does nothing.
	 */
	public void undoTopEvent(){
		if(topEvent >= 0){
			eventList[topEvent].undo();
			topEvent--;
		}
	}
	/**
	 * Redos the last undone event in the list indicated by the internal variable, topEvent. If topEvent equals the number of current events, it does nothing.
	 */
	public void redoTopEvent(){
		if(topEvent < eventList.length){
			eventList[topEvent].redo();
			topEvent++;
		}
	}
	/**
	 * Undos the event indicated by i in the list.
	 */
	public void undoEventAtGivenPosition(int i){
		if(i < eventList.length)
			eventList[i].undo();
	}
	/**
	 * Redos the event indicated by i in the list.
	 */
	public void redoEventAtGivenPosition(int i){
		if(i < eventList.length)
			eventList[i].redo();
	}
	/**
	 * Appends an event on the top. If the maximum event number is reached, it deletes the oldest one.
	 */
	public void appendEvent(UndoableEvent e){
		if(eventList.length < maxEventNumber){
			eventList ~= e;
			topEvent++;
		}else{
			eventList = eventList[1..eventList.length] ~ e;
		}
		/*if(position < eventList.length){
			swapAt(eventList, eventList.length-1, position);
		}*/
	}
	/**
	 * Sets the maximum number of events that can be stored.
	 */
	public void setLength(int i){
		maxEventNumber = i;
	}
	/**
	 * Gets the maximum number of events that can be stored.
	 */
	public int getMaxLength(){
		return maxEventNumber;
	}
	/**
	 * Sets the current number of events that are stored.
	 */
	public int getCurrentLength(){
		return eventList.length;
	}
	/**
	 * Removes the event stored at position indicated by i.
	 */
	public void removeEvent(int i){
		eventList = remove(eventList, i);
	}
}