module pixelperfectengine.graphics.layers.trianglemasklayer;

public import pixelperfectengine.graphics.layers.base;
package import bindbc.opengl;

public class TriangleMaskLayer : MaskLayer {
	protected uint texture;
	/**
	 * Returns the resulting OpenGL texture.
	 */
	public override uint getTexture_gl() @nogc nothrow {
		return texture;
	}
	/**
	 * Runs the OpenGL renderer for the texture. Can be ran independently of the main rendering loop, e.g. only when
	 * the content needs to be updated.
	 */
	public override void renderToTexture_gl() @nogc nothrow {

	}
}
