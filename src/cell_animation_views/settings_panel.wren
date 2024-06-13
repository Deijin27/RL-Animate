import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame, Cell, Cluster, CellSize
import "dome" for Process, Window, Log
import "controls" for Form, Field, AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math, Vector
import "util" for FileUtil

class SettingsPanel {
  construct new(res) {
    _res = res
    initForm()
  }

  name { "SETTINGS" }

  allowSwapPanel { !_form.captureFocus }

  initForm() {
    var fields = [
      Field.readonly()
        .withName("Format")
        .withGetter {|m| m.format }
    ]

    _form = Form.new("SETTINGS", fields)
    _form.width = 115
    _form.isFocused = true
    _form.model = _res
  }

  update() {
    _form.update()
  }

  draw(x, y) {
    _form.draw(x, y)
  }


}