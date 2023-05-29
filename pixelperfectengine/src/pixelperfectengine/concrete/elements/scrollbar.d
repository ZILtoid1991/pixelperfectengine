module pixelperfectengine.concrete.elements.scrollbar;

public import pixelperfectengine.concrete.elements.base;
import std.math : isNaN, nearbyint;
import pixelperfectengine.system.timer;

abstract class ScrollBar : WindowElement{
	protected static enum 	PLUS_PRESSED = 1<<9;
	protected static enum 	MINUS_PRESSED = 1<<10;
	protected static enum 	SCROLLMATIC = 1<<11;
	protected int _value, _maxValue, _barLength;
	public int				scrollSpeed = 1;			///Sets the scrollspeed for the given instance, can be useful for large number of items.
	//protected double largeVal;							///Set to double.nan if value is less than travellength, or the ratio between 
	protected double valRatio;							///Ratio between the travel length and the maximum value
	protected double barLength0;
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
		assert(val >= 0, "Value must be positive!");
		const int iconSize = position.width < position.height ? position.width : position.height;
		const int length = position.width > position.height ? position.width : position.height;
		_maxValue = val;
		if (_value > _maxValue) _value = _maxValue;
		barLength0 = (length - iconSize * 2) / cast(double)(val + 1);
		_barLength = barLength0 < 1.0 ? 1 : cast(int)nearbyint(barLength0);
		//largeVal = barLength0 < 1.0 ? 1.0 / barLength0 : double.nan;
		valRatio = 1.0 / barLength0;
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
	protected void timerEvent(Duration jitter) nothrow {
		try {
			if (flags & PLUS_PRESSED) {
				value = value + 1;
				draw;
				flags |= SCROLLMATIC;
				registerTimer();
			} else if (flags & MINUS_PRESSED) {
				value = value - 1;
				draw;
				flags |= SCROLLMATIC;
				registerTimer();
			}
		} catch (Exception e) {

		}
	}
	protected void registerTimer() nothrow {
		timer.register(&timerEvent, msecs(flags & SCROLLMATIC ? 50 : 1000));
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
		if (parent is null) return;
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		//const int travelLength = position.height - (position.width * 2) - _barLength;
		Box slider;
		//const int value0 = valRatio < 1.0 ? value : cast(int)(value / valRatio);
		slider.left = position.left;
		slider.right = position.right;
		slider.top = position.top + position.width + cast(int)nearbyint(barLength0 * _value);
		slider.bottom = slider.top + _barLength;
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage("upArrowB") : ss.getImage("upArrowA"));
		Point lower = position.cornerLL;
		lower.y -= position.width;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage("downArrowB") : ss.getImage("downArrowA"));
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		/+if (isFocused) {
			parent.drawBoxPattern(position, ss.pattern["blackDottedLine"]);
		}+/
		if (onDraw !is null) {
			onDraw();
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (state != ElementState.Enabled) return;
		mce.x -= position.left;
		mce.y -= position.top;
		if (mce.button == MouseButton.Left) {
			if (mce.y < position.width) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value - 1;
					flags |= MINUS_PRESSED;
					registerTimer();
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~(MINUS_PRESSED | SCROLLMATIC);
				}
			} else if (mce.y >= position.height - position.width) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value + 1;
					flags |= PLUS_PRESSED;
					registerTimer();
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~(PLUS_PRESSED | SCROLLMATIC);
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.y - position.width - (_barLength / 2.0);
				if (newVal >= 0) {
					//const int travelLength = position.height - (position.width * 2) - _barLength;
					//const double valRatio = isNaN(largeVal) ? 1.0 : largeVal;
					//value = cast(int)nearbyint((travelLength / newVal) * valRatio);
					value = cast(int)nearbyint((newVal) * valRatio);
				}
			}
		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (state != ElementState.Enabled) return;
		if (mme.buttonState == MouseButtonFlags.Left && mme.y > position.height && mme.y < position.width - position.height) {
			import std.math : nearbyint;
			const double newVal = mme.y - position.width - (_barLength / 2.0);
			if (newVal >= 0)
				value = cast(int)nearbyint((newVal) * valRatio);
			//value = _value = mme.relY;
			//draw();
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (state != ElementState.Enabled) return;
		value = _value - mwe.y * scrollSpeed;
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
		if (parent is null) return;
		StyleSheet ss = getStyleSheet();
		//draw background
		parent.drawFilledBox(position, ss.getColor("SliderBackground"));
		//draw slider
		//const int travelLength = position.width - position.height * 2;
		const int value0 = valRatio < 1.0 ? value : cast(int)(value / valRatio);
		Box slider;
		slider.top = position.top;
		slider.bottom = position.bottom;
		slider.left = position.left + position.height + cast(int)nearbyint(barLength0 * value0);
		slider.right = slider.left + _barLength;
		parent.drawFilledBox(slider, ss.getColor("SliderColor"));
		
		//draw buttons
		parent.bitBLT(position.cornerUL, flags & MINUS_PRESSED ? ss.getImage("leftArrowB") : ss.getImage("leftArrowA"));
		Point lower = position.cornerUR;
		lower.x -= position.height;
		parent.bitBLT(lower, flags & PLUS_PRESSED ? ss.getImage("rightArrowB") : ss.getImage("rightArrowA"));
		/+if (isFocused) {
			parent.drawBoxPattern(position, ss.pattern["blackDottedLine"]);
		}+/
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (state != ElementState.Enabled) return;
		mce.x -= position.left;
		mce.y -= position.top;
		if (mce.button == MouseButton.Left) {
			if (mce.x < position.height) {
				if (!(flags & MINUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value - 1;
					flags |= MINUS_PRESSED;
					registerTimer();
				} else if (flags & MINUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~MINUS_PRESSED;
				}
			} else if (mce.x >= position.width - position.height) {
				if (!(flags & PLUS_PRESSED) && mce.state == ButtonState.Pressed) {
					value = _value + 1;
					flags |= PLUS_PRESSED;
					registerTimer();
				} else if (flags & PLUS_PRESSED && mce.state == ButtonState.Released) {
					flags &= ~PLUS_PRESSED;
				}
			} else {
				import std.math : nearbyint;
				const double newVal = mce.x - position.height - (_barLength / 2.0);
				if (newVal >= 0) {
					//const int travelLength = position.width - position.height * 2 - _barLength;
					//const double valRatio = isNaN(largeVal) ? 1.0 : largeVal;
					//value = cast(int)nearbyint((travelLength / newVal) * valRatio);
					value = cast(int)nearbyint((newVal) * valRatio);
				}
			}
			flags &= ~SCROLLMATIC;

		} 
		super.passMCE(mec, mce);
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (state != ElementState.Enabled) return;
		if (mme.buttonState == MouseButtonFlags.Left && mme.x > position.width && mme.x < position.height) {
			/* value = _value + mme.relX;
			draw(); */
			import std.math : nearbyint;
			const double newVal = mme.x - position.height - (_barLength / 2.0);
			if (newVal >= 0)
				value = cast(int)nearbyint((newVal) * valRatio);
		}
		super.passMME(mec, mme);
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		if (state != ElementState.Enabled) return;
		value = _value + mwe.x * scrollSpeed;
		super.passMWE(mec, mwe);
	}
}
