[DBus (name = "org.gnome.SettingsDaemon.Power.Screen")]
private interface BrightnessSettings : GLib.Object {
    public abstract int brightness {get; set; }
}
namespace niki {
    public class CameraFlash : Gtk.Window {
        private uint fade_timeout = 0;
        private uint flash_timeout = 0;
        private int start_brighnest;
        public signal bool capture_now ();
        private new BrightnessSettings? brightness_settings;

        construct {
            var headerbar = new Gtk.HeaderBar ();
            headerbar.has_subtitle = false;
            headerbar.show_close_button = false;
            headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            headerbar.get_style_context ().add_class ("default-decoration");
            set_titlebar (headerbar);
            headerbar.hide ();
            try {
                brightness_settings = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SettingsDaemon.Power",
                    "/org/gnome/SettingsDaemon/Power", DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
            } catch (IOError e) {
                warning (e.message);
            }
        }

        private bool flash_opacity_fade () {
            opacity *= 0.5;
            if (opacity <= 0.1) {
                set_keep_above (false);
                destroy ();
                if (lid_detect ()) {
                    brightness_settings.brightness = start_brighnest + 1;
                }
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = NikiApp.settings.get_boolean ("dark-style");
                fade_timeout = 0;
                return Source.REMOVE;
            } else {
                opacity = opacity;
            }
            return Source.CONTINUE;
        }

        private bool flash_start_fade () {
            if (!get_screen ().is_composited ()) {
                destroy ();
                return Source.REMOVE;
            }
            Idle.add (() => {
                return capture_now ();
            });
            fade_timeout = Timeout.add (20, flash_opacity_fade);
            flash_timeout = 0;
            return Source.REMOVE;
        }

        public void flash_now () {
            if (flash_timeout > 0) {
                Source.remove (flash_timeout);
                flash_timeout = 0;
            }
            if (fade_timeout > 0) {
                Source.remove (fade_timeout);
                fade_timeout = 0;
            }
            Gdk.Screen screen_win  = window.get_toplevel ().get_screen ();
            Gdk.Monitor monitor_primary = screen_win.get_display ().get_primary_monitor ();
            Gdk.Rectangle rect = monitor_primary.get_workarea ();
            set_transient_for (window);
            resize (rect.width, rect.height);
            move (rect.x, rect.y);
            opacity = 1;
            set_keep_above (true);
            get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;
            show_all ();
            if (lid_detect ()) {
                start_brighnest = brightness_settings.brightness;
            }
            flash_timeout = Timeout.add (400, flash_start_fade);
            Idle.add (bright_now);
        }
        private static bool lid_detect () {
            var interface_path = File.new_for_path ("/proc/acpi/button/lid/");
            try {
                var enumerator = interface_path.enumerate_children ( GLib.FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
                FileInfo lid;
                if ((lid = enumerator.next_file ()) != null) {
                    return true;
                }
                enumerator.close ();
            } catch (GLib.Error err) {
                critical ("%s", err.message);
            }
            return false;
        }
        private bool bright_now () {
            if (lid_detect ()) {
                brightness_settings.brightness = 80;
            }
            return Source.REMOVE;
        }
    }
}
