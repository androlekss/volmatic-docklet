using Gtk;

namespace Volmatic {
public class SettingsWindow : Gtk.Window
{
    private VolmaticDockItemPreferences prefs;

    public SettingsWindow (VolmaticDockItem parent, VolmaticDockItemPreferences prefs)
    {
        this.prefs = prefs;
        bool has_playerctl = false;

        try {
            string? stdout;
            string? stderr;
            int exit_status;
            GLib.Process.spawn_command_line_sync("playerctl --version", out stdout, out stderr, out exit_status);
            has_playerctl = (exit_status == 0);
        }
        catch(Error e) {
            has_playerctl = false;
        }

        prefs.notify["step"].connect(() => {
                parent.step = prefs.step;
            });

        title = "Volmatic Settings";
        set_default_size(300, 100);
        set_border_width(10);
        set_position(Gtk.WindowPosition.CENTER);

        var step_label = new Gtk.Label("Volume Step:");
        step_label.set_halign(Gtk.Align.START);

        var step_combo = new Gtk.ComboBoxText();
        step_combo.append_text("5%");
        step_combo.append_text("10%");
        step_combo.append_text("15%");

        if(prefs.step == 0.05)
            step_combo.set_active(0);
        else if(prefs.step == 0.10)
            step_combo.set_active(1);
        else if(prefs.step == 0.15)
            step_combo.set_active(2);

        step_combo.changed.connect(() => {
                switch(step_combo.get_active())
                {
                case 0: prefs.step = 0.05; break;
                case 1: prefs.step = 0.10; break;
                case 2: prefs.step = 0.15; break;
                }
            });

        var media_info_toggle = new Gtk.CheckButton.with_label("Show media info");
        media_info_toggle.set_active(prefs.show_media_info);
        media_info_toggle.set_sensitive(has_playerctl);

        media_info_toggle.toggled.connect(() => {
                prefs.show_media_info = media_info_toggle.get_active();
            });


        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        vbox.pack_start(step_label, false, false, 0);
        vbox.pack_start(step_combo, false, false, 0);

        if(!has_playerctl)
        {
            var warning_label = new Gtk.Label("This feature requires 'playerctl' to be installed.");
            warning_label.get_style_context().add_class("dim-label");
            warning_label.set_halign(Gtk.Align.START);
            vbox.pack_start(warning_label, false, false, 0);
        }
        vbox.pack_start(media_info_toggle, false, false, 0);

        add(vbox);

        show_all();
    }

}
}
