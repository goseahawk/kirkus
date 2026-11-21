#!/usr/bin/env python3
"""The live USB's start screen: the kirkus logo and two big buttons, Connect to Wi-Fi and
Install kirkus, each of which opens a terminal window. Started by kirk-live-gui."""
import os
import subprocess
import tkinter as tk

HERE = os.path.dirname(os.path.abspath(__file__))
BG, TILE, TILE_HOVER = "#000000", "#0b1020", "#162038"
CREAM, BLUE, SLATE, GREEN, AMBER = "#fff8ec", "#5590b4", "#aeb6c8", "#7fc79a", "#e0b25c"
FONT = "Noto Sans"


def version():
    try:
        return open("/etc/kirk-version").read().strip()
    except OSError:
        return ""


def network():
    """('wifi', name) / ('ethernet', '') when connected, else None."""
    try:
        out = subprocess.run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"],
                             capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    for line in out.splitlines():
        parts = line.split(":", 2)
        if len(parts) == 3 and parts[1] == "connected" and parts[0] in ("wifi", "ethernet"):
            return parts[0], parts[2].replace("\\:", ":")
    return None


def terminal(title, command):
    """Open an xterm in the kirkus colours running command; returns the process."""
    return subprocess.Popen([
        "xterm", "-title", title, "-geometry", "100x32",
        "-fa", "Noto Sans Mono", "-fs", "12",
        "-bg", TILE, "-fg", CREAM, "-cr", BLUE, "-bc",
        "-e", "bash", "-c", command,
    ])


class Launcher:
    def __init__(self, root):
        self.root, self.procs = root, {}
        sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
        self.k = k = max(0.75, min(sh / 900, 2.0))          # scale everything to the screen
        root.title("kirkus")
        root.configure(bg=BG)
        root.geometry(f"{sw}x{sh}+0+0")
        try:
            root.attributes("-type", "desktop")             # stays behind the terminal windows
        except tk.TclError:
            pass

        page = tk.Frame(root, bg=BG)
        page.place(relx=0.5, rely=0.47, anchor="center")

        self.logo = tk.PhotoImage(file=os.path.join(HERE, "wordmark.png"))
        tk.Label(page, image=self.logo, bg=BG).pack()
        tk.Label(page, text=f"LIVE USB  {version()}".strip(), bg=BG, fg=SLATE,
                 font=(FONT, int(9 * k))).pack(pady=(int(10 * k), int(44 * k)))

        tiles = tk.Frame(page, bg=BG)
        tiles.pack()
        self.wifi = self.tile(tiles, "wifi.png", "Connect to Wi-Fi", "wifi",
                              "Connect to Wi-Fi", "/usr/bin/nmtui")
        self.install = self.tile(tiles, "install.png", "Install kirkus", "install",
                                 "Install kirkus",
                                 "/root/install.sh; echo; read -rp 'Press Enter to close this window. '")
        self.install["sub"].config(text="Asks before changing anything")

        bar = tk.Frame(root, bg=BG)
        bar.place(relx=0.5, rely=0.94, anchor="center")
        for text, cmd in (("Restart", ["systemctl", "reboot"]),
                          ("Power off", ["systemctl", "poweroff"]),
                          ("Text console", None)):
            b = tk.Label(bar, text=text, bg=BG, fg=SLATE, font=(FONT, int(10 * k)),
                         cursor="hand2", padx=int(14 * k))
            b.pack(side="left")
            b.bind("<Enter>", lambda e, b=b: b.config(fg=CREAM))
            b.bind("<Leave>", lambda e, b=b: b.config(fg=SLATE))
            b.bind("<Button-1>", lambda e, c=cmd: subprocess.Popen(c) if c else root.destroy())

        self.refresh()

    def tile(self, parent, icon, label, key, title, command):
        k = self.k
        f = tk.Frame(parent, bg=TILE, cursor="hand2", width=int(260 * k), height=int(220 * k))
        f.pack(side="left", padx=int(16 * k))
        f.pack_propagate(False)
        img = tk.PhotoImage(file=os.path.join(HERE, icon))
        icon_l = tk.Label(f, image=img, bg=TILE)
        icon_l.image = img
        icon_l.pack(pady=(int(30 * k), int(10 * k)))
        name = tk.Label(f, text=label, bg=TILE, fg=CREAM, font=(FONT, int(14 * k), "bold"))
        name.pack()
        sub = tk.Label(f, text="", bg=TILE, fg=SLATE, font=(FONT, int(9 * k)),
                       wraplength=int(230 * k), justify="center")
        sub.pack(pady=(int(6 * k), 0))
        parts = (f, icon_l, name, sub)

        def paint(colour):
            for w in parts:
                w.config(bg=colour)

        def click(_e):
            p = self.procs.get(key)
            if p and p.poll() is None:
                return                                     # its window is already open
            self.procs[key] = terminal(title, command)
            self.refresh()

        for w in parts:
            w.bind("<Enter>", lambda e: paint(TILE_HOVER))
            w.bind("<Leave>", lambda e: paint(TILE))
            w.bind("<Button-1>", click)
        return {"frame": f, "name": name, "sub": sub, "key": key, "label": label}

    def refresh(self):
        net = network()
        if net is None:
            self.wifi["sub"].config(text="Not connected yet", fg=AMBER)
        elif net[0] == "wifi":
            self.wifi["sub"].config(text=f"Connected to {net[1]}", fg=GREEN)
        else:
            self.wifi["sub"].config(text="Connected by cable", fg=GREEN)
        for t in (self.wifi, self.install):
            p = self.procs.get(t["key"])
            busy = p is not None and p.poll() is None
            t["name"].config(text=t["label"] + ("  (open)" if busy else ""))
        self.root.after(2000, self.refresh)


if __name__ == "__main__":
    root = tk.Tk()
    Launcher(root)
    root.mainloop()
