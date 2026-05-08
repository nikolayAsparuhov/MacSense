# Bubble Map

The interactive circles on the Storage Size tab. Each bubble represents one folder; the area is proportional to the folder's recursive size.

## Details

How to read it:

- **Bigger circle = bigger folder.** Two-dimensional area, not radius — so a folder twice the size has roughly twice the visible area.
- **Click a bubble** to drill into that folder. The right-side bubble map and the breadcrumb at the top both update.
- **Selection rail** on the left sidebar lets you toggle items for trashing. Toggling here selects whole folders at once.

Tiny siblings get grouped into an **"Other items"** bubble so the visualization stays readable. Clicking it expands the sidebar list to show every entry.

The bubble layout is recomputed whenever the breadcrumb changes — there's no animation between layouts to keep navigation snappy.
