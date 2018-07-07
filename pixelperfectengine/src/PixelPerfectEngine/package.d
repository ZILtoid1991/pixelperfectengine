module PixelPerfectEngine.collision;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, collision detector module
 */


/**
 *Use this interface to listen to collision events.
 */
public interface CollisionListener{
	//Invoked when two sprites have collided.
	//IMPORTANT: Might generate "mirrored collisions" if both sprites are moving. Be aware of it when you're developing your program.
	public void spriteCollision(CollisionEvent ce);
	
}
/**
 * Stores the data regarding a sprite collision.
 */
public class CollisionEvent{
	public int sourceA, sourceB;		/// A = object that called the detection.

	public this(int sourceA, int sourceB){
		this.sourceA = sourceA;
		this.sourceB = sourceB;
	}
}