"""Draw the ideal-pipeline figure (fig-ideal-pipeline) as a hand-laid SVG.

Run from the repo root:  python .docs/figures/make_ideal_pipeline.py [classic|budapest|moonrise|darjeeling]
With no argument it writes every theme. Every position comes from the layout
constants below, so boxes stay aligned and centred when labels change; the
themes change only colours, fonts and corner styles.
"""
import sys
from pathlib import Path

THEMES = {
    # The site's original earthy palette.
    "classic": dict(
        file="ideal-pipeline.svg",
        font="Source Sans Pro, Segoe UI, Helvetica Neue, Arial, sans-serif",
        ink="#201e1d", sub="#201e1d", arrow="#444444", title_upper=False,
        data=("#ebddc5", "#7a8a5e"), code=("#f5ead8", "#201e1d"), std=("#dde7f0", "#1f5f99"),
        api="#c67139", consumer="#c67139", placeholder=("#b9ab96", "#7d6f5c"),
        bronze=("#f6e6d6", "#b87333", "#201e1d"), silver=("#f0f0f0", "#8c8c8c", "#201e1d"),
        gold=("#faf1cf", "#c9a227", "#201e1d"), radius=6, node_radius=4, shadow=False,
    ),
    # Three mild palettes after Wes Anderson films. Futura (Century Gothic on
    # Windows), letter-spaced uppercase stage titles, no shadows.
    "budapest": dict(   # The Grand Budapest Hotel: dusty pinks, lilac, powder blue
        file="ideal-pipeline-budapest.svg", font="Futura, Futura PT, Century Gothic, Avenir Next, Trebuchet MS, Segoe UI, sans-serif",
        ink="#3b2a2f", sub="#6b565b", arrow="#a8959a", title_upper=True,
        data=("#f3d9dc", "#b76e79"), code=("#fbf5ef", "#7a5c61"), std=("#dce6ee", "#6f8fa6"),
        api="#c9737f", consumer="#8e6c8a", placeholder=("#d8c3c6", "#a8959a"),
        bronze=("#f7e6dc", "#c98b6b", "#9c5f45"), silver=("#eee9f0", "#a397ae", "#6e6179"),
        gold=("#f7eed6", "#d4b06a", "#9a7a35"), radius=8, node_radius=6, shadow=False,
    ),
    "moonrise": dict(   # Moonrise Kingdom: mustard, khaki, sage, faded red
        file="ideal-pipeline-moonrise.svg", font="Futura, Futura PT, Century Gothic, Avenir Next, Trebuchet MS, Segoe UI, sans-serif",
        ink="#33301f", sub="#625d45", arrow="#a39f86", title_upper=True,
        data=("#f1e4bb", "#b89b4a"), code=("#fcf8ec", "#5e5a44"), std=("#e0e7dc", "#7d9481"),
        api="#7d8b5e", consumer="#b5553c", placeholder=("#d6d1b8", "#a39f86"),
        bronze=("#f5e7d2", "#c08552", "#8f5a2e"), silver=("#ecebe0", "#9a9a7f", "#626249"),
        gold=("#f7eecb", "#c9a44c", "#8a6d24"), radius=8, node_radius=6, shadow=False,
    ),
    "darjeeling": dict(   # The Darjeeling Limited: apricot, terracotta, muted teal
        file="ideal-pipeline-darjeeling.svg", font="Futura, Futura PT, Century Gothic, Avenir Next, Trebuchet MS, Segoe UI, sans-serif",
        ink="#2e2a28", sub="#5f5550", arrow="#a3a09c", title_upper=True,
        data=("#f4dac9", "#c9826b"), code=("#fdf8f1", "#5a4a42"), std=("#e2ecef", "#6f98a8"),
        api="#5f8a8b", consumer="#c46b54", placeholder=("#d9cdc4", "#a3978f"),
        bronze=("#f9e8da", "#d08c60", "#9a5a32"), silver=("#e8eeee", "#8fa9ab", "#58767a"),
        gold=("#faf0d4", "#d9ad5b", "#946f25"), radius=8, node_radius=6, shadow=False,
    ),
}

LH = 14             # line height of body text
NODE_W = 176        # width of every node inside a stage
BOX_W, BAR_W = 250, 36
TOP, BOX_H = 20, 280
ROW = dict(std=(60, 52), code=(136, 56), data=(214, 66))   # (top, height) per row
GAP = 56
XB = 176; XS = XB + BOX_W + GAP; XG = XS + BOX_W + GAP
W, H = 1250, 432


