module PixelPerfectEngine.system.input.interfaces;

public import PixelPerfectEngine.system.input.types;

/**
 * Listener for keyboard, joystick, etc. events.
 */
public interface InputListener {
	/**
	 * Called when a keybinding event is generated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on release.
	 */
	public void keyEvent(uint id, BindingCode code, uint timestamp, bool isPressed);
	/**
	 * Called when an axis is being operated.
	 * The `id` should be generated from a string, usually the name of the binding.
	 * `code` is a duplicate of the code used for fast lookup of the binding, which also contains other info (deviceID, etc).
	 * `timestamp` is the time lapsed since the start of the program, can be used to measure time between keypresses.
	 * `value` is the current position of the axis normalized between -1.0 and +1.0 for joysticks, and 0.0 and +1.0 for analog
	 * triggers.
	 */
	public void axisEvent(uint id, BindingCode code, uint timestamp, float value);
}
/**
 * Listener for system events. Controller adding and removal, quiting the application, etc.
 */
public interface SystemEventListener {
	/**
	 * Called if the window is being closed.
	 */
	public void onQuit();
	/**
	 * Called if a controller was added.
	 */
	public void controllerAdded(uint id);
	/**
	 * Called if a controller was removed.
	 */
	public void controllerRemoved(uint id);
}
/**
 * Called on text input events.
 */
public interface TextInputListener {
	/**
	 * Passes the inputted text to the target, alongside with a window ID and a timestamp.
	 */
	public void textInputEvent(uint timestamp, uint windowID, dstring text);
	/**
	 * Passes text editing events to the target, alongside with a window ID and a timestamp.
	 */
	public void textEditingEvent(uint timestamp, uint windowID, dstring text, int start, int length);
	/**
	 * Passes text input key events to the target, e.g. cursor keys.
	 */
	public void textInputKeyEvent(uint timestamp, uint windowID, TextInputKey key, ushort modifier);
	/**
	 * When called, the listener should drop all text input.
	 */
	public void dropTextInput();
	/**
	 * Called if text input should be initialized.
	 */
	public void initTextInput();
}
/**
 * Called on mouse events
 */
public interface MouseListener {
	/**
	 * Called on mouse click events.
	 */
	public void mouseClickEvent(MouseEventCommons mec, MouseClickEvent mce);
	/**
	 * Called on mouse wheel events.
	 */
	public void mouseWheelEvent(MouseEventCommons mec, MouseWheelEvent mwe);
	/**
	 * Called on mouse motion events.
	 */
	public void mouseMotionEvent(MouseEventCommons mec, MouseMotionEvent mme);
}