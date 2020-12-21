module PixelPerfectEngine.concrete.elements.scrollbar;

public import PixelPerfectEngine.concrete.elements.base;

abstract class ScrollBar : WindowElement{
	protected static enum 	PLUS_PRESSED = 1<<9;
	protected static enum 	MINUS_PRESSED = 1<<10;
	protected int _value, _maxValue, _barLength;
	public void delegate(Event ev) onScrolling;

	/**
	 * Returns the slider position.
	 */
	public @property int value() @nogc @safe pure nothrow const {
		return _value;
	}
	/**
	 * Sets the slider position, and redraws the slider.
	 * Returns the new slider position.
	 */
	public @property int value(int val) {
		if (val < _maxValue) _value = val;
		else _value = _maxValue;
		draw();
		return _value;
	}
	/**
	 * Returns the maximum value of the slider.
	 */
	public @property int maxValue() @nogc @safe pure nothrow const {
		return _maxValue;
	}
	/**
	 * Sets the new maximum value and bar lenght of the slider.
	 * Position is kept or lowered if maximum is reached.
	 */
	public @property int maxValue(int val) {
		const int iconSize = position.width < position.height ? position.width : position.height;
		const int length = position.width > position.height ? position.width : position.height;
		_maxValue = val;
		if (_value > _maxValue) _value = _maxValue;
		_barLength = (length - iconSize * 2) / _maxValue;
		return _maxValue;
	}
	/**
	 * Returns the length of the scrollbar.
	 */
	public @property int barLength() @nogc @safe pure nothrow const {
		return _barLength;
	}
}
/**
 * Vertical scroll bar.
 */
public class VertScrollBar : ScrollBar {
	//public int[] brush;

	//private int value, maxValue, barLength;

	public this(int maxValue, string source, Box position){
		this.position = position;
		this.source = source;
		_maxValue = maxValue;
		_barLength = (position.height - position.width * 2) / _maxValue;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		const int travelLength = position.height - position.width * 2 - _barLength;
		Box slider;
		slider.left = position.left;
		slider.right = position.right;
		slider.top = (travelLength / value) - (_barLength / 2);
		slider.bottom = (travelLength / value) + (_barLength / 2);
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		if (isFocused) {
			parent.drawBoxPattern(slider, ss.pattern["blackDottedLine"]);
		}
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage["ButtonUpB"] : ss.getImage["ButtonUpA"]);
		Point lower = position.cornerLL;
		lower.y -= position.width;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage["ButtonDownB"] : ss.getImage["ButtonDownA"]);
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.button == MouseButton.Left) {
			if (mce.y < position.width) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					if (_value > 0) _value--;
					flags |= MINUS_PRESSED;
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~MINUS_PRESSED;
				}
			} else if (mce.y >= position.height - position.width) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					if (_value < _maxValue) _value++;
					flags |= PLUS_PRESSED;
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~PLUS_PRESSED;
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.y - position.width - (_barLength / 2);
				if (newVal >= 0) {
					const int travelLength = position.height - position.width * 2 - _barLength;
					_value = nearbyint(travelLength / newVal);
					if (_value > _maxValue) _value = _maxValue;
				}
			}
		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (isPressed && mme.buttonState == 1 << MouseButton.Left) {
			_value += mme.relY;
			if (_value <= 0 ) _value = 0;
			else if (_value >= _maxValue) _value = _maxValue;
			draw;
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		_value += mwe.y;
		if (_value <= 0 ) _value = 0;
		else if (_value >= _maxValue) _value = _maxValue;
		draw;
		super.passMWE(mec, mwe);
	}
	
}
/**
 * Horizontal scrollbar.
 */
public class HorizScrollBar : ScrollBar {
	public this(int maxValue, string source, Box position){
		this.position = position;
		this.source = source;
		_maxValue = maxValue;
		_barLength = (position.height - position.width * 2) / _maxValue;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		const int travelLength = position.height - position.width * 2 - _barLength;
		Box slider;
		slider.top = position.top;
		slider.bottom = position.bottom;
		slider.left = (travelLength / value) - (_barLength / 2);
		slider.right = (travelLength / value) + (_barLength / 2);
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		if (isFocused) {
			parent.drawBoxPattern(slider, ss.pattern["blackDottedLine"]);
		}
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage["ButtonUpB"] : ss.getImage["ButtonUpA"]);
		Point lower = position.cornerLL;
		lower.y -= position.width;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage["ButtonDownB"] : ss.getImage["ButtonDownA"]);
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.button == MouseButton.Left) {
			if (mce.x < position.height) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					if (_value > 0) _value--;
					flags |= MINUS_PRESSED;
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~MINUS_PRESSED;
				}
			} else if (mce.y >= position.width - position.height) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					if (_value < _maxValue) _value++;
					flags |= PLUS_PRESSED;
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~PLUS_PRESSED;
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.y - position.height - (_barLength / 2);
				if (newVal >= 0) {
					const int travelLength = position.width - position.height * 2 - _barLength;
					_value = nearbyint(travelLength / newVal);
					if (_value > _maxValue) _value = _maxValue;
				}
			}
		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (isPressed && mme.buttonState == 1 << MouseButton.Left) {
			_value += mme.relX;
			if (_value <= 0 ) _value = 0;
			else if (_value >= _maxValue) _value = _maxValue;
			draw;
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		_value += mwe.x;
		if (_value <= 0 ) _value = 0;
		else if (_value >= _maxValue) _value = _maxValue;
		draw;
		super.passMWE(mec, mwe);
	}
}