def cy(r):
    return ROW[r][0] + ROW[r][1] / 2


def build(T):
    out = []
    add = out.append
    INK = T["ink"]
    SH = ' filter="url(#sh)"' if T["shadow"] else ""

    def text(x, y_mid, lines, color=INK):
        """First line bold title, the rest regular; block centred on y_mid."""
        n = len(lines)
        y0 = y_mid - (n - 1) * LH / 2 + 4
        spans = []
        for i, s in enumerate(lines):
            w = ' font-weight="600" font-size="12.5"' if i == 0 else ' font-size="11.5"'
            if i and color == INK:
                w += f' fill="{T["sub"]}"'
            spans.append(f'<tspan x="{x}" y="{y0 + i * LH:.1f}"{w}>{s}</tspan>')
        add(f'<text text-anchor="middle" fill="{color}">{"".join(spans)}</text>')

    def stage_title(x, y, s, color, anchor):
        if T["title_upper"]:
            add(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="11.5" font-weight="700" '
                f'letter-spacing="1.2" fill="{color}">{s.upper()}</text>')
        else:
            add(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="13.5" font-weight="600" '
                f'fill="{color}">{s}</text>')

    def cylinder(cx, top, h, w, lines):
        f, s = T["data"]; x, ry = cx - w / 2, 7
        add(f'<path d="M{x},{top+ry} a{w/2},{ry} 0 0 1 {w},0 v{h-2*ry} a{w/2},{ry} 0 0 1 {-w},0 z" '
            f'fill="{f}" stroke="{s}" stroke-width="1.6"/>')
        add(f'<path d="M{x},{top+ry} a{w/2},{ry} 0 0 0 {w},0" fill="none" stroke="{s}" stroke-width="1.6"/>')
        text(cx, top + h / 2 + ry / 2, lines)

    def code(cx, top, h, w, lines):
        f, s = T["code"]
        add(f'<rect x="{cx-w/2}" y="{top}" width="{w}" height="{h}" rx="{T["node_radius"]}" fill="{f}" '
            f'stroke="{s}" stroke-width="1.4" stroke-dasharray="5 3"/>')
        text(cx, top + h / 2, lines)

    def standard(cx, top, h, w, lines):
        f, s = T["std"]; x, k = cx - w / 2, 10
        add(f'<path d="M{x},{top} h{w-k} l{k},{k} v{h-k} h{-w} z" fill="{f}" stroke="{s}" stroke-width="1.4"/>')
        add(f'<path d="M{x+w-k},{top} v{k} h{k}" fill="none" stroke="{s}" stroke-width="1.4"/>')
        text(cx, top + h / 2, lines)

    def placeholder(cx, top, h, w, s):
        ps, pt = T["placeholder"]
        add(f'<rect x="{cx-w/2}" y="{top}" width="{w}" height="{h}" rx="{T["node_radius"]}" fill="none" '
            f'stroke="{ps}" stroke-width="1.2" stroke-dasharray="2 3"/>')
        add(f'<text x="{cx}" y="{top+h/2+4}" text-anchor="middle" font-size="11.5" font-style="italic" '
            f'fill="{pt}">{s}</text>')

    def pill(x, top, w, h, lines):
        add(f'<rect x="{x}" y="{top}" width="{w}" height="{h}" rx="{h/2}" fill="{T["consumer"]}"{SH}/>')
        text(x + w / 2, top + h / 2, lines, color="#ffffff")

    def arrow(x1, y1, x2, y2, dotted=False):
        d = ' stroke-dasharray="2 3"' if dotted else ""
        add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{T["arrow"]}" stroke-width="1.5"{d} '
            f'marker-end="url(#ah)"/>')

    def stage(x0, tone, title, api, std_lines, code_lines, data_lines):
        f, s, tc = T[tone]; cx = x0 + (BOX_W - BAR_W) / 2
        add(f'<rect x="{x0}" y="{TOP}" width="{BOX_W}" height="{BOX_H}" rx="{T["radius"]}" fill="{f}" '
            f'stroke="{s}" stroke-width="1.8"{SH}/>')
        bx, r = x0 + BOX_W - BAR_W, T["radius"]
        add(f'<path d="M{bx},{TOP} h{BAR_W-r} a{r},{r} 0 0 1 {r},{r} v{BOX_H-2*r} a{r},{r} 0 0 1 {-r},{r} '
            f'h{-(BAR_W-r)} z" fill="{T["api"]}"/>')
        add(f'<text transform="translate({bx+BAR_W/2+4.5},{TOP+BOX_H/2}) rotate(-90)" text-anchor="middle" '
            f'fill="#ffffff" font-size="12.5" font-weight="600" letter-spacing="0.3">{api}</text>')
        stage_title(cx, TOP + 24, title, tc, "middle")
        t, h = ROW["std"]
        if std_lines:
            standard(cx, t, h, NODE_W, std_lines); arrow(cx, t + h, cx, ROW["code"][0] - 2, dotted=True)
        else:
            placeholder(cx, t, h, NODE_W, "No standard: kept as delivered")
        t, h = ROW["code"]; code(cx, t, h, NODE_W, code_lines); arrow(cx, t + h, cx, ROW["data"][0] - 2)
        t, h = ROW["data"]; cylinder(cx, t, h, NODE_W, data_lines)
        arrow(cx + NODE_W / 2, cy("data"), bx - 2, cy("data"))
        return bx

    code_left = lambda x0: x0 + (BOX_W - BAR_W) / 2 - NODE_W / 2 - 2

    cylinder(80, cy("code") - 33, 66, 120, ["Raw data", "Survey microdata,", "boundaries, text"])
    arrow(140, cy("code"), code_left(XB), cy("code"))

    stage(XB, "bronze", "Bronze · ingestion", "API to raw microdata (e.g. GMD)",
          None, ["Ingestion code", "Loads the data as delivered"],
          ["Raw microdata", "One copy per survey"])
    sbar = stage(XS, "silver", "Silver · harmonisation", "API to harmonised microdata",
                 ["Harmonisation standard", "Required variables, codes,", "units and geography"],
                 ["Harmonisation code", "Replicable, with", "documented decisions"],
                 ["Harmonised microdata", "One standard for", "every country"])
    stage(XG, "gold", "Gold · indicators", "API to indicators",
          ["Indicator standard", "AFW 360: SDMX structures,", "codelists, series plan"],
          ["Indicator code", "Computes indicators,", "converts them to SDMX"],
          ["Indicators in SDMX", "Data, structures,", "reference metadata"])

    # stage to stage: API bar -> next stage's code
    for x_from, x_next in ((XB, XS), (XS, XG)):
        arrow(x_from + BOX_W, cy("code"), code_left(x_next), cy("code"))

    # consumers of the Gold API, one per row
    CX = XG + BOX_W + 44
    for r, lines in (("std", ["MCP server", "Search and extraction by AI"]),
                     ("code", ["AI chat", "Narratives on the indicators"]),
                     ("data", ["Dashboards", "Shiny | Power BI | Tableau"])):
        arrow(XG + BOX_W, cy(r), CX - 2, cy(r))
        pill(CX, cy(r) - 23, 170, 46, lines)

    # custom fiscal incidence analysis: slim, horizontal, fed by the Silver API only
    f, s, tc = T["gold"]; ax = sbar + BAR_W / 2
    KT, KH = TOP + BOX_H + 24, 88
    KX0, KX1 = ax - NODE_W / 2 - 20, ax + NODE_W / 2 + 60 + NODE_W + 20
    add(f'<rect x="{KX0}" y="{KT}" width="{KX1-KX0}" height="{KH}" rx="{T["radius"]}" fill="{f}" '
        f'stroke="{s}" stroke-width="1.8"{SH}/>')
    stage_title(KX1 - 14, KT + 18, "Custom fiscal incidence analysis", tc, "end")
    nt, nh = KT + 28, 48
    arrow(ax, TOP + BOX_H, ax, nt - 2)
    code(ax, nt, nh, NODE_W, ["Analysis code", "Reads harmonised microdata"])
    rcx = ax + NODE_W + 60
    arrow(ax + NODE_W / 2, nt + nh / 2, rcx - NODE_W / 2 - 2, nt + nh / 2)
    cylinder(rcx, nt - 4, nh + 8, NODE_W, ["Results", "Tables and figures"])

    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
            f'font-family="{T["font"]}">\n<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" '
            f'markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,1 L9,5 L0,9 z" '
            f'fill="{T["arrow"]}"/></marker><filter id="sh" x="-10%" y="-10%" width="120%" height="130%">'
            f'<feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#0f172a" flood-opacity="0.08"/>'
            f'</filter></defs>\n' + "\n".join(out) + "\n</svg>\n")


if __name__ == "__main__":
    for name in (sys.argv[1:] or THEMES):
        T = THEMES[name]
        Path(__file__).with_name(T["file"]).write_text(build(T), encoding="utf-8")
        print("wrote", T["file"])
