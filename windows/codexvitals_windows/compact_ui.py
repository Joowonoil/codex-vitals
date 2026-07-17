from __future__ import annotations

import tkinter as tk
import tkinter.font as tkfont
from dataclasses import dataclass
from typing import Any, Callable

from .models import AccountRuntimeState, StoredAccount, StoredAccountSource
from .presentation_logic import compact_reset_countdown, quota_window_label, quota_window_slots


def draw_rounded_rectangle(
    canvas: tk.Canvas,
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    radius: float,
    *,
    fill: str,
    outline: str = "",
    width: int = 1,
) -> int:
    radius = max(0.0, min(radius, (x2 - x1) / 2, (y2 - y1) / 2))
    points = [
        x1 + radius, y1,
        x2 - radius, y1,
        x2, y1,
        x2, y1 + radius,
        x2, y2 - radius,
        x2, y2,
        x2 - radius, y2,
        x1 + radius, y2,
        x1, y2,
        x1, y2 - radius,
        x1, y1 + radius,
        x1, y1,
    ]
    return canvas.create_polygon(
        points,
        smooth=True,
        splinesteps=24,
        fill=fill,
        outline=outline,
        width=width,
    )


class HoverTooltip:
    def __init__(self, widget: tk.Widget, text: str, palette: dict[str, str], delay_ms: int = 550) -> None:
        self.widget = widget
        self.text = text
        self.palette = palette
        self.delay_ms = delay_ms
        self._job: str | None = None
        self._window: tk.Toplevel | None = None
        widget.bind("<Enter>", self._schedule, add="+")
        widget.bind("<Leave>", self._hide, add="+")
        widget.bind("<ButtonPress>", self._hide, add="+")

    def _schedule(self, _: tk.Event[Any]) -> None:
        self._cancel()
        self._job = self.widget.after(self.delay_ms, self._show)

    def _cancel(self) -> None:
        if self._job is None:
            return
        try:
            self.widget.after_cancel(self._job)
        except tk.TclError:
            pass
        self._job = None

    def _show(self) -> None:
        self._job = None
        if not self.text or not self.widget.winfo_exists():
            return
        x = self.widget.winfo_pointerx() + 12
        y = self.widget.winfo_pointery() + 14
        window = tk.Toplevel(self.widget)
        window.wm_overrideredirect(True)
        window.wm_geometry(f"+{x}+{y}")
        window.configure(bg=self.palette["hairline"])
        tk.Label(
            window,
            text=self.text,
            bg=self.palette["tooltip"],
            fg=self.palette["text"],
            font=("Segoe UI", 9),
            justify="left",
            padx=8,
            pady=5,
        ).pack(padx=1, pady=1)
        self._window = window

    def _hide(self, _: tk.Event[Any] | None = None) -> None:
        self._cancel()
        if self._window is not None:
            try:
                self._window.destroy()
            except tk.TclError:
                pass
        self._window = None


class IconButton(tk.Canvas):
    def __init__(
        self,
        parent: tk.Widget,
        *,
        icon: str,
        command: Callable[[], None],
        palette: dict[str, str],
        font: tuple[str, int] | tuple[str, int, str],
        tooltip: str,
        tone: str | None = None,
        size: int = 28,
    ) -> None:
        super().__init__(
            parent,
            width=size,
            height=size,
            bg=parent.cget("bg"),
            highlightthickness=0,
            bd=0,
            cursor="hand2",
            takefocus=0,
        )
        self.icon = icon
        self.command = command
        self.palette = palette
        self.font = font
        self.tone = tone
        self.size = size
        self.enabled = True
        self.selected = False
        self._hovering = False
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_click)
        self.bind("<Configure>", self._redraw)
        HoverTooltip(self, tooltip, palette)
        self._redraw()

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = enabled
        self.configure(cursor="hand2" if enabled else "arrow")
        self._redraw()

    def set_selected(self, selected: bool) -> None:
        self.selected = selected
        self._redraw()

    def set_icon(self, icon: str) -> None:
        self.icon = icon
        self._redraw()

    def set_tone(self, tone: str | None) -> None:
        self.tone = tone
        self._redraw()

    def _on_enter(self, _: tk.Event[Any]) -> None:
        self._hovering = True
        self._redraw()

    def _on_leave(self, _: tk.Event[Any]) -> None:
        self._hovering = False
        self._redraw()

    def _on_click(self, _: tk.Event[Any]) -> None:
        if self.enabled:
            self.command()

    def _redraw(self, _: tk.Event[Any] | None = None) -> None:
        self.delete("all")
        width = max(1, self.winfo_width())
        height = max(1, self.winfo_height())
        if self.selected:
            fill = self.palette["control_selected"]
            border = self.palette["control_border"]
        elif self._hovering and self.enabled:
            fill = self.palette["control_hover"]
            border = self.palette["control_border"]
        else:
            fill = self.cget("bg")
            border = self.cget("bg")
        draw_rounded_rectangle(
            self,
            1,
            1,
            width - 2,
            height - 2,
            7,
            fill=fill,
            outline=border,
        )
        color = self.tone or self.palette["muted"]
        if not self.enabled:
            color = self.palette["disabled"]
        self.create_text(width / 2, height / 2, text=self.icon, fill=color, font=self.font)


