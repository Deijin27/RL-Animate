import "graphics" for Canvas, Color, Font
import "input" for Mouse
import "dome" for Log

class AppFont {
  static small { "small" }
  static smallBold { "smallBold" }

  static load() {
    //Font.load(small, "fonts/pixelmix.ttf", 8)
    Font.load(small, "fonts/gorgeousjr.ttf", 16)
    Canvas.font = small
  }
}

class AppColor {
  //static background { Color.hex("#1E1E2E") }
  //static foreground { Color.hex("#cdd6f4")}
  //static background { Color.hex("#191919") }
  static domePurple { Color.hex("#8D3BFF") }
  static background { Color.black }
  static foreground { Color.white }
  static buttonForeground { Color.white }
  static buttonBackground { AppColor.domePurple }
  static gray { Color.darkgray }
}

class Control {
  construct new(x, y, width, height) {
    _x = x
    _y = y
    _width = width
    _height = height
  }
  x { _x }
  y { _y }
  width { _width }
  height { _height }

  mouseOver { Mouse.x > _x && Mouse.y > _y && Mouse.x < (_x + _width) && Mouse.y < (_y + _height) }
}

class Button is Control {
  construct new(x, y, text) {
    _justPressed = false
    _text = text

    var area = Font[AppFont.small].getArea(_text)
    var w = area.x + 4
    var h = area.y + 4

    super(x, y, w, h)
  }
  
  text { _text }
 
  justPressed { _justPressed }

  update() {
    _justPressed = Mouse["left"].justPressed && mouseOver
  }
  draw(dt) {
    Canvas.rectfill(x, y, width, height, AppColor.buttonBackground)
    Canvas.print(_text, x + 2, y + 2, AppColor.buttonForeground)
  }
}

class ToggleButton {
  construct new(x, y, text) {
    super(x, y, text)
  }

  isChecked { _isChecked }
  isChecked=(value) { _isChecked = value }

  update() {
    super.update()
    if (justPressed) {
      _isChecked = !_isChecked
    }
  }

  draw(dt) {

  }
}