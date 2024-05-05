import "graphics" for Canvas, Color, Font
import "input" for Mouse, Keyboard
import "dome" for Log
import "math" for Math

class Hotkey {
  construct new(name, key) {
    _name = name
    _key = key
  }

  name { _name }
  key { _key }

  justPressed { Keyboard[key].justPressed }
  down { Keyboard[key].down }
  previous { Keyboard[key].previous }
  repeats { Keyboard[key].repeats }

  static [name] {
    var hk = __hotkeys[name]
    if (hk == null) {
      Fiber.abort("No hotkey found of name %(name)")
    }
    return hk
  }

  static register(name, key) {
    __hotkeys[name] = Hotkey.new(name, key)
  }

  static init_() {
    __hotkeys = {}
  }
}
Hotkey.init_()

class AppFont {
  static small { "small" }
  static smallBold { "smallBold" }

  static load() {
    //Font.load(small, "fonts/pixelmix.ttf", 8)
    Font.load(small, "fonts/gorgeousjr.ttf", 16)
    //Font.load(small, "fonts/pokemonconquest.ttf", 16)
    Canvas.font = small
  }
}

class AppColor {
  static gamer { __gamer }
  static domePurple { __domePurple }
  static background { Color.black }
  static raisedBackground { __raisedBackground }
  static foreground { Color.white }
  static buttonForeground { Color.white }
  static buttonBackground { AppColor.domePurple }
  static gray { Color.darkgray }
  static init_() {
    __domePurple = Color.hex("#8D3BFF")
    __raisedBackground = Color.hex("#000000")

    __gamerPoints = [
      Color.hex("#8D3BFF"),
      Color.hex("#A05CFF"),
      Color.hex("#B179FF"),
      Color.hex("#C8A0FF"),
      Color.hex("#DABFFF")
    ]

    __updateCounter = 0

    AppColor.update()
  }
  static update() {
    __updateCounter = __updateCounter + 1

    var gamerIndex = (__updateCounter / 6).floor % (__gamerPoints.count * 2 - 1)
    if (gamerIndex < __gamerPoints.count) {
      __gamer = __gamerPoints[gamerIndex]
    } else {
      __gamer = __gamerPoints[__gamerPoints.count * 2 - gamerIndex - 1]
    }
  }
}
AppColor.init_()

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


class ListView {
  construct new(title, items, drawItemFn) {
    _title = title
    _items = items
    _selectedIndex = 0
    _isFocused = true
    _drawItemFn = drawItemFn
    _visibleItemCapacity = 7
    _scrollPosition = 0
    _scrollWrap = true
    _spacing = 12
    _moving = false
  }
  scrollWrap { _scrollWrap }
  scrollWrap=(value) { _scrollWrap = value }
  title { _title }
  isFocused { _isFocused }
  isFocused=(value) { _isFocused = value }
  selectedIndex { _selectedIndex }
  selectedItem {
    return _items.count > 0 ? _items[_selectedIndex] : null 
  }
  moving { _moving }
  moving=(value) { _moving = value }

  items { _items }
  items=(value) { 
    _items = value
    coerceSelectedIndex()
  }

  requiresScrollBar { _items.count > _visibleItemCapacity }

  update() {
    var oldIndex = _selectedIndex
    var downRepeats = Hotkey["down"].repeats
    var upRepeats = Hotkey["up"].repeats
    if (downRepeats > 20) {
      if (downRepeats % 5 == 0) {
        _selectedIndex = _selectedIndex + 1
      }
    } else if (upRepeats > 40) {
      if (upRepeats % 5 == 0) {
        _selectedIndex = _selectedIndex - 1
      }
    } else if (Hotkey["down"].justPressed) {
      _selectedIndex = _selectedIndex + 1
    } else if (Hotkey["up"].justPressed) {
      _selectedIndex = _selectedIndex - 1
    }
    coerceSelectedIndex()

    if (requiresScrollBar) {
      if (_selectedIndex >= (_scrollPosition + _visibleItemCapacity)) {
        _scrollPosition = _selectedIndex - _visibleItemCapacity + 1
      } else if (_selectedIndex <= _scrollPosition) {
        _scrollPosition = _selectedIndex
      }
    }

    if (_moving) {
      move(oldIndex, _selectedIndex)
    }
  }

  move(oldIndex, newIndex) {
    if (oldIndex == newIndex) {
      return
    }
    var item = _items[oldIndex]
    // if (oldIndex < newIndex) {
    //   newIndex = newIndex - 1
    // }
    _items.removeAt(oldIndex)
    _items.insert(newIndex, item)
  }

