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
  //static background { Color.hex("#1E1E2E") }
  //static foreground { Color.hex("#cdd6f4")}
  //static background { Color.hex("#191919") }
  static domePurple { Color.hex("#8D3BFF") }
  static background { Color.black }
  static raisedBackground { Color.hex("#110022")}
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
    _spacing = 10
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

  items { _items }
  items=(value) { 
    _items = value
    coerceSelectedIndex()
  }

  requiresScrollBar { _items.count > _visibleItemCapacity }

  update() {
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
       Canvas.print(title, x + 6, y, isFocused ? AppColor.domePurple : AppColor.gray)
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
        _drawItemFn.call(items[itemIndex], x + 6, itemY)
        itemY = itemY + _spacing
      }
    }
    if (requiresScrollBar) {
      drawScrollBar(x, y)
    }
  }

  drawSelectionIndicator(x, y) {
    Canvas.circle(x, y + 2, 2, isFocused ? AppColor.domePurple : AppColor.gray)
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