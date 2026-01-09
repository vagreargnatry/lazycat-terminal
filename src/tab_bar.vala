// Chrome-style Tab Bar with custom drawing

public class TabBar : Gtk.DrawingArea {
    private List<TabInfo> tab_infos;
    private int active_index = -1;
    private int hover_index = -1;

    private const int TAB_HEIGHT = 34;
    private const int TAB_MIN_WIDTH = 80;
    private const int TAB_MAX_WIDTH = 200;
    private const int TAB_OVERLAP = 16;
    private const int TAB_PADDING = 12;
    private const int CLOSE_BTN_SIZE = 16;
    private const int NEW_TAB_BTN_SIZE = 28;
    private const int CORNER_RADIUS = 10;

    public signal void tab_selected(int index);
    public signal void tab_closed(int index);
    public signal void new_tab_requested();

    private class TabInfo {
        public string title;
        public int x;
        public int width;

        public TabInfo(string title) {
            this.title = title;
            this.x = 0;
            this.width = 0;
        }
    }

    public TabBar() {
        Object();
    }

    construct {
        tab_infos = new List<TabInfo>();

        set_content_height(TAB_HEIGHT + 4);
        set_draw_func(draw_tabs);

        // Mouse events
        var motion = new Gtk.EventControllerMotion();
        motion.motion.connect(on_motion);
        motion.leave.connect(on_leave);
        add_controller(motion);

        var click = new Gtk.GestureClick();
        click.set_button(0);
        click.pressed.connect(on_click);
        add_controller(click);
    }

    private void draw_tabs(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Calculate tab positions and widths
        calculate_tab_layout(width);

        // Draw background
        cr.set_source_rgba(0.16, 0.16, 0.16, 0.9);
        cr.rectangle(0, 0, width, height);
        cr.fill();

        // Draw inactive tabs first (back to front for overlap)
        for (int i = (int)tab_infos.length() - 1; i >= 0; i--) {
            if (i != active_index) {
                draw_tab(cr, i, height, false);
            }
        }

        // Draw active tab on top
        if (active_index >= 0 && active_index < tab_infos.length()) {
            draw_tab(cr, active_index, height, true);
        }

        // Draw new tab button
        draw_new_tab_button(cr, width, height);

        // Draw window controls (minimize, maximize, close)
        draw_window_controls(cr, width, height);
    }