  coerceSelectedIndex() {
    if (scrollWrap) {
      if (_selectedIndex == 0) {
        // do nothing
      } else if (_selectedIndex >= 0) {
        _selectedIndex = _selectedIndex % _items.count
      } else {
        _selectedIndex = _items.count - (Math.abs(_selectedIndex) % _items.count)
      }
    } else {
      _selectedIndex = Math.clamp(_selectedIndex, 0, _items.count - 1)
    }
  }

  draw(x, y) {
    if (title != null) {
       drawItemBackground(x + 4, y - 2)
       Canvas.print(title, x + 6, y, isFocused ? AppColor.gamer : AppColor.gray)
       y = y + _spacing
    }

    if (_items.count == 0) {
      Canvas.print("no items", x + 6, y, AppColor.gray)
    } else {
      var itemY = y
      for (drawIndex in 0..._visibleItemCapacity) {
        var itemIndex = _scrollPosition + drawIndex
        if (itemIndex >= _items.count) {
          break
        }
        if (itemIndex == selectedIndex) {
          drawSelectionIndicator(x, itemY)
        }
        drawItemBackground(x + 4, itemY - 2)
        _drawItemFn.call(items[itemIndex], x + 6, itemY)
        itemY = itemY + _spacing
      }
    }
    if (requiresScrollBar) {
      drawScrollBar(x, y)
    }
  }


  drawItemBackground(x, y) {
    var color = isFocused ? AppColor.domePurple : AppColor.gray
    Canvas.rectfill(x, y, 50, 9, Color.black)
  }

  drawSelectionIndicator(x, y) {
    var color = null
    if (moving) {
      color = Color.hex("#E3C355")
    } else {
      color = isFocused ? AppColor.gamer : AppColor.gray
    }
    Canvas.circle(x, y + 2, 2, color)
  }

  drawScrollBar(x, y) {
    // draw the border of the scroll bar
    x = x + 50
    var sbHeight = _visibleItemCapacity * _spacing - 4
    var sbWidth = 4
    Canvas.rect(x, y, sbWidth, sbHeight, AppColor.foreground)
    // draw the filled in section indicating current focus
    var fillHeight = _visibleItemCapacity / _items.count * sbHeight
    var fillY = y + (_scrollPosition / _items.count * sbHeight)
    Canvas.rectfill(x, fillY, sbWidth, fillHeight, AppColor.foreground)
  }
}

class Menu {
  construct new(items) {
    _list = ListView.new(null, items) {|item, x, y| Canvas.print(item, x, y, AppColor.foreground)}
    _complete = false
    _proceed = false
  }

  selected { _list.selectedItem }

  complete { _complete }

  proceed { _proceed }

  update() {
    if (Hotkey["navigateForward"].justPressed) {
      _proceed = true
      _complete = true
    } else if (Hotkey["navigateBack"].justPressed) {
      _proceed = false
      _complete = true
    } else {
      _list.update()
    }
  }

  draw(x, y) {
    var w = 60
    var h = _list.items.count * 10 + 4
    Canvas.rectfill(x, y, w, h, AppColor.raisedBackground)
    Canvas.rect(x, y, w, h, AppColor.gray)
    _list.draw(x + 6, y + 4)
    
  }
}

class TextInputDialog {
  construct new(initText, validateText) {
    _text = initText
    _validateText = validateText
    _complete = false
    _proceed = false
    Keyboard.handleText = true
    _state = "tbox"
    validate()
  }

  close(proceed) {
    Keyboard.handleText = false
    _proceed = proceed
    _complete = true
  }

  validate() {
    _valid = _validateText.call(_text)
  }

  text { _text }
  complete { _complete }
  proceed { _proceed }
  valid { _valid }

  update() {
    if (Keyboard["escape"].justPressed) {
      close(false)
    } else if (valid && Keyboard["return"].justPressed) {
      close(true)
    } else if (Keyboard["backspace"].justPressed) {
      if (_text.count > 0) {
        _text = _text[0...-1]
        validate()
      }
    } else {
      var newText = Keyboard.text
      _text = _text + newText
      validate()
    }
  }

  draw(x, y) {
    var w = 70
    var h = 30
    Canvas.rectfill(x, y, w, h, AppColor.raisedBackground)
    Canvas.rect(x, y, w, h, AppColor.gray)

    // draw text box
    var tboxX = x + 2
    var tboxY = y + 2
    var tboxW = w - 4
    var tboxH = 10
    Canvas.rectfill(tboxX, tboxY, tboxW, tboxH, AppColor.background)
    Canvas.rect(tboxX, tboxY, tboxW, tboxH, AppColor.gamer)
    Canvas.print(_text, tboxX + 2, tboxY + 2, AppColor.foreground)

    // draw hints
    Canvas.print("<< ESCAPE", x + 2, y + 16, Color.red)
    Canvas.print("ENTER >>", x + 40, y + 16, valid ? Color.green : AppColor.gray)
  }
}