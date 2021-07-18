module PixelPerfectEngine.concrete.elements.scrollbar;

public import PixelPerfectEngine.concrete.elements.base;
import std.math : isNaN;

abstract class ScrollBar : WindowElement{
	protected static enum 	PLUS_PRESSED = 1<<9;
	protected static enum 	MINUS_PRESSED = 1<<10;
	protected int _value, _maxValue, _barLength;
	protected double largeVal;							///Set to double.nan if value is less than travellength, or the ratio between 
	public void delegate(Event ev) onScrolling;			///Called shen the scrollbar's value is changed

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
		if (val < 0) _value = 0;
		else if (val < _maxValue) _value = val;
		else _value = _maxValue;
		draw();
		if (onScrolling !is null)
			onScrolling(new Event(this, EventType.MouseScroll, SourceType.WindowElement));
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
		const double barLength0 = (length - iconSize * 2) / cast(double)val;
		_barLength = barLength0 < 1.0 ? 1 : cast(int)barLength0;
		largeVal = barLength0 < 1.0 ? 1.0 / barLength0 : double.nan;
		return _maxValue;
	}
	/**
	 * Returns the length of the scrollbar in pixels.
	 *
	 * Automatically calculated every time maxValue is changed.
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
		this.maxValue = maxValue;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		//const int travelLength = position.height - (position.width * 2) - _barLength;
		Box slider;
		const int value0 = isNaN(largeVal) ? value : cast(int)(value / largeVal);
		slider.left = position.left;
		slider.right = position.right;
		slider.top = position.top + position.width + (_barLength * value0);
		slider.bottom = slider.top + _barLength;
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		if (isFocused) {
			parent.drawBoxPattern(slider, ss.pattern["blackDottedLine"]);
		}
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage("upArrowB") : ss.getImage("upArrowA"));
		Point lower = position.cornerLL;
		lower.y -= position.width;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage("downArrowB") : ss.getImage("downArrowA"));
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.button == MouseButton.Left) {
			if (mce.y < position.width) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value - 1;
					flags |= MINUS_PRESSED;
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~MINUS_PRESSED;
				}
			} else if (mce.y >= position.height - position.width) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value + 1;
					flags |= PLUS_PRESSED;
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~PLUS_PRESSED;
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.y - position.width - (_barLength / 2.0);
				if (newVal >= 0) {
					const int travelLength = position.height - (position.width * 2) - _barLength;
					const double valRatio = isNaN(largeVal) ? 1.0 : largeVal;
					value = cast(int)nearbyint((travelLength / newVal) * valRatio);
				}
			}
		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (isPressed && mme.buttonState == 1 << MouseButton.Left) {
			value = _value = mme.relY;
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		value = _value - mwe.y;
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
		this.maxValue = maxValue;
	}
	public override void draw(){
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		//const int travelLength = position.width - position.height * 2;
		const int value0 = isNaN(largeVal) ? value : cast(int)(value / largeVal);
		Box slider;
		slider.top = position.top;
		slider.bottom = position.bottom;
		slider.left = position.left + position.height + (_barLength * value0);
		slider.right = slider.left + _barLength;
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		if (isFocused) {
			parent.drawBoxPattern(slider, ss.pattern["blackDottedLine"]);
		}
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage("leftArrowB") : ss.getImage("leftArrowA"));
		Point lower = position.cornerUR;
		lower.x -= position.height;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage("rightArrowB") : ss.getImage("rightArrowA"));
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.button == MouseButton.Left) {
			if (mce.x < position.height) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value - 1;
					flags |= MINUS_PRESSED;
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~MINUS_PRESSED;
				}
			} else if (mce.x >= position.width - position.height) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value + 1;
					flags |= PLUS_PRESSED;
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~PLUS_PRESSED;
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.y - position.height - (_barLength / 2.0);
				if (newVal >= 0) {
					const int travelLength = position.width - position.height * 2 - _barLength;
					const double valRatio = isNaN(largeVal) ? 1.0 : largeVal;
					value = cast(int)nearbyint((travelLength / newVal) * valRatio);
				}
			}
		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (isPressed && mme.buttonState == 1 << MouseButton.Left) {
			value = _value + mme.relX;
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		value = _value + mwe.x;
		super.passMWE(mec, mwe);
	}
}
