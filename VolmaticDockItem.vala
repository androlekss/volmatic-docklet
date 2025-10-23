using Plank;
using Gee;

namespace Volmatic {

public class VolmaticDockItem : DockletItem
{
    private VolmaticDockItemPreferences prefs;
    private SinkState state;
    private SettingsWindow? settings_window = null;
    private Gtk.Label playerctl_label;
    private Gtk.Window? volume_popup = null;
    private Gtk.Label? volume_label = null;
    private Gtk.Label? hint_label = null;
    private uint64 last_change_time = 0;
    private bool hovered_state = false;
    private int image_width;
    private int image_height;
    public double step {
        [Notify]
        get; set; default = 0.05;
    }

    public VolmaticDockItem.with_dockitem_file(GLib.File file) {
        GLib.Object(Prefs: new VolmaticDockItemPreferences.with_file(file));
    }

    construct {

        var css = new Gtk.CssProvider();

        try {
            css.load_from_resource("/com/volmatic/css/volmatic.css");
        }
        catch(GLib.Error e) {
            warning("Failed to load CSS: %s".printf(e.message));
        }

        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

        prefs = (VolmaticDockItemPreferences) Prefs;
        step = prefs.step;

        var state = new WpctlState().get_active_sink();
        if(state != null)
        {
            stdout.printf("Sink %d (%s): vol=%d muted=%s\n",
                          state.id, state.name, state.volume, state.muted.to_string());
        }

        var display = Gdk.Display.get_default();
        var monitor = display.get_primary_monitor();
        Gdk.Rectangle geometry = monitor.get_geometry();

        int screen_width = geometry.width;
        int screen_height = geometry.height;

        image_width = (int)(screen_width * 0.15);
        image_height = (int)(screen_height * 0.15);

        hint_label = new Gtk.Label("Scroll to adjust volume");
        update_volume_popup();
    }

    protected override AnimationType on_hovered()
    {
        hovered_state = !hovered_state;

        if(!hovered_state && volume_popup != null)
        {
            volume_popup.destroy();
            volume_popup = null;
            return AnimationType.NONE;
        }

        if(hovered_state)
        {
            show_volume_popup();
            state = new WpctlState().get_active_sink();
        }

        return AnimationType.NONE;
    }

    protected override AnimationType on_scrolled(Gdk.ScrollDirection direction, Gdk.ModifierType mod, uint32 event_time)
    {
        try {

            int vol = state.volume;
            uint64 now = GLib.get_real_time();
            if(now - last_change_time > 150000)
            {
                last_change_time = now;

                if(vol != 100 && vol != 0)
                {
                    Process.spawn_command_line_async("paplay /usr/share/sounds/freedesktop/stereo/message.oga");
                }

                double current = vol / 100.0;

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

                string vol_formatted = "%.2f".printf(current).replace(",", ".");
                string[] argv = {
                    "wpctl", "set-volume", state.id.to_string(), vol_formatted
                };

                int status;
                Process.spawn_sync(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, null, null, out status);
                string muted = "0";
                if(current == 0.0)
                {
                    muted = "1";
                }

                argv = {
                    "wpctl", "set-mute", state.id.to_string(), muted
                };

                try {
                    Process.spawn_sync(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, null, null, out status);
                }
                catch(GLib.SpawnError e) {
                    warning("Failed to spawn process: %s".printf(e.message));
                }

                update_volume_label();
            }

        }
        catch(Error e) {
            warning("Error changing volume: %s", e.message);
        }

        return AnimationType.NONE;
    }

