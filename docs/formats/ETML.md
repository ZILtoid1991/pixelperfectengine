Purpose of the ETML (Embedded Text Markup Language):

* Provide some familiar way to format text.
* Provide some basic compatibility with HTML without the later overcomplicated formats.

An ETML file also can contain format definitions, essentially doubling as a stylesheet.

# Markup tags

All tags and attributes are case sensitive.

All boolean values can be set as: `true` or `yes`, and `false` or `no`.

## Tags with the same behavior as their HTML counterpart

* `<p></p>`: Paragraph marker.
* `<u></u>`: Understrike marker.
* `</ br>`: Line break (normal line breaks are not processed by default).
* `<s></s>`: Strikethrough.

Note: `u` can be formatted with attributes
* `style` (possible values: `single`, `double`, `triple`, `quad`),
* `lines` (possible values: `normal`, `dotted`, `wavy`, `wavySoft`, `stripes`),
* and `perWord` (boolean).

Note: `p` can be formatted with attributes
* `paragraphSpace` (numeric values): Defines the space between two paragraphs.
* `rowHeight` (numeric values): Defines the height of a row.
* `justify`: Defines where the text should be justified. Possible values are: `left`, `right`, `center`, `fill`

Note: `p`, `font`, and `text` tags can be formatted with attribute:
* `offsetV`: Vertical offset for single-line texts, sometimes can be useful.

## Tags special to ETML

* `<o></o>`: Turns the text overstriken (puts a line on top of the selected text).

* `<i></i>`: Marks the text as italic. The amount can be set with the attribute `amount`.

* `<font type="OpenSans-reg-14" color="15"></font>`: Sets the type and/or of the font. In the future, there might be a
size attribute, if vector fonts will ever be supported.

* `<format id="default"></format>`: Chooses a predefined format for the text chunk. Can be modified with any of the 
other tags. The `id` attribute is mandatory.

* `<frontTab amount="10" />` or `<ft amount="10" />`: Inserts a tabulator at the given position. The `amount` attribute is mandatory.

* `<image src="jeffrey" hoffset="10" voffset="3" spacing="5" />`: Inserts an image at the current position. The `src` attribute is mandatory.

* `<text id="64"></text>`: Used for containing the multiple textchunks in a single file. The `id` attribute is mandatory. Contained within the document body. Cannot be cascading.

* `<formatDef id="menuText" u="yes" u_style="single" />`: Used for defining a text formatting for the `<format>` tags. Contained within the document body, the `id` attribute is mandatory. Attributes work like this: most single formatting tag names (e.g. `u`) are boolean values, and the `[formatting tag name]_[formatting attribute]` works similarly to the full formatting tag. `p` and `font` by themselves don't exists as boolean values. All default values are tied to the default formatting.

# Example document

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ETML>
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