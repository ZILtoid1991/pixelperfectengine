module contmenu;

import pixelperfectengine.concrete.popup.popupmenu;
import pixelperfectengine.concrete.types;



/*
 * Contains functions to create various context menus for the editor.
 */
/**
 * Generates a context menu for select mode.
 */
public PopUpMenu createSelectContextMenu(EventDeleg onMenuSelect) {
    PopUpMenuElement[] elements;
    elements ~= new PopUpMenuElement("copy", "Copy"d);
    elements ~= new PopUpMenuElement("cut", "Cut"d);
    elements ~= new PopUpMenuElement("paste", "Paste"d);
    return new PopUpMenu(elements, "contextMenu_Select", onMenuSelect);
}