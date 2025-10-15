using Plank;
using Cairo;
using Gee;

namespace Volmatic {

public class VolmaticDockItem : DockletItem
{

    private Gtk.Clipboard clipboard;
    private Gdk.Pixbuf icon_pixbuf;
    private VolmaticDockItemPreferences prefs;
    private string sink_id = "0";

    public VolmaticDockItem.with_dockitem_file(GLib.File file) {
        GLib.Object(Prefs: new VolmaticDockItemPreferences.with_file(file));
    }

    construct {

        prefs = (VolmaticDockItemPreferences) Prefs;
        Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/volmatic_icon.png";
        Text = get_volume();

        ((VolmaticDockItemPreferences) Prefs).notify["CustomIcon"].connect(() => {
                update_icon();
            });

        update_icon();
        sink_id = get_active_sink_id();
        clipboard = Gtk.Clipboard.get(Gdk.Atom.intern("CLIPBOARD", true));

        try {
            icon_pixbuf = new Gdk.Pixbuf.from_resource(Volmatic.G_RESOURCE_PATH + "/icons/volmatic_icon.png");
        }
        catch(Error e) {
            warning("Error: " + e.message);
        }
    }

    protected override AnimationType on_hovered()
    {
        Text = get_volume();
        sink_id = get_active_sink_id();
        return AnimationType.NONE;
    }

    protected override AnimationType on_scrolled(Gdk.ScrollDirection direction, Gdk.ModifierType mod, uint32 event_time)
    {
        try {
            // Беремо поточну гучність (наприклад "51")
            string vol_str = get_volume();
            if(vol_str != "100" && vol_str != "0")
            {
               Process.spawn_command_line_async("paplay /usr/share/sounds/freedesktop/stereo/message.oga");
               var popover = new Gtk.Popover(this);
popover.set_position(Gtk.PositionType.BOTTOM);
popover.add(new Gtk.Label(vol_str));
popover.show_all();
            }
            double current = int.parse(vol_str) / 100.0;
            double step = 0.05; // 5%

            if(direction == Gdk.ScrollDirection.UP)
                current += step;
            else if(direction == Gdk.ScrollDirection.DOWN)
                current -= step;
            else
                return AnimationType.NONE;

            if(current < 0.0)
                current = 0.0;
            if(current > 1.0)
                current = 1.0;

            // Формуємо команду
            string vol_formatted = "%.2f".printf(current).replace(",", ".");
            string[] argv = {
                "wpctl", "set-volume", sink_id, vol_formatted
            };

            int status;
            Process.spawn_sync(
                null,
                argv,
                null,
                GLib.SpawnFlags.SEARCH_PATH,
                null,
                null,
                null,
                out status
                );

            // Оновлюємо label після зміни
            update_volume_label();

        }
        catch(Error e) {
            warning("Error changing volume: %s", e.message);
        }

        return AnimationType.NONE;
    }

    void update_volume_label()
    {
        string vol = get_volume(); // з попереднього прикладу
        Text = "🔊 " + vol + "%";
    }


    string get_volume()
    {
        try {
            string[] argv = {
                "bash", "-c",
                "wpctl status | awk '/Sinks:/,/Sources:/' | grep '\\*' | sed -n 's/.*\\[vol: *\\([0-9.]*\\)\\].*/\\1/p'"
            };

            string? stdout;
            string? stderr;
            int status;

            Process.spawn_sync(
                null, argv, null,
                GLib.SpawnFlags.SEARCH_PATH,
                null,
                out stdout, out stderr, out status
                );

            if(stdout != null && stdout.strip().length > 0)
            {
                double vol = double.parse(stdout.strip());
                return ((int)(vol * 100)).to_string();
            }

        }
        catch(Error e) {
            warning("Error getting volume: %s", e.message);
        }

        return "0";
    }

    string get_active_sink_id()
    {
        try {
            string[] argv = {
                "bash", "-c",
                "wpctl status | awk '/Sinks:/,/Sources:/' | grep '\\*' | sed -n 's/.*\\* *\\([0-9]\\+\\)\\..*/\\1/p'"
            };

            string? stdout;
            string? stderr;
            int status;

            Process.spawn_sync(
                null, argv, null,
                GLib.SpawnFlags.SEARCH_PATH,
                null,
                out stdout, out stderr, out status
                );

            if(stdout != null && stdout.strip().length > 0)
                return stdout.strip();

        }
        catch(Error e) {
            warning("Error getting active sink id: %s", e.message);
        }

        return "0"; // fallback
    }


    public override ArrayList<Gtk.MenuItem> get_menu_items()
    {
        var items = new ArrayList<Gtk.MenuItem>();

        var shutdown_item = new Gtk.MenuItem.with_label(_("Shut down"));
        shutdown_item.activate.connect(() => {
                //Quit.SessionManager.perform_with_confirmation(null, SessionManager.Action.SHUTDOWN, prefs);
            });
        items.add(shutdown_item);

        var reboot_item = new Gtk.MenuItem.with_label(_("Reboot"));
        reboot_item.activate.connect(() => {
                //Quit.SessionManager.perform_with_confirmation(null, SessionManager.Action.REBOOT, prefs);
            });
        items.add(reboot_item);

        var logout_item = new Gtk.MenuItem.with_label(_("Log out"));
        logout_item.activate.connect(() => {
                //Quit.SessionManager.perform_with_confirmation(null, SessionManager.Action.LOGOUT, prefs);
            });
        items.add(logout_item);
        var quit_item = new Gtk.MenuItem.with_label(_("Session Control"));
        quit_item.activate.connect(() => {
                //new Quit.QuitDialog(null, prefs);
            });
        items.add(quit_item);

        var separator = new Gtk.SeparatorMenuItem();
        items.add(separator);

        var settings_item = new Gtk.MenuItem.with_label(_("Settings"));
        settings_item.activate.connect(() => {
                //new Quit.SettingsWindow(this, prefs);
            });
        items.add(settings_item);

        return items;
    }

    public void update_icon()
    {
        string custom_icon = prefs.CustomIcon;
        if(custom_icon != null && custom_icon != "")
        {
            Icon = custom_icon;
        }
        else
        {
            Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/volmatic_icon.png";
        }
    }

}
}