    private void show_volume_popup()
    {
        DockController? controller = get_dock();
        if(controller == null)
        {
            warning("Dock controller is null!");
            return;
        }

        // Create the popup menu if not created yet
        if(volume_popup == null)
        {
            volume_popup = new Gtk.Window(Gtk.WindowType.POPUP);
            volume_popup.set_type_hint(Gdk.WindowTypeHint.TOOLTIP);
            volume_popup.set_decorated(false);
            volume_popup.set_skip_taskbar_hint(true);
            volume_popup.set_skip_pager_hint(true);
            volume_popup.set_keep_above(true);
            volume_popup.set_resizable(false);

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            box.set_border_width(6);
            update_volume_popup();
            hint_label.get_style_context().add_class("hint");
            box.pack_start(volume_label, false, false, 0);
            box.pack_start(hint_label, false, false, 0);

            playerctl_label = new Gtk.Label("");
            playerctl_label.set_max_width_chars(30);
            playerctl_label.set_line_wrap(true);
            playerctl_label.get_style_context().add_class("media-info");
            playerctl_label.set_halign(Gtk.Align.FILL);

            if(prefs.show_media_info)
            {
                string art_path = get_art_img();

                if(GLib.FileUtils.test(art_path, GLib.FileTest.EXISTS))
                {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(art_path, image_width, image_height, true);
                    var album_art = new Gtk.Image.from_pixbuf(pixbuf);
                    box.pack_start(album_art, false, false, 0);
                }

                playerctl_label.set_text(get_playerctl_info());
                box.pack_start(playerctl_label, false, false, 0);
            }

            volume_popup.add(box);
            volume_popup.show_all();
        }
        else
        {
            update_volume_popup();
            volume_popup.queue_draw();
            return;
        }

        Gtk.Requisition req;
        volume_popup.get_preferred_size(null, out req);

        int x, y;
        controller.position_manager.get_menu_position(this, req, out x, out y);

        Gdk.Gravity gravity;
        Gdk.Gravity flipped_gravity;

        switch(controller.position_manager.Position)
        {
        case Gtk.PositionType.BOTTOM:
            gravity = Gdk.Gravity.NORTH;
            flipped_gravity = Gdk.Gravity.SOUTH;
            break;
        case Gtk.PositionType.TOP:
            gravity = Gdk.Gravity.SOUTH;
            flipped_gravity = Gdk.Gravity.NORTH;
            break;
        case Gtk.PositionType.LEFT:
            gravity = Gdk.Gravity.EAST;
            flipped_gravity = Gdk.Gravity.WEST;
            break;
        case Gtk.PositionType.RIGHT:
            gravity = Gdk.Gravity.WEST;
            flipped_gravity = Gdk.Gravity.EAST;
            break;
        default:
            gravity = Gdk.Gravity.NORTH;
            flipped_gravity = Gdk.Gravity.SOUTH;
            break;
        }

        volume_popup.move(x,y);
    }

    private void update_volume_popup()
    {
        if(volume_label == null)
        {
            volume_label = new Gtk.Label("");
        }

        state = new WpctlState().get_active_sink();
        int current_volume = state.volume;
        volume_label.set_text("🔊 Volume: %d%%".printf(current_volume));

        if(state.muted)
        {
            volume_label.set_text("🔇 Muted");
            Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/audio-volume-muted.png";
        }
        else if(current_volume < 30)
        {
            volume_label.set_text("🔈 %d%%".printf(current_volume));
            Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/audio-volume-low.png";
        }
        else if(current_volume < 70)
        {
            volume_label.set_text("🔉 %d%%".printf(current_volume));
            Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/audio-volume-medium.png";
        }
        else
        {
            volume_label.set_text("🔊 %d%%".printf(current_volume));
            Icon = "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/audio-volume-high.png";
        }
    }

    private string get_art_img()
    {
        try {
            string? stdout;
            string? stderr;
            int exit_status;

            GLib.Process.spawn_command_line_sync(
                "playerctl metadata --format '{{mpris:artUrl}}'",
                out stdout,
                out stderr,
                out exit_status
                );
            stdout.printf("stdout");
            if(exit_status == 0 && stdout != null)
            {
                return stdout.replace("file://", "").strip();
            }
        }
        catch(Error e) {
            warning("playerctl error: " + e.message);
        }

        return "No media info";

    }

    private string get_playerctl_info()
    {
        try {
            string? stdout;
            string? stderr;
            int exit_status;

            GLib.Process.spawn_command_line_sync(
                "playerctl metadata --format '{{status}}: {{artist}} - {{title}}'",
                out stdout,
                out stderr,
                out exit_status
                );

            if(exit_status == 0 && stdout != null)
                return stdout.strip();
        }
        catch(Error e) {
            warning("playerctl error: " + e.message);
        }

        return "No media info";
    }

    void update_volume_label()
    {
        show_volume_popup();
    }

    public override ArrayList<Gtk.MenuItem> get_menu_items()
    {
        volume_popup.destroy();

        var items = new ArrayList<Gtk.MenuItem>();

        var settings_item = new Gtk.MenuItem.with_label(_("Settings"));
        settings_item.activate.connect(() => {
                open_settings_window();
            });

        string mutr_item_label = state.muted ? _("Unmute") : _("Mute");

        var mute_item = new Gtk.MenuItem.with_label(mutr_item_label);
        mute_item.activate.connect(() => {

                string[] argv = { "wpctl", "set-mute", state.id.to_string(), "toggle" };

                int status;
                try {
                    Process.spawn_sync(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, null, null, out status);
                }
                catch(GLib.SpawnError e) {
                    warning("Failed to spawn process: %s".printf(e.message));
                }

                update_volume_label();

                GLib.Timeout.add(500, () => {
                    if(volume_popup != null)
                    {
                        volume_popup.destroy();
                        volume_popup = null;
                    }
                    return GLib.Source.REMOVE;
                });
            });

        var separator = new Gtk.SeparatorMenuItem();

        items.add(settings_item);
        items.add(separator);
        items.add(mute_item);

        return items;
    }

    private void open_settings_window()
    {
        if(settings_window != null && settings_window.is_visible())
        {
            settings_window.present();
            return;
        }

        settings_window = new SettingsWindow(this, prefs);
        settings_window.set_destroy_with_parent(true);

        settings_window.destroy.connect(() => {
                settings_window = null;
            });

        settings_window.show_all();
    }
}
}

