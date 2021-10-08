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
    elements ~= new PopUpMenuElement("flph", "Flip horizontal"d);
    elements ~= new PopUpMenuElement("flpv", "Flip vertical"d);
    elements ~= new PopUpMenuElement("mirh", "Mirror horizontal"d);
    elements ~= new PopUpMenuElement("mirv", "Mirror vertical"d);
    elements ~= new PopUpMenuElement("shp", "Shift palette..."d);
    return new PopUpMenu(elements, "contextMenu_Select", onMenuSelect);
}
/**
 * Generates a context menu for tile placement mode.
 */
public PopUpMenu createTilePlacementContextMenu(EventDeleg onMenuSelect) {
    PopUpMenuElement[] elements;
    elements ~= new PopUpMenuElement("paste", "Paste"d);
    elements ~= new PopUpMenuElement("hm", "Toggle horizontal mirroring"d);
    elements ~= new PopUpMenuElement("vm", "Toggle vertical mirroring"d);
    elements ~= new PopUpMenuElement("p+", "Next palette"d);
    elements ~= new PopUpMenuElement("p-", "Prev palette"d);
    return new PopUpMenu(elements, "contextMenu_Select", onMenuSelect);
}