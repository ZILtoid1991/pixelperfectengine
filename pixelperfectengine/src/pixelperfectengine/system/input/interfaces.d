module pixelperfectengine.system.input.interfaces;

public import pixelperfectengine.system.input.types;
public import iota.controls.types : TextCommandEvent, Timestamp;

/**
 * Listener for keyboard, joystick, etc. events.
 */
public interface InputListener {
	/**
	 * Called when a key or button is pressed. (Digital buttons)
	 * Params:
	 *   id = ID of the event, MurMurHash3/32 hash of the name of the binding.
	 *   code = The full code for the binding used while looking up the ID.
	 *   timestamp = The time when the input event has been recorded, in microseconds.
	 *   isPressed = True if the key or button has been pressed, false otherwise.
	 *   device = The `iota` device that has created the event. See its documentation on how to use it to generate
	 * haptic feedback, etc. if needed.
	 * NOTE: Hat events on joysticks don't generate keyReleased events, instead they generate keyPressed events on
	 * getting centered.
	 */
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, bool isPressed, InputDevice device);
	/**
	 * Called when a key or button is pressed. (Analog buttons)
	 * Params:
	 *   id = ID of the event, MurMurHash3/32 hash of the name of the binding.
	 *   code = The full code for the binding used while looking up the ID.
	 *   timestamp = The time when the input event has been recorded, in microseconds.
	 *   pressure = The amount of how much the button is being pressed. 0.0 if fully released, 1.0 if fully pressed.
	 *   device = The `iota` device that has created the event. See its documentation on how to use it to generate
	 * haptic feedback, etc. if needed.
	 */
	public void keyEvent(uint id, BindingCode code, Timestamp timestamp, float pressure, InputDevice device);
	/**
	 * Called when an axis is being operated.
	 * Params:
	 *   id = ID of the event, MurMurHash3/32 hash of the name of the binding.
	 *   code = The full code for the binding used while looking up the ID.
	 *   timestamp = The time when the input event has been recorded, in microseconds.
	 *   value = The value of the axis, between -1.0 and +1.0.
	 *   device = The `iota` device that has created the event. See its documentation on how to use it to generate
	 * haptic feedback, etc. if needed.
	 */
	public void axisEvent(uint id, BindingCode code, Timestamp timestamp, float value, InputDevice device);
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
	 * Called if a window was resized.
	 * Params:
	 *   window = Handle to the OSWindow class.
	 *   width = active area width.
	 *   height = active area height.
	 */
	public void windowResize(OSWindow window, int width, int height);
	/**
	 * Called if a controller was added.
	 * The `id` input device defined by external package `iota`.
	 */
	public void inputDeviceAdded(InputDevice id);
	/**
	 * Called if a controller was removed.
	 * The `id` input device defined by external package `iota`.
	 */
	public void inputDeviceRemoved(InputDevice id);
}
/**
 * Called on text input events.
 */
public interface TextInputListener {
	/**
	 * Passes the inputted text to the target, alongside with a window ID and a timestamp.
	 */
	public void textInputEvent(Timestamp timestamp, OSWindow windowID, dstring text);
	/**
	 * Passes text editing events to the target, alongside with a window ID and a timestamp.
	 */
	public void textEditingEvent(Timestamp timestamp, OSWindow windowID, dstring text, int start, int length);
	/**
	 * Passes text input key events to the target, e.g. cursor keys.
	 */
	public void textInputKeyEvent(Timestamp timestamp, OSWindow windowID, TextCommandEvent command);
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
