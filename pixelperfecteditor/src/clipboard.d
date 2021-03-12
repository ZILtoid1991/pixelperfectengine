module clipboard;

/**
 * Implements a clipboard, with history.
 */
public class Clipboard {

}
/**
 * Implements the basics of a clipboard item
 */
public abstract class ClipboardItem {
    public abstract void paste(int offsetX, int offsetY);
}