module PixelPerfectEngine.system.input.scancode;

/**
 * USB HID compatible keyboard scancodes.
 */
public enum ScanCode : uint {
	A				=	4,
	B				=	5,
	C				=	6,
	D				=	7,
	E				=	8,
	F				=	9,
	G				=	10,
	H				=	11,
	I				=	12,
	J				=	13,
	K				=	14,
	L				=	15,
	M				=	16,
	N				=	17,
	O				=	18,
	P				=	19,
	Q				=	20,
	R				=	21,
	S				=	22,
	T				=	23,
	U				=	24,
	V				=	25,
	W				=	26,
	X				=	27,
	Y				=	28,
	Z				=	29,

	n1				=	30,
	n2				=	31,
	n3				=	32,
	n4				=	33,
	n5				=	34,
	n6				=	35,
	n7				=	36,
	n8				=	37,
	n9				=	38,
	n0				=	39,

	ENTER			=	40,
	ESCAPE			=	41,
	BACKSPACE		=	42,
	TAB				=	43,
	SPACE			=	44,

	MINUS			=	45,
	EQUALS			=	46,
	LEFTBRACKET		=	47,
	RIGHTBRACKET	=	48,
	BACKSLASH		=	49,
	NONUSLASH		=	50,
	SEMICOLON		=	51,
	APOSTROPHE		=	52,
	GRAVE			=	53,
	COMMA			=	54,
	PERIOD			=	55,
	SLASH			=	56,
	CAPSLOCK		=	57,

	F1				=	58,
	F2				=	59,
	F3				=	60,
	F4				=	61,
	F5				=	62,
	F6				=	63,
	F7				=	64,
	F8				=	65,
	F9				=	66,
	F10				=	67,
	F11				=	68,
	F12				=	69,

	PRINTSCREEN		=	70,
	SCROLLLOCK		=	71,
	PAUSE			=	72,
	INSERT			=	73,
	HOME			=	74,
	PAGEUP			=	75,
	DELETE			=	76,
	END				=	77,
	PAGEDOWN		=	78,
	RIGHT			=	79,
	LEFT			=	80,
	DOWN			=	81,
	UP				=	82,

	NUMLOCK			=	83,
	NP_DIVIDE		=	84,
	NP_MULTIPLY		=	85,
	NP_MINUS		=	86,
	NP_PLUS			=	87,
	NP_ENTER		=	88,

	np1				=	89,
	np2				=	90,
	np3				=	91,
	np4				=	92,
	np5				=	93,
	np6				=	94,
	np7				=	95,
	np8				=	96,
	np9				=	97,
	np0				=	98,

	NP_PERIOD		=	99,

	NONUSBACKSLASH	=	100,
	APPLICATION		=	101,

	NP_EQUALS		=	102,

	F13				=	104,
	F14				=	105,
	F15				=	106,
	F16				=	107,
	F17				=	108,
	F18				=	109,
	F19				=	110,
	F20				=	111,
	F21				=	112,
	F22				=	113,
	F23				=	114,
	F24				=	115,

	EXECUTE			=	116,
	HELP			=	117,
	MENU			=	118,
	SELECT			=	119,
	STOP			=	120,
	REDO			=	121,
	UNDO			=	122,
	CUT				=	123,
	COPY			=	124,
	PASTE			=	125,
	FIND			=	126,
	MUTE			=	127,
	VOLUME_UP		=	128,
	VOLUME_DOWN		=	129,

	NP_COMMA		=	133,
	NP_EQUALSAS400	=	134,

	INTERNATIONAL1	=	135,
	INTERNATIONAL2	=	136,
	INTERNATIONAL3	=	137,
	INTERNATIONAL4	=	138,
	INTERNATIONAL5	=	139,
	INTERNATIONAL6	=	140,
	INTERNATIONAL7	=	141,
	INTERNATIONAL8	=	142,
	INTERNATIONAL9	=	143,

	LANGUAGE1		=	144,
	LANGUAGE2		=	145,
	LANGUAGE3		=	146,
	LANGUAGE4		=	147,
	LANGUAGE5		=	148,
	LANGUAGE6		=	149,
	LANGUAGE7		=	150,
	LANGUAGE8		=	151,
	LANGUAGE9		=	152,

	ALTERASE		=	153,
	SYSREQ			=	154,
	CANCEL			=	155,
	PRIOR			=	157,
	ENTER2			=	158,
	SEPARATOR		=	159,
	OUT				=	160,
	OPERATE			=	161,
	CLEARAGAIN		=	162,
	CRSEL			=	163,
	EXSEL			=	164,

	NP00			=	176,
	NP000			=	177,
	THROUSANDSEPAR	=	178,
	HUNDREDSSEPAR	=	179,
	CURRENCYUNIT	=	180,
	CURRENCYSUBUNIT	=	181,
	NP_LEFTPAREN	=	182,
	NP_RIGHTPAREN	=	183,
	NP_LEFTBRACE	=	184,
	NP_RIGHTBRACE	=	185,
	NP_TAB			=	186,
	NP_BACKSPACE	=	187,
	NP_A			=	188,
	NP_B			=	189,
	NP_C			=	190,
	NP_D			=	191,
	NP_E			=	192,
	NP_F			=	193,
	NP_XOR			=	194,
	NP_POWER		=	195,
	NP_PERCENT		=	196,
	NP_LESS			=	197,
	NP_GREATER		=	198,
	NP_AMPERSAND	=	199,
	NP_DBAMPERSAND	=	200,
	NP_VERTICALBAR	=	201,
	NP_DBVERTICALBAR=	202,
	NP_COLON		=	203,
	NP_HASH			=	204,
	NP_SPACE		=	205,
	NP_AT			=	206,
	NP_EXCLAM		=	207,
	NP_MEMSTORE		=	208,
	NP_MEMRECALL	=	209,
	NP_MEMCLEAR		=	210,
	NP_MEMADD		=	211,
	NP_MEMSUBSTRACT	=	212,
	NP_MEMMULTIPLY	=	213,
	NP_MEMDIVIDE	=	214,
	NP_PLUSMINUS	=	215,
	NP_CLEAR		=	216,
	NP_CLEARENTRY	=	217,
	NP_BINARY		=	218,
	NP_OCTAL		=	219,
	NP_DECIMAL		=	220,
	NP_HEXADECIMAL	=	221,

	LCTRL			=	224,
	LSHIFT			=	225,
	LALT			=	226,
	LGUI			=	227,
	RCTRL			=	228,
	RSHIFT			=	229,
	RALT			=	230,
	RGUI			=	231,

	AUDIONEXT		=	258,
	AUDIOPREV		=	259,
	AUDIOSTOP		=	260,
	AUDIOPLAY		=	261,
	AUDIOMUTE		=	262,
	MEDIASELECT		=	263,
	WWW				=	264,
	MAIL			=	265,
	CALCULATOR		=	266,
	COMPUTER		=	267,
}