module pixelperfectengine.concrete.elements.encoder;

public import pixelperfectengine.concrete.elements.base;

import std.math;

/** 
 * Implements a sliding encoder for various data-entry purposes.
 */
public class SlidingEncoder : WindowElement {
	protected Box			track;				///The track, where the slider resides.
	protected Bitmap8Bit	slider;				///The bitmap for the slider.
	protected Bitmap8Bit	background;			///The bitmap for the background.
	protected uint			_maxValue;			///The maximum value of this encoder.
	protected uint			_value;				///The current value of this encoder.
	protected uint			trackLength;		///The total usable length of the encoder in pixels.
	protected double		valRatio;			///Pixel-to-value ratio of the encoder.
	public EventDeleg		onValueChange;		///Called when the value is changed.
	/** 
	 * Creates an instance of a sliding encoder
	 * Params:
	 *   source = source string for events.
	 *   position = Determines where the encoder should be drawn on the window.
	 *   slider = Specifies the slider of the encoder.
	 *   background = Specifies the background of the encoder. should have the exact sizes as position.
	 *   track = Specifies where the track of the encoder is. Is relative toupper-left corner of position.
	 *   _maxValue = Maximum value that can be reached by this encoder.
	 */
	public this(string source, Box position, Bitmap8Bit slider, Bitmap8Bit background, Box track, uint _maxValue) {
		this.source = source;
		this.position = position;
		this.slider = slider;
		this.background = background;
		this.track = track;
		trackLength = track.height - (slider.height & ~1);
		this._maxValue = _maxValue;
		valRatio = trackLength / _maxValue;
	}
	public @property uint maxValue() @nogc @safe pure nothrow const {
		return _maxValue;
	}
	public @property uint maxValue(uint val) {
		_maxValue = val;
		valRatio = trackLength / _maxValue;
		if (_maxValue < _value)
			_value = _maxValue;
		draw();
		return _maxValue;
	}
	public @property uint value() @nogc @safe pure nothrow const {
		return _value;
	}
	public @property uint value(uint val) {
		_value = val;
		if (_maxValue < _value)
			_value = _maxValue;
		draw();
		return _value;
	}
	override public void draw() {
		if (parent is null || state == ElementState.Hidden) return;
		parent.bitBLT(position.cornerUL, background);
		const Point sliderpos = Point(position.left + track.left, position.top + track.top + cast(uint)(valRatio * _value));
		parent.bitBLT(sliderpos, slider);
		StyleSheet ss = getStyleSheet();
		if (isFocused) {
			const int textPadding = ss.drawParameters["horizTextPadding"];
			parent.drawBoxPattern(position - textPadding, ss.pattern["blackDottedLine"]);
		}
		if (state == ElementState.Disabled) {
			parent.bitBLTPattern(position, ss.getImage("ElementDisabledPtrn"));
		}
		if (onDraw !is null) {
			onDraw();
		}
	}
	public override void passMCE(MouseEventCommons mec, MouseClickEvent mce) {
		if (mce.button == MouseButtons.Left && track.isBetween(mce.x - position.left, mce.y - position.top)) {
			const int position = mce.x - position.left - (slider.height / 2);
			parent.requestFocus(this);
			if (position <= 0) value = 0;
			else if (position >= trackLength) value = _maxValue;
			else {
				value = cast(uint)nearbyint(value * valRatio);
			}
			if (onValueChange !is null)
				onValueChange(new Event(this, EventType.MouseScroll, SourceType.WindowElement));
		} else {
			super.passMCE(mec, mce);
		}
	}
	public override void passMME(MouseEventCommons mec, MouseMotionEvent mme) {
		if (onValueChange !is null)
			onValueChange(new Event(this, EventType.MouseScroll, SourceType.WindowElement));
	}
	public override void passMWE(MouseEventCommons mec, MouseWheelEvent mwe) {
		const int diff = mwe.x + cast(int)nearbyint(mwe.y / valRatio);
		value(_value + diff);
		if (onValueChange !is null)
			onValueChange(new Event(this, EventType.MouseScroll, SourceType.WindowElement));
	}
}
public class RotaryEncoder : WindowElement {
	protected Bitmap8Bit		dot;
	protected Bitmap8Bit		knob;

	override public void draw() {

	}
}