class ToggleSwitch(tk.Canvas):
    def __init__(
        self,
        parent: tk.Widget,
        *,
        value: bool,
        command: Callable[[bool], None],
        palette: dict[str, str],
        tooltip: str,
        width: int = 42,
        height: int = 24,
    ) -> None:
        super().__init__(
            parent,
            width=width,
            height=height,
            bg=parent.cget("bg"),
            highlightthickness=0,
            bd=0,
            cursor="hand2",
            takefocus=0,
        )
        self.value = value
        self.command = command
        self.palette = palette
        self.switch_width = width
        self.switch_height = height
        self.enabled = True
        self._hovering = False
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_click)
        self.bind("<Configure>", self._redraw)
        HoverTooltip(self, tooltip, palette)
        self._redraw()

    def set_value(self, value: bool) -> None:
        self.value = value
        self._redraw()

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = enabled
        self.configure(cursor="hand2" if enabled else "arrow")
        self._redraw()

    def _on_enter(self, _: tk.Event[Any]) -> None:
        self._hovering = True
        self._redraw()

    def _on_leave(self, _: tk.Event[Any]) -> None:
        self._hovering = False
        self._redraw()

    def _on_click(self, _: tk.Event[Any]) -> None:
        if not self.enabled:
            return
        self.value = not self.value
        self._redraw()
        self.command(self.value)

    def _redraw(self, _: tk.Event[Any] | None = None) -> None:
        self.delete("all")
        width = max(1, self.winfo_width())
        height = max(1, self.winfo_height())
        track_fill = self.palette["success"] if self.value else self.palette["switch_off"]
        border = self.palette["control_border"] if self._hovering else track_fill
        if not self.enabled:
            track_fill = self.palette["disabled"]
            border = track_fill
        draw_rounded_rectangle(
            self,
            1,
            1,
            width - 2,
            height - 2,
            (height - 2) / 2,
            fill=track_fill,
            outline=border,
        )
        knob_radius = max(4, (height - 8) / 2)
        knob_x = width - 5 - knob_radius if self.value else 5 + knob_radius
        self.create_oval(
            knob_x - knob_radius,
            (height / 2) - knob_radius,
            knob_x + knob_radius,
            (height / 2) + knob_radius,
            fill=self.palette["switch_knob"],
            outline="",
        )


@dataclass(slots=True)
class AccountRowActions:
    switch: Callable[[], None]
    refresh: Callable[[], None]
    reauthenticate: Callable[[], None]
    rename: Callable[[], None]
    copy_email: Callable[[], None]
    open_folder: Callable[[], None]
    remove: Callable[[], None]