    private void calculate_tab_layout(int available_width) {
        if (tab_infos.length() == 0) return;

        // Reserve space for new tab button and window controls
        int reserved = NEW_TAB_BTN_SIZE + 20 + 90;
        int usable_width = available_width - reserved - TAB_PADDING;

        // Calculate tab width
        int overlap_total = (int)(tab_infos.length() - 1) * TAB_OVERLAP;
        int tab_width = (usable_width + overlap_total) / (int)tab_infos.length();
        tab_width = int.min(tab_width, TAB_MAX_WIDTH);
        tab_width = int.max(tab_width, TAB_MIN_WIDTH);

        // Set positions
        int x = TAB_PADDING;
        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            info.x = x;
            info.width = tab_width;
            x += tab_width - TAB_OVERLAP;
        }
    }

    private void draw_tab(Cairo.Context cr, int index, int height, bool is_active) {
        var info = tab_infos.nth_data((uint)index);
        if (info == null) return;

        double x = info.x;
        double w = info.width;
        double h = TAB_HEIGHT;
        double y = height - h;

        // Tab title
        draw_tab_title(cr, info, x, y, w, h, is_active);

        // Draw underline for active tab (full width of tab)
        if (is_active) {
            double underline_y = height - 2;

            cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
            cr.set_line_width(2.0);
            cr.move_to(x, underline_y);
            cr.line_to(x + w, underline_y);
            cr.stroke();
        }
    }

    private void draw_tab_title(Cairo.Context cr, TabInfo info, double x, double y, double w, double h, bool is_active) {
        cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(12);

        // Truncate title if needed
        // Text area: tab width - 40px (20px padding on each side)
        string title = info.title;
        double max_text_width = w - 40;

        Cairo.TextExtents extents;
        cr.text_extents(title, out extents);

        if (extents.width > max_text_width) {
            while (title.length > 3 && extents.width > max_text_width) {
                title = title.substring(0, title.length - 4) + "...";
                cr.text_extents(title, out extents);
            }
        }

        // Center text horizontally in tab
        double text_x = x + (w - extents.width) / 2;
        double text_y = y + h / 2 + extents.height / 2 - 2;

        if (is_active) {
            cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
        } else {
            cr.set_source_rgba(0.7, 0.7, 0.7, 1.0);
        }

        cr.move_to(text_x, text_y);
        cr.show_text(title);
    }

    private void draw_new_tab_button(Cairo.Context cr, int width, int height) {
        double btn_x = get_new_tab_button_x();
        double btn_y = (height - NEW_TAB_BTN_SIZE) / 2;
        double center_x = btn_x + NEW_TAB_BTN_SIZE / 2;
        double center_y = btn_y + NEW_TAB_BTN_SIZE / 2;

        // Plus icon only, no background
        cr.set_line_width(2.0);
        cr.set_source_rgba(0.7, 0.7, 0.7, 1.0);

        double offset = 6;
        cr.move_to(center_x - offset, center_y);
        cr.line_to(center_x + offset, center_y);
        cr.stroke();

        cr.move_to(center_x, center_y - offset);
        cr.line_to(center_x, center_y + offset);
        cr.stroke();
    }

    private void draw_window_controls(Cairo.Context cr, int width, int height) {
        double btn_size = 12;
        double spacing = 8;
        double start_x = width - 80;
        double y = height / 2;

        // Colors for macOS-style buttons
        double[,] colors = {
            {0.35, 0.78, 0.35, 1.0},  // Green (minimize)
            {0.98, 0.75, 0.18, 1.0},  // Yellow (maximize)
            {0.98, 0.38, 0.35, 1.0}   // Red (close)
        };

        for (int i = 0; i < 3; i++) {
            double x = start_x + i * (btn_size + spacing);
            cr.arc(x, y, btn_size / 2, 0, 2 * Math.PI);
            cr.set_source_rgba(colors[i, 0], colors[i, 1], colors[i, 2], colors[i, 3]);
            cr.fill();
        }
    }

    private double get_new_tab_button_x() {
        if (tab_infos.length() == 0) {
            return TAB_PADDING;
        }
        var last = tab_infos.nth_data((uint)(tab_infos.length() - 1));
        return last.x + last.width - TAB_OVERLAP + 8;
    }

    private void on_motion(double x, double y) {
        int old_hover = hover_index;

        hover_index = -1;

        // Check tabs
        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            if (x >= info.x && x <= info.x + info.width && y <= TAB_HEIGHT + 4) {
                hover_index = i;
                break;
            }
        }

        if (old_hover != hover_index) {
            queue_draw();
        }
    }

    private void on_leave() {
        if (hover_index != -1) {
            hover_index = -1;
            queue_draw();
        }
    }

    private void on_click(int n_press, double x, double y) {
        // Check new tab button
        double btn_x = get_new_tab_button_x();
        if (x >= btn_x && x <= btn_x + NEW_TAB_BTN_SIZE && y <= TAB_HEIGHT + 4) {
            new_tab_requested();
            return;
        }

        // Check window controls
        int width = get_width();
        if (x >= width - 80) {
            double btn_size = 12;
            double spacing = 8;
            double start_x = width - 80;

            for (int i = 0; i < 3; i++) {
                double bx = start_x + i * (btn_size + spacing);
                double dist = Math.sqrt(Math.pow(x - bx, 2) + Math.pow(y - get_height() / 2, 2));
                if (dist <= btn_size / 2) {
                    if (i == 0) {
                        // Minimize
                        var window = get_root() as Gtk.Window;
                        if (window != null) window.minimize();
                    } else if (i == 1) {
                        // Maximize
                        var window = get_root() as Gtk.Window;
                        if (window != null) {
                            if (window.is_maximized()) {
                                window.unmaximize();
                            } else {
                                window.maximize();
                            }
                        }
                    } else {
                        // Close
                        var window = get_root() as Gtk.Window;
                        if (window != null) window.close();
                    }
                    return;
                }
            }
        }

        // Check tab selection
        if (hover_index >= 0 && hover_index != active_index) {
            active_index = hover_index;
            tab_selected(active_index);
            queue_draw();
        }
    }

    public bool is_over_tab(int x, int y) {
        for (int i = 0; i < tab_infos.length(); i++) {
            var info = tab_infos.nth_data((uint)i);
            if (x >= info.x && x <= info.x + info.width && y <= TAB_HEIGHT) {
                return true;
            }
        }

        // Also check new tab button and window controls
        if (x >= get_new_tab_button_x() && x <= get_new_tab_button_x() + NEW_TAB_BTN_SIZE) {
            return true;
        }
        if (x >= get_width() - 80) {
            return true;
        }

        return false;
    }

    public void add_tab(string title) {
        tab_infos.append(new TabInfo(title));
        queue_draw();
    }

    public void remove_tab(int index) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            tab_infos.remove(info);

            if (active_index >= tab_infos.length()) {
                active_index = (int)tab_infos.length() - 1;
            }
            queue_draw();
        }
    }

    public void set_active_tab(int index) {
        if (index >= 0 && index < tab_infos.length()) {
            active_index = index;
            queue_draw();
        }
    }

    public void update_tab_title(int index, string title) {
        if (index >= 0 && index < tab_infos.length()) {
            var info = tab_infos.nth_data((uint)index);
            info.title = title;
            queue_draw();
        }
    }

    public int get_active_index() {
        return active_index;
    }
}
