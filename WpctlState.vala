namespace Volmatic {

public class WpctlState : Object
{

    public SinkState? get_active_sink() {
        try {
            string[] argv = {
                "bash", "-c",
                "wpctl status"
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

            if(stdout == null || stdout.strip().length == 0)
                return SinkState() {
                           id = -1, name = "Unknown", volume = 0, muted = false
                }
            ;

            foreach(string line in stdout.split("\n"))
            {
                if(!line.contains("Sinks:") && line.contains("*"))
                {
                    MatchInfo id_info;
                    int id = -1;
                    Regex id_regex = new Regex("\\*\\s+(\\d+)\\.");
                    if(id_regex.match(line, 0, out id_info))
                    {
                        id = int.parse(id_info.fetch(1));
                    }

                    MatchInfo name_info;
                    string name = "Unknown";
                    Regex name_regex = new Regex("\\*\\s+\\d+\\.\\s+(.+?)\\s+\\[");
                    if(name_regex.match(line, 0, out name_info))
                    {
                        name = name_info.fetch(1).strip();
                    }

                    MatchInfo vol_info;
                    int volume = 0;
                    Regex vol_regex = new Regex("\\[vol:\\s*([0-9.]+)");
                    if(vol_regex.match(line, 0, out vol_info))
                    {
                        string vol_str = vol_info.fetch(1);
                        volume = (int)(double.parse(vol_str) * 100);
                    }

                    // MUTED
                    bool muted = line.contains("MUTED");

                    return SinkState() {
                               id = id,
                               name = name,
                               volume = volume,
                               muted = muted
                    };
                }
            }
        }
        catch(Error e) {
            warning("Failed to parse wpctl status: %s".printf(e.message));
        }

        return SinkState() {
                   id = -1, name = "Unknown", volume = 0, muted = false
        };
    }
}
}