class AccountRow(tk.Canvas):
    HEIGHT = 58
    METRIC_WIDTH = 150
    SOURCE_WIDTH = 68
    ACTION_WIDTH = 76
    MENU_WIDTH = 28

    def __init__(
        self,
        parent: tk.Widget,
        *,
        account: StoredAccount,
        state: AccountRuntimeState,
        palette: dict[str, str],
        fonts: dict[str, tuple[Any, ...]],
        is_active: bool,
        can_switch: bool,
        needs_reauthentication: bool,
        is_reauthenticating: bool,
        actions: AccountRowActions,
    ) -> None:
        super().__init__(
            parent,
            height=self.HEIGHT,
            bg=palette["list"],
            highlightthickness=0,
            bd=0,
            takefocus=0,
        )
        self.account = account
        self.state = state
        self.palette = palette
        self.fonts = fonts
        self.is_active = is_active
        self.can_switch = can_switch
        self.needs_reauthentication = needs_reauthentication
        self.is_reauthenticating = is_reauthenticating
        self.actions = actions
        self._hovering = False
        self._hover_region: str | None = None
        self._action_region = (0, 0, 0, 0)
        self._menu_region = (0, 0, 0, 0)
        self._font_cache = {name: tkfont.Font(font=font) for name, font in fonts.items()}

        self.bind("<Configure>", self._redraw)
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Motion>", self._on_motion)
        self.bind("<Button-1>", self._on_click)
        self.bind("<Button-3>", self._show_menu)

        identity = account.email_hint or account.display_name
        if account.nickname:
            identity = f"{account.nickname}\n{identity}"
        HoverTooltip(self, identity, palette)

    def _on_enter(self, _: tk.Event[Any]) -> None:
        self._hovering = True
        self._redraw()

    def _on_leave(self, _: tk.Event[Any]) -> None:
        self._hovering = False
        self._hover_region = None
        self.configure(cursor="arrow")
        self._redraw()

    def _on_motion(self, event: tk.Event[Any]) -> None:
        region = None
        if self._contains(self._menu_region, event.x, event.y):
            region = "menu"
        elif self._contains(self._action_region, event.x, event.y) and self._row_action()[1] is not None:
            region = "action"
        if region != self._hover_region:
            self._hover_region = region
            self.configure(cursor="hand2" if region else "arrow")
            self._redraw()

    def _on_click(self, event: tk.Event[Any]) -> None:
        if self._contains(self._menu_region, event.x, event.y):
            self._show_menu(event)
            return
        if self._contains(self._action_region, event.x, event.y):
            _, command, _ = self._row_action()
            if command is not None:
                command()

    @staticmethod
    def _contains(region: tuple[int, int, int, int], x: int, y: int) -> bool:
        x1, y1, x2, y2 = region
        return x1 <= x <= x2 and y1 <= y <= y2

    def _redraw(self, _: tk.Event[Any] | None = None) -> None:
        self.delete("all")
        width = max(1, self.winfo_width())
        if width < 100:
            return

        if self.is_active:
            row_fill = self.palette["active_row_hover"] if self._hovering else self.palette["active_row"]
            row_border = self.palette["active_border"]
        elif self._hovering:
            row_fill = self.palette["row_hover"]
            row_border = self.palette["row_hover_border"]
        else:
            row_fill = self.palette["list"]
            row_border = self.palette["list"]

        draw_rounded_rectangle(
            self,
            4,
            2,
            width - 4,
            self.HEIGHT - 3,
            10,
            fill=row_fill,
            outline=row_border,
        )
        if self.is_active:
            draw_rounded_rectangle(
                self,
                7,
                10,
                10,
                self.HEIGHT - 11,
                2,
                fill=self.palette["success"],
            )

        menu_right = width - 9
        menu_left = menu_right - self.MENU_WIDTH
        action_right = menu_left - 6
        action_left = action_right - self.ACTION_WIDTH
        second_metric_left = action_left - 8 - self.METRIC_WIDTH
        first_metric_left = second_metric_left - 6 - self.METRIC_WIDTH
        source_left = first_metric_left - 8 - self.SOURCE_WIDTH
        identity_left = 42
        identity_right = max(identity_left + 120, source_left - 10)

        self._draw_status_icon(24, self.HEIGHT / 2)
        self._draw_identity(identity_left, identity_right)
        self._draw_source_chip(source_left, 18)

        slots = quota_window_slots(self.state.snapshot)
        self._draw_metric(first_metric_left, slots.get("5h"), "5h")
        self._draw_metric(second_metric_left, slots.get("1w"), "1w")

        self._action_region = (action_left, 16, action_right, 42)
        self._menu_region = (menu_left, 15, menu_right, 43)
        self._draw_action_button(action_left, action_right)
        self._draw_menu_button(menu_left, menu_right)

        if not self.is_active:
            self.create_line(
                14,
                self.HEIGHT - 1,
                width - 14,
                self.HEIGHT - 1,
                fill=self.palette["divider"],
            )

    def _draw_status_icon(self, x: float, y: float) -> None:
        if self.state.error_message:
            fill = self.palette["warning"]
        elif self.is_active:
            fill = self.palette["success"]
        elif self.state.snapshot is not None:
            fill = self.palette["neutral"]
        else:
            fill = self.palette["disabled"]
        self.create_oval(x - 6, y - 6, x + 6, y + 6, fill=fill, outline=self.palette["list_border"])
        if self.is_active:
            self.create_line(x - 3, y, x - 1, y + 3, fill=self.palette["check"], width=2)
            self.create_line(x - 1, y + 3, x + 4, y - 3, fill=self.palette["check"], width=2)
        elif self.state.is_loading:
            self.create_arc(
                x - 3,
                y - 3,
                x + 3,
                y + 3,
                start=40,
                extent=245,
                style="arc",
                outline=self.palette["check"],
                width=1,
            )

    def _draw_identity(self, left: int, right: int) -> None:
        plan = self.state.snapshot.plan_display_name if self.state.snapshot else None
        plan = plan if plan and plan != "Unknown" else None
        if plan:
            normalized_plan = plan.lower().replace(" ", "")
            if normalized_plan == "prolite":
                plan = "Pro Lite"
        if self.account.nickname:
            title_y = 18
            email_y = 39
            title = self.account.nickname
            email = self.account.email_hint or self.account.display_name
        else:
            title_y = 29
            email_y = None
            title = self.account.email_hint or self.account.display_name
            email = ""

        cursor = left
        if plan:
            plan_bg, plan_fg, plan_border = self._plan_tone(plan)
            plan_width = max(31, self._font_cache["badge"].measure(plan) + 10)
            draw_rounded_rectangle(
                self,
                cursor,
                title_y - 9,
                cursor + plan_width,
                title_y + 8,
                8,
                fill=plan_bg,
                outline=plan_border,
            )
            self.create_text(
                cursor + plan_width / 2,
                title_y,
                text=plan,
                fill=plan_fg,
                font=self.fonts["badge"],
            )
            cursor += plan_width + 7

        available = max(40, right - cursor)
        title = self._ellipsize(title, "row_title", available)
        self.create_text(
            cursor,
            title_y,
            text=title,
            fill=self.palette["text"],
            font=self.fonts["row_title"],
            anchor="w",
        )
        if email_y is not None:
            email = self._ellipsize(email, "row_meta", max(40, right - left))
            self.create_text(
                left,
                email_y,
                text=email,
                fill=self.palette["muted"],
                font=self.fonts["row_meta"],
                anchor="w",
            )

    def _draw_source_chip(self, left: int, top: int) -> None:
        text = "System" if self.account.source is StoredAccountSource.AMBIENT else "Managed"
        draw_rounded_rectangle(
            self,
            left,
            top,
            left + self.SOURCE_WIDTH,
            top + 22,
            7,
            fill=self.palette["source_bg"],
            outline=self.palette["source_border"],
        )
        self.create_text(
            left + self.SOURCE_WIDTH / 2,
            top + 11,
            text=text,
            fill=self.palette["source_text"],
            font=self.fonts["chip"],
        )

    def _draw_metric(self, left: int, window: Any | None, slot_label: str) -> None:
        top = 17
        quota_width = 96
        reset_left = left + quota_width + 4
        reset_width = self.METRIC_WIDTH - quota_width - 4
        draw_rounded_rectangle(
            self,
            left,
            top,
            left + quota_width,
            top + 24,
            7,
            fill=self.palette["metric"],
            outline=self.palette["metric_border"],
        )
        draw_rounded_rectangle(
            self,
            reset_left,
            top,
            reset_left + reset_width,
            top + 24,
            7,
            fill=self.palette["metric"],
            outline=self.palette["metric_border"],
        )

        label = quota_window_label(window) if window is not None else slot_label
        remaining = window.remaining_percent if window is not None else None
        value = f"{remaining:.0f}%" if remaining is not None else "--"
        color = self._quota_color(remaining) if remaining is not None else self.palette["disabled"]
        self.create_text(
            left + 8,
            top + 12,
            text=label,
            fill=self.palette["muted"],
            font=self.fonts["metric_label"],
            anchor="w",
        )

        track_left = left + 28
        track_right = left + 58
        track_top = top + 10
        draw_rounded_rectangle(
            self,
            track_left,
            track_top,
            track_right,
            track_top + 5,
            3,
            fill=self.palette["track"],
        )
        if remaining is not None and remaining > 0.001:
            fill_width = max(2, (track_right - track_left) * min(100.0, remaining) / 100.0)
            draw_rounded_rectangle(
                self,
                track_left,
                track_top,
                track_left + fill_width,
                track_top + 5,
                3,
                fill=color,
            )
        self.create_text(
            left + quota_width - 7,
            top + 12,
            text=value,
            fill=color,
            font=self.fonts["metric_value"],
            anchor="e",
        )
        reset_text = compact_reset_countdown(window.reset_at) if window is not None else "--"
        self.create_text(
            reset_left + reset_width / 2,
            top + 12,
            text=reset_text,
            fill=self.palette["muted"],
            font=self.fonts["metric_reset"],
        )

    def _draw_action_button(self, left: int, right: int) -> None:
        text, command, kind = self._row_action()
        hovering = self._hover_region == "action" and command is not None
        if kind == "active":
            fill = self.palette["active_control"]
            border = self.palette["active_border"]
            foreground = self.palette["success"]
        elif kind == "warning":
            fill = self.palette["warning_control_hover"] if hovering else self.palette["warning_control"]
            border = self.palette["warning_border"]
            foreground = self.palette["warning"]
        elif command is not None:
            fill = self.palette["control_hover"] if hovering else self.palette["control"]
            border = self.palette["control_border"]
            foreground = self.palette["text"]
        else:
            fill = self.palette["metric"]
            border = self.palette["metric_border"]
            foreground = self.palette["disabled"]
        draw_rounded_rectangle(
            self,
            left,
            17,
            right,
            41,
            8,
            fill=fill,
            outline=border,
        )
        self.create_text(
            (left + right) / 2,
            29,
            text=text,
            fill=foreground,
            font=self.fonts["action"],
        )

    def _draw_menu_button(self, left: int, right: int) -> None:
        hovering = self._hover_region == "menu"
        fill = self.palette["control_hover"] if hovering else self.palette["list"]
        border = self.palette["control_border"] if hovering else self.palette["list"]
        draw_rounded_rectangle(
            self,
            left,
            16,
            right,
            42,
            7,
            fill=fill,
            outline=border,
        )
        center = (left + right) / 2
        for offset in (-5, 0, 5):
            self.create_oval(
                center + offset - 1.2,
                27.8,
                center + offset + 1.2,
                30.2,
                fill=self.palette["muted"],
                outline="",
            )

    def _row_action(self) -> tuple[str, Callable[[], None] | None, str]:
        if self.is_reauthenticating:
            return "Signing in", None, "warning"
        if self.needs_reauthentication:
            return "Reconnect", self.actions.reauthenticate, "warning"
        if self.is_active:
            return "Active", None, "active"
        if self.can_switch:
            return "Switch", self.actions.switch, "normal"
        return "Unavailable", None, "normal"

    def _show_menu(self, event: tk.Event[Any]) -> None:
        menu = tk.Menu(
            self,
            tearoff=False,
            bg=self.palette["menu"],
            fg=self.palette["text"],
            activebackground=self.palette["control_hover"],
            activeforeground=self.palette["text"],
            disabledforeground=self.palette["disabled"],
            relief="flat",
            bd=1,
        )
        if self.is_active:
            menu.add_command(label="Active account", state="disabled")
        elif self.can_switch:
            menu.add_command(label="Switch account", command=self.actions.switch)
        else:
            menu.add_command(label="Switch unavailable", state="disabled")
        menu.add_separator()
        menu.add_command(label="Refresh usage", command=self.actions.refresh)
        menu.add_command(
            label="Reconnect account",
            command=self.actions.reauthenticate,
            state="disabled" if self.is_reauthenticating else "normal",
        )
        menu.add_separator()
        menu.add_command(
            label="Edit alias..." if self.account.nickname else "Set alias...",
            command=self.actions.rename,
        )
        menu.add_command(
            label="Copy email",
            command=self.actions.copy_email,
            state="normal" if self.account.email_hint else "disabled",
        )
        menu.add_command(label="Open account folder", command=self.actions.open_folder)
        if self.account.source.owns_files:
            menu.add_separator()
            menu.add_command(label="Remove account...", command=self.actions.remove)
        try:
            menu.tk_popup(self.winfo_rootx() + event.x, self.winfo_rooty() + event.y)
        finally:
            menu.grab_release()

    def _quota_color(self, remaining: float) -> str:
        if remaining >= 50:
            return self.palette["success"]
        if remaining >= 20:
            return self.palette["yellow"]
        if remaining >= 5:
            return self.palette["warning"]
        if remaining > 0.001:
            return self.palette["danger"]
        return self.palette["neutral"]

    def _plan_tone(self, plan: str) -> tuple[str, str, str]:
        normalized = plan.strip().lower().replace("_", " ").replace("-", " ")
        if "pro" in normalized and "lite" in normalized:
            key = "plan_pro_lite"
        elif normalized == "pro" or normalized.startswith("pro "):
            key = "plan_pro"
        elif normalized == "plus":
            key = "plan_plus"
        elif normalized == "team":
            key = "plan_team"
        else:
            key = "plan_default"
        return (
            self.palette[f"{key}_bg"],
            self.palette[f"{key}_text"],
            self.palette[f"{key}_border"],
        )

    def _ellipsize(self, text: str, font_name: str, max_width: int) -> str:
        font = self._font_cache[font_name]
        if font.measure(text) <= max_width:
            return text
        ellipsis = "..."
        low = 0
        high = len(text)
        while low < high:
            midpoint = (low + high + 1) // 2
            if font.measure(text[:midpoint] + ellipsis) <= max_width:
                low = midpoint
            else:
                high = midpoint - 1
        return text[:low] + ellipsis
