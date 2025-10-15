public static void docklet_init(Plank.DockletManager manager)
{
    manager.register_docklet(typeof (Volmatic.VolmaticDocklet));
}

namespace Volmatic {

public const string G_RESOURCE_PATH = "/at/greyh/volmatic";

public class VolmaticDocklet : Object, Plank.Docklet
{
    public unowned string get_id()
    {
        return "Volmatic";
    }

    public unowned string get_name()
    {
        return _("Volmatic");
    }

    public unowned string get_description()
    {
        return _("Quick access to volume actions");
    }

    public unowned string get_icon()
    {
        return "resource://" + Volmatic.G_RESOURCE_PATH + "/icons/volmatic_icon.png";
    }

    public bool is_supported()
    {
        return true;
    }

    public Plank.DockElement make_element(string launcher, GLib.File file)
    {
        return new VolmaticDockItem.with_dockitem_file(file);
    }
}
}
