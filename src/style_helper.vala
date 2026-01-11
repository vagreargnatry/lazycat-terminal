// Helper to avoid deprecated Gtk.StyleContext warnings
// Uses direct C binding without deprecated attribute

namespace StyleHelper {
    // Direct binding to gtk_style_context_add_provider_for_display without deprecated warning
    [CCode (cname = "gtk_style_context_add_provider_for_display", cheader_filename = "gtk/gtk.h")]
    public extern void add_provider_for_display(Gdk.Display display, Gtk.StyleProvider provider, uint priority);
}
