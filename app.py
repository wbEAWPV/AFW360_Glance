"""Connect smoke test for the AFW 360 At A Glance port.

Deliberately minimal: it proves Python is enabled on Connect, that version matching
succeeds, and that the corporate proxy passes Shiny's WebSocket traffic (the slider
only moves the text if the websocket is live). Replaced by the real app in Phase 3.
"""

from shiny import App, render, ui

app_ui = ui.page_fluid(
    ui.h2("AFW 360 At A Glance — Connect smoke test"),
    ui.input_slider("n", "Move me: the reactive value below proves the websocket works", 0, 100, 42),
    ui.output_code("echo"),
)


def server(input, output, session):
    @render.code
    def echo():
        import sys

        return f"n = {input.n()}\nPython {sys.version.split()[0]}"


app = App(app_ui, server)
