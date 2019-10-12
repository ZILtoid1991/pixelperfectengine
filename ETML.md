Purpose of the ETML (Embedded Text Markup Language):

* Provide some familiar way to format text
* Provide some basic compatibility with HTML

# Markup tags

## Tags with the same behavior as their HTML counterpart

* `<p></p>`
* `<u></u>`
* `</ br>`
* `<s></s>`

Note: `u` and `s` (and `o`) can be formatted with attributes
* `style` (possible values: `single`, `double`, `triple`, `quad`),
* `lines` (possible values: `normal`, `dotted`, `wavy`, `wavySoft`, `stripes`),
* and `perWord` (possible values: `true`, `false`).

## Tags special to ETML

* `<o></o>`

Turns the text overstriken (puts a line on top of the selected text).

* `<i></i>`

Marks the text as italic. The amount can be set with the attribute `amount`.

* `<font type="OpenSans-reg-14" color="15"></font>`

Sets the type of the font.

* `</ frontTab amount="10">`

Inserts a tabulator at the given position.

* `</ image src="jeffrey">`

Inserts an image at the current position.
