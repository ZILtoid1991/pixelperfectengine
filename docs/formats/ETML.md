Purpose of the ETML (Embedded Text Markup Language):

* Provide some familiar way to format text
* Provide some basic compatibility with HTML

# Markup tags

## Tags with the same behavior as their HTML counterpart

* `<p></p>`: Paragraph marker.
* `<u></u>`: Understrike marker.
* `</ br>`: Line break (normal line breaks are not processed by default).
* `<s></s>`: Strikethrough.

Note: `u` can be formatted with attributes
* `style` (possible values: `single`, `double`, `triple`, `quad`),
* `lines` (possible values: `normal`, `dotted`, `wavy`, `wavySoft`, `stripes`),
* and `perWord` (possible values: `true`, `false`).

Note: `p` can be formatted with attributes
* `paragraphSpace` (numeric values): Defines the space between two paragraphs.
* `rowHeight` (numeric values): Defines the height of a row.

Note: `p`, `font`, and `text` tags can be formatted with attribute:
* `offsetV`: Vertical offset for single-line texts, sometimes can be useful.

## Tags special to ETML

* `<o></o>`: Turns the text overstriken (puts a line on top of the selected text).

* `<i></i>`: Marks the text as italic. The amount can be set with the attribute `amount`.

* `<font type="OpenSans-reg-14" color="15"></font>`: Sets the type and/or of the font. In the future, there might be a
size attribute, if vector fonts will ever be supported.

* `<format id="default"></format>`: Chooses a predefined format for the text chunk. Can be modified with any of the 
other tags.

* `<frontTab amount="10" />` or `<ft amount="10" />`: Inserts a tabulator at the given position.

* `<image src="jeffrey" />`: Inserts an image at the current position.

* `<text id="64"></text>`: Used for containing multiple textchunks in a single file.

# Example document

```xml
<!xml version = "1.0" encoding = "utf8">
<?DOCTYPE ETML?>
<etml>
    <text id="example1">
        Hello world! <br />
        This is an examle of a <i>multiline</i> text done in ETML.
    </text>
    <text id="example2">
        This even supports Unicode characters as long as the target system is capable of displaying them. <br />
        árvíztűrő tükörfúrógép ÁRVÍZTŰRŐ TÜKÖRFÚRÓGÉP
    </text>
</etml>
```

# Note on custom entities

Applications can register custom entities, that will be injected into the document while parsing, and override any DTD
defined entities if names are matching. So called "system" (or external) entities are completely disabled.