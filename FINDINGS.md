# Findings

Binding and tooling limitations hit while porting fretboard, recorded here so
a gap description never has to carry its own excuse. Nothing here closes a
gap; it only explains why one is hard.

## `Gtk::Accessible#update_property` cannot be called from Ruby

Confirmed by direct test against the fork's dev shell (gtk4 gem 4.22.x,
`gobject-introspection` gem 4.3.9, GTK 4.22.4):

```
$ nix develop --command xvfb-run -a ruby -e '
    require "gtk4"
    b = Gtk::Button.new
    b.update_property([Gtk::AccessibleProperty::LABEL], ["hello"])
  '
.../gobject-introspection-4.3.9/lib/ruby/gems/3.4.0/gems/gobject-introspection-4.3.9/lib/gobject-introspection/loader.rb:722:in
'GObjectIntrospection::MethodInfo#invoke':
TODO: in Ruby -> GIArgument(array/C)[interface(enum)](GtkAccessibleProperty) (NotImplementedError)
```

The method exists and is bound (`Gtk::Accessible#update_property`,
`#update_relation`, `#update_state` are all present on
`Gtk::Accessible.instance_methods`), but the `gobject-introspection` gem's
argument marshaller has no case for "C array of an enum-typed interface",
which is exactly the shape of `GtkAccessibleProperty properties[]` in
`gtk_accessible_update_property`'s non-varargs form. The failure is identical
whether the properties array holds `Gtk::AccessibleProperty::LABEL` symbols or
the equivalent raw integers, and it is the same failure for `update_relation`
and `update_state`, which take the same array shape. This is a gap in the
introspection loader itself, not a quirk of how the call was made.

**Workarounds considered and ruled out:**

- Calling the underlying C symbol directly (via Fiddle/FFI), bypassing the
  broken marshaller. This needs the object's raw `GObject*` pointer.
  `Gtk::Widget` exposes no such accessor in these bindings: `#pointer` is an
  unrelated, deprecated method (`Gdk::Window#get_device_position`'s old name)
  that raises `GLib::DeprecatedError`, `#native` is the widget's native
  surface (`nil` until realized, and not a GObject pointer regardless), and
  nothing in `GLib::Object`'s or `Gtk::Widget`'s method list or private
  methods yields an address a Fiddle call could use. There is no supported
  escape hatch to raw pointers from Ruby in this binding.
- A GObject property fallback (`set_property("accessible-label", …)`). There
  is no such property; `GtkAccessible` is a plain interface whose state is set
  only through `update_property`/`update_relation`/`update_state`.

**What would close it:** a fix to `gobject-introspection`'s loader adding a
marshalling case for enum-typed C arrays, upstreamed to the gem, or a
hand-written C extension in this project that calls
`gtk_accessible_update_property` directly and is required alongside the
pure-Ruby bindings. Both are real engineering, not a one-line workaround.

This is why `lib/fretboard/chord_diagram_top_toggle.rb` and
`lib/fretboard/chord_name_entry.rb` set only a tooltip where upstream sets both
a tooltip and an accessible label — see those files and `TRANSLATION_PARITY.md`
for the behaviour this leaves missing.
