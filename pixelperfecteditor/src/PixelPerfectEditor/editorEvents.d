module editorEvents;

public import PixelPerfectEngine.concrete.eventChainSystem;
public import PixelPerfectEngine.graphics.layers;

public class WriteToMapVoidFill : UndoableEvent{
	ITileLayer target;
	Coordinate area;
	MappingElement me;
	ubyte[] mask;
	public this(ITileLayer target, Coordinate area, MappingElement me){
		this.target = target;
		this.area = area;
		this.me = me;
	}
	public void redo(){
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				if(target.readMapping(x,y).tileID != 0xFFFF){
					mask[area.width * y + x] = 0xFF;
					target.writeMapping(x,y,me);
				}
			}
		}
	}
	public void undo(){
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				if(mask[area.width * y + x] == 0xFF){
					target.writeMapping(x,y,MappingElement(0xFFFF));
				}
			}
		}
	}
}

public class WriteToMapOverwrite : UndoableEvent{
	ITileLayer target;
	Coordinate area;
	MappingElement me;
	MappingElement[] original;
	public this(ITileLayer target, Coordinate area, MappingElement me){
		this.target = target;
		this.area = area;
		this.me = me;
		original.length = area.area;
	}
	public void redo(){
		size_t pos;
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				original[pos] = target.readMapping(x,y);
				target.writeMapping(x,y,me);
				pos++;
			}
		}
	}
	public void undo(){
		size_t pos;
		for(int y = area.top ; y < area.bottom ; y++){
			for(int x = area.left ; x < area.right ; x++){
				target.writeMapping(x,y,original[pos]);
				pos++;
			}
		}
	}
}

public class WriteToMapSingle : UndoableEvent{
	ITileLayer target;
	int x;
	int y;
	MappingElement me;
	MappingElement original;
	public this(ITileLayer target, int x, int y, MappingElement me){
		this.target = target;
		this.x = x;
		this.y = y;
		this.me = me;
	}
	public void redo(){
		original = target.readMapping(x,y);
		target.writeMapping(x,y,me);
	}
	public void undo(){
		target.writeMapping(x,y,original);
	}
}
