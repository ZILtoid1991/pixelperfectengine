/*
 * PixelPerfectEditor, multiImportDialog module
 *
 * Copyright 2017, under Boost License
 *
 * by Laszlo Szeremi
 */

module multiImportDialog;

import PixelPerfectEngine.concrete.window;
import PixelPerfectEngine.graphics.common;

import std.conv;
import std.string;

import converterdialog;

class MultiImportDialog : Window {
	Label label1;
	Label label2;
	//Label label3;
	Label label4;
	Label label5;
	Label label6;
	TextBox bitmapID;
	TextBox numFrom;
	//TextBox secBitmapID;
	TextBox sWidth;
	TextBox sHeight;
	TextBox paletteID;
	CheckBox checkBox_palImp;
	CheckBox checkBox_hex;
	RadioButtonGroup rb_bitDepth;
	Button button_ok;
	Button button_cancel;
	int fullX, fullY;
	ConverterDialog c;
	this(int x, int y, ConverterDialog c){
		super(Coordinate(0, 0, 225, 320), "Import sheet");
		label1 = new Label("IDbase:", "label1", Coordinate(5, 22, 75, 41));
		addElement(label1, EventProperties.MOUSE);
		label2 = new Label("NumFrom:", "label2", Coordinate(5, 47, 75, 65));
		addElement(label2, EventProperties.MOUSE);
		//label3 = new Label("IDsec:"w, "label3", Coordinate(5, 72, 75, 88));
		//addElement(label1, EventProperties.MOUSE);
		label4 = new Label("Width:", "label4", Coordinate(5, 72, 75, 88));
		addElement(label4, EventProperties.MOUSE);
		label5 = new Label("Height:", "label5", Coordinate(5, 97, 75, 115));
		addElement(label5, EventProperties.MOUSE);
		label6 = new Label("Palette:", "label6", Coordinate(5, 122, 75, 138));
		addElement(label6, EventProperties.MOUSE);
		bitmapID = new TextBox("bitmapID##xyz", "bitmapID", Coordinate(75, 20, 220, 39));
		addElement(bitmapID, EventProperties.MOUSE);
		numFrom = new TextBox("0", "numFrom", Coordinate(75, 45, 220, 65));
		addElement(numFrom, EventProperties.MOUSE);
		numFrom.onTextInput = &numFrom_onTextInput;
		//numTo = new TextBox("1"w, "numTo", Coordinate(75, 70, 220, 90));
		sWidth = new TextBox("32", "sWidth", Coordinate(75, 70, 220, 90));
		addElement(sWidth, EventProperties.MOUSE);
		sWidth.onTextInput = &sWidth_onTextInput;
		sHeight = new TextBox("32", "sHeight", Coordinate(75, 95, 220, 115));
		addElement(sHeight, EventProperties.MOUSE);
		sHeight.onTextInput = &sHeight_onTextInput;
		paletteID = new TextBox("default", "paletteID", Coordinate(75, 120, 220, 140));
		addElement(paletteID, EventProperties.MOUSE);
		checkBox_palImp = new CheckBox("Import palette from file", "checkBox_palImp", Coordinate(5, 150, 220, 166));
		addElement(checkBox_palImp, EventProperties.MOUSE);
		checkBox_hex = new CheckBox("Use hex numbering", "checkBox_hex", Coordinate(5, 170, 220, 186));
		addElement(checkBox_hex, EventProperties.MOUSE);
		rb_bitDepth = new RadioButtonGroup("BitDepth:", "rb_bitDepth", Coordinate(5, 190, 220, 290),[ "1bit", "4bit", "8bit", "16bit", "32bit"], 16, 0);
		addElement(rb_bitDepth, EventProperties.MOUSE);
		button_ok = new Button("Ok", "button_ok", Coordinate(160, 295, 220, 315));
		addElement(button_ok, EventProperties.MOUSE);
		button_ok.onMouseLClickRel = &buttonOk_mouseLClickRel;
		button_cancel = new Button("Cancel", "button_cancel", Coordinate(95, 295, 155, 315));
		addElement(button_cancel, EventProperties.MOUSE);
		button_cancel.onMouseLClickRel = &buttonClose_mouseLClickRel;
		this.c = c;
		fullX = x;
		fullY = y;
	}
	private bool checkIDbase(dstring s, out dstring foreTag, out dstring afterTag, out int digits){
		byte state;
		foreach(c; s){
			if(state == 0 && c == '#'){
				state = 1;
				digits++;
			}else if(state == 0){
				foreTag ~= c;
			}else if(state == 1 && c == '#'){
				digits++;
			}else if(state == 2 && c == '#'){
				return false;
			}else if(state == 2){
				afterTag ~= c;
			}else{
				state = 2;
				afterTag ~= c;
			}
		}
		if(!digits){
			return false;
		}
		return true;
	}
	private void numFrom_onTextInput(Event ev){
		if(!isNumeric(ev.text, true)){
			parent.messageWindow("Input Type Error", "Input field \"numFrom\"'s text is impossible to parse as a number!");
		}
	}
	private void sWidth_onTextInput(Event ev){

	}
	private void sHeight_onTextInput(Event ev){

	}
	private void buttonOk_mouseLClickRel(Event ev){
		try{
			dstring foreTag, afterTag;
			int digits;
			if(checkIDbase(bitmapID.getText(),foreTag,afterTag,digits)){
				string bitDepth;
				switch(rb_bitDepth.value){
					case 1:
						bitDepth = "4bit";
						break;
					case 2:
						bitDepth = "8bit";
						break;
					case 3:
						bitDepth = "16bit";
						break;
					case 4:
						bitDepth = "32bit";
						break;
					default:
						bitDepth = "1bit";
						break;
				}
				//string palID = checkBox_palImp.value ? to!string(paletteID.getText()) : null;
				c.multiImport(to!string(foreTag), to!string(afterTag), digits, to!string(paletteID.getText()), checkBox_palImp.value, bitDepth, to!int(numFrom.getText()), to!int(sWidth.getText()), to!int(sHeight.getText()), checkBox_hex.value);
				close();
			}else{
				parent.messageWindow("Input Error", "IDBase must have the following format:\n <foretag><####><aftertag>");
			}
		}catch(ConvException e){
			parent.messageWindow("Input Error", "Please check the fields if they're containing the correct type of data.");
		}catch(Exception e){
			parent.messageWindow(to!dstring(e.classinfo.toString()), to!dstring(e.msg));
		}
	}
	private void buttonClose_mouseLClickRel(Event ev){
		close();
	}
	deprecated public void actionEvent(Event event){
		switch(event.source){
			case "numFrom":
				if(!isNumeric(event.text, true)){
					parent.messageWindow("Input Type Error", "Input field \"numFrom\"'s text is impossible to parse as a number!");
				}
				break;
			case "sWidth":
				if(!isNumeric(event.text, true)){
					parent.messageWindow("Input Type Error", "Input field \"sWidth\"'s text is impossible to parse as a number!");
				}else if(fullX % to!int(sWidth.getText())){
					parent.messageWindow("Size Mismatch Error", "Current width is not suitable for input image's width. Try to choose
							a size that's dividable with the input image's width.");
				}
				break;
			case "sHeight":
				if(!isNumeric(event.text, true)){
					parent.messageWindow("Input Type Error", "Input field \"sHeight\"'s text is impossible to parse as a number!");
				}else if(fullY % to!int(sHeight.getText())){
					parent.messageWindow("Size Mismatch Error", "Current height is not suitable for input image's height. Try to choose
							a size that's dividable with the input image's height.");
				}
				break;
			case "button_ok":
				try{
					dstring foreTag, afterTag;
					int digits;
					if(checkIDbase(bitmapID.getText(),foreTag,afterTag,digits)){
						string bitDepth;
						switch(rb_bitDepth.value){
							case 1:
								bitDepth = "4bit";
								break;
							case 2:
								bitDepth = "8bit";
								break;
							case 3:
								bitDepth = "16bit";
								break;
							case 4:
								bitDepth = "32bit";
								break;
							default:
								bitDepth = "1bit";
								break;
						}
						//string palID = checkBox_palImp.value ? to!string(paletteID.getText()) : null;
						c.multiImport(to!string(foreTag), to!string(afterTag), digits, to!string(paletteID.getText()), checkBox_palImp.value, bitDepth, to!int(numFrom.getText()), to!int(sWidth.getText()), to!int(sHeight.getText()), checkBox_hex.value);
						close();
					}else{
						parent.messageWindow("Input Error", "IDBase must have the following format:\n <foretag><####><aftertag>");
					}
				}catch(ConvException e){
					parent.messageWindow("Input Error", "Please check the fields if they're containing the correct type of data.");
				}catch(Exception e){
					parent.messageWindow(to!dstring(e.classinfo.toString()), to!dstring(e.msg));
				}
				break;
			case "button_cancel":
				close();
				break;
			default:
				break;
		}
	}

}
