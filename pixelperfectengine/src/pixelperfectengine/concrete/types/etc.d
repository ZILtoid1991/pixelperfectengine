module pixelperfectengine.concrete.types.etc;

import std.bitmanip : bitfields;

import iota.controls.types;

/**
 * Defines various cursor types.
 * Should be compatible with the SDL cursor types.
 */
/* public enum CursorType {
	Arrow,
	IBeam,
	Wait,
	Crosshair,
	ArrowWait,
	ResizeNWSE,
	ResizeNESW,
	ResizeWE,
	ResizeNS,
	ResizeAll,
	No,
	Hand,
} */
/**
 * Defines what kind of characters can be inputted into a given text field.
 */
public enum TextInputFieldType {
	init,
	None = init,
	Text,
	ASCIIText,
	Decimal,
	Integer,
	DecimalP,
	IntegerP,
	Hex,
	Oct,
	Bin
}