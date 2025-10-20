using Plank;

namespace Volmatic {

public class VolmaticDockItemPreferences : DockItemPreferences
{
    public double step {
        get; set; default = 0.05;
    }


    public bool show_media_info {
        [Notify]
        get; set; default = false;
    }

    public Volmatic.VolmaticDockItemPreferences.with_file(GLib.File file) {
        base.with_file(file);
    }

    protected override void reset_properties()
    {
        step = 0.05;
        show_media_info = false;
    }

}
}
