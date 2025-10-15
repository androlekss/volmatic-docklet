using Plank;

namespace Volmatic {

public class VolmaticDockItemPreferences : DockItemPreferences
{
    public string CustomIcon { get; set; default = ""; }

    public Volmatic.VolmaticDockItemPreferences.with_file(GLib.File file) {
        base.with_file(file);
    }

    protected override void reset_properties () {
        CustomIcon = "";
    }

}
}
