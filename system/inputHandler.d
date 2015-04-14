module system.inputHandler;

import derelict.sdl2.sdl;

abstract class InputHandler{
	private bool b;
	private InputListener[int] il;
	private string name;
	public KeyBinding[int] kb;

	public void addInputListener(InputListener i, int id){
		il[id] = i;
	}
	public string getName(){
		return name;
	}
	public void init(){

	}
	public void test(){
	
	}
	public void stop(){
		b = true;
	}
	private void invokeKeyPressed(string ID, Uint32 timestamp){
		foreach(i; il){
			i.keyPressed(ID, timestamp);
		}
	}
	private void invokeKeyReleased(string ID, Uint32 timestamp){
		foreach(i; il){
			i.keyReleased(ID, timestamp);
		}
	}

}

public class KeyboardHandler : InputHandler{

	public this(){
		name = "Keyboard";
	}
	public override void init(){
		b = false;
		while(!b){
			SDL_Event event;
			while(SDL_PollEvent(&event)){
				if(event.type == SDL_KEYDOWN){

					foreach(k; kb){
						if(event.key.keysym.scancode == k.keycode && event.key.keysym.mod == k.keymod){
							invokeKeyPressed(k.ID, event.key.timestamp);
						}
					}
				}
				else if(event.type == SDL_KEYUP){
					foreach(k; kb){
						if(event.key.keysym.scancode == k.keycode && event.key.keysym.mod == k.keymod){
							invokeKeyReleased(k.ID, event.key.timestamp);
						}
					}
				}
			}
		}
	}

	public override void test() {
		SDL_Event event;
		while(SDL_PollEvent(&event)){
			if(event.type == SDL_KEYDOWN){

				foreach(k; kb){
					if(event.key.keysym.scancode == k.keycode && event.key.keysym.mod == k.keymod){
						invokeKeyPressed(k.ID, event.key.timestamp);
					}
				}
			}
			else if(event.type == SDL_KEYUP){
				foreach(k; kb){
					if(event.key.keysym.scancode == k.keycode && event.key.keysym.mod == k.keymod){
						invokeKeyReleased(k.ID, event.key.timestamp);
					}
				}
			}
		}
	}

}

public class JoystickHandler : InputHandler{
	private AxisListener[int] al;
	private string hatpos;
	public this(){
		name = "Joystick";
	}

	public override void init(){
		b = false;
		while(!b){
			SDL_Event event;
			while(SDL_PollEvent(&event)){
				if(event.type == SDL_JOYBUTTONDOWN){
					
					foreach(k; kb){
						if(event.jbutton.button == k.keycode && 0 == k.keymod){
							invokeKeyPressed(k.ID, event.jbutton.timestamp);
						}
					}
				}
				else if(event.type == SDL_JOYBUTTONUP){
					foreach(k; kb){
						if(event.jbutton.button == k.keycode && 0 == k.keymod){
							invokeKeyReleased(k.ID, event.key.timestamp);
						}
					}
				}
				if(event.type == SDL_JOYHATMOTION){
					foreach(k; kb){
						if(event.jhat.alignof == k.keycode && 4 == k.keymod){
							invokeKeyReleased(hatpos, event.jhat.timestamp);
							invokeKeyPressed(k.ID, event.jhat.timestamp);
							hatpos = k.ID;
						}
					}
				}
				if(event.type == SDL_JOYAXISMOTION){
					foreach(k; kb){
						if(event.jaxis.axis == k.keycode && 8 == k.keymod){
							invokeAxisEvent(k.ID, event.jaxis.timestamp, event.jaxis.value);
						}
					}
				}
			}
		}
	}
	
	public override void test() {
		SDL_Event event;
		while(SDL_PollEvent(&event)){
			if(event.type == SDL_JOYBUTTONDOWN){
				
				foreach(k; kb){
					if(event.jbutton.button == k.keycode && 0 == k.keymod){
						invokeKeyPressed(k.ID, event.jbutton.timestamp);
					}
				}
			}
			else if(event.type == SDL_JOYBUTTONUP){
				foreach(k; kb){
					if(event.jbutton.button == k.keycode && 0 == k.keymod){
						invokeKeyReleased(k.ID, event.key.timestamp);
					}
				}
			}
			if(event.type == SDL_JOYHATMOTION){
				foreach(k; kb){
					if(event.jhat.alignof == k.keycode && 4 == k.keymod){
						invokeKeyReleased(hatpos, event.jhat.timestamp);
						invokeKeyPressed(k.ID, event.jhat.timestamp);
						hatpos = k.ID;
					}
				}
			}
			if(event.type == SDL_JOYAXISMOTION){
				foreach(k; kb){
					if(event.jaxis.axis == k.keycode && 8 == k.keymod){
						invokeAxisEvent(k.ID, event.jaxis.timestamp, event.jaxis.value);
					}
				}
			}
		}
	}
	private void invokeAxisEvent(string ID, Uint32 timestamp, Sint16 val){
		foreach(a; al){
			a.axisEvent(ID, timestamp, val);
		}
	}
}

public struct KeyBinding{
	public Uint32 keycode;
	public Uint16 keymod;
	public string ID;

	this(Uint16 km, Uint32 kc, string s){
		keycode = kc;
		keymod = km;
		ID = s;
	}
}

public interface InputListener{
	public void keyPressed(string ID, Uint32 timestamp);
	public void keyReleased(string ID, Uint32 timestamp);
}

public interface AxisListener{
	public void axisEvent(string ID, Uint32 timestamp, Sint16 val);
}

public interface MovementListener{
	public void movementEvent(string ID, Sint16 x, Sint16 y, Sint16 relX, Sint16 relY);
}