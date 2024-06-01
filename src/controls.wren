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
    _visibleItemCapacity = 6
    _scrollPosition = 0
    _scrollWrap = true
    _spacing = 12
    _moving = false
    _width = 50
  }
  width { _width }
  width=(v) { _width = v }
  scrollWrap { _scrollWrap }
  scrollWrap=(value) { _scrollWrap = value }
  title { _title }
  isFocused { _isFocused }
  isFocused=(value) { _isFocused = value }
  selectedIndex { _selectedIndex }
  selectedIndex=(value) {
    
    _selectedIndex = value
    coerceSelectedIndex()
  }

  validateSelectedIndex() {
    if (!(_selectedIndex is Num)) {
      Fiber.abort("selected index should be number but is %(_selectedIndex.type)")
    }
    if (!(_selectedIndex.isInteger)) {
      Fiber.abort("selected index should be integer but is %(_selectedIndex)")
    }
    if (!(_selectedIndex >= 0)) {
      Fiber.abort("selected index should be >= 0, but is %(_selectedIndex)")
    }
  }

  selectedItem {
    return _items.count > 0 ? _items[selectedIndex] : null 
  }
  moving { _moving }
  moving=(value) { _moving = value }

  items { _items }
  items=(value) { 
    _items = value
    coerceSelectedIndex()
  }

  requiresScrollBar { _items.count > _visibleItemCapacity }

  addItem(newItem) {
    var targetPos = items.count > 0 ? selectedIndex + 1 : 0
    items.insert(targetPos, newItem)
    selectedIndex = targetPos
  }

  deleteSelected() {
    var removed = items.removeAt(selectedIndex)
    if (selectedIndex >= items.count) {
      selectedIndex = selectedIndex - 1
    }
  }

  update() {
    if (!isFocused) {
      Fiber.abort("List should not be updated if not focused!")
    }
    var oldIndex = _selectedIndex
    var downRepeats = Hotkey["down"].repeats
    var upRepeats = Hotkey["up"].repeats
    if (downRepeats > 20) {
      if (downRepeats % 5 == 0) {
        selectedIndex = selectedIndex + 1
      }
    } else if (upRepeats > 20) {
      if (upRepeats % 5 == 0) {
        selectedIndex = selectedIndex - 1
      }
    } else if (Hotkey["down"].justPressed) {
      selectedIndex = selectedIndex + 1
    } else if (Hotkey["up"].justPressed) {
      selectedIndex = selectedIndex - 1
    }

    if (_moving) {
      move(oldIndex, selectedIndex)
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
    if (_items.count != 0) {
      if (scrollWrap) {
        if (_selectedIndex == 0) {
          // do nothing
        } else if (_selectedIndex >= 0) {
          _selectedIndex = _selectedIndex % _items.count
        } else {
          _selectedIndex = _items.count - (Math.abs(_selectedIndex) % _items.count)
        }
      }
      _selectedIndex = Math.clamp(_selectedIndex, 0, _items.count - 1)
    } else {
      _selectedIndex = 0
    }
    
    validateSelectedIndex()

    // bring selected into view
    if (requiresScrollBar) {
      if (_selectedIndex >= (_scrollPosition + _visibleItemCapacity)) {
        _scrollPosition = _selectedIndex - _visibleItemCapacity + 1
      } else if (_selectedIndex <= _scrollPosition) {
        _scrollPosition = _selectedIndex
      }
    }
  }

  draw(x, y) {
    if (title != null) {
       drawItemRect(x + 4, y - 2, AppColor.background, AppColor.background)
       Canvas.print(title, x + 6, y, isFocused ? AppColor.gamer : AppColor.gray)
       y = y + _spacing
    }

    if (_items.count == 0) {
      drawItemBackground(x + 4, y - 2, false, false)
      Canvas.print("no items", x + 6, y, AppColor.gray)
    } else {
      var itemY = y
      for (drawIndex in 0..._visibleItemCapacity) {
        var itemIndex = _scrollPosition + drawIndex
        if (itemIndex >= _items.count) {
          break
        }
        var isSelectedItem = itemIndex == selectedIndex
        if (isSelectedItem) {
          //drawSelectionIndicator(x, itemY)
        }
        if (isSelectedItem && moving) {
          drawMoveIndicator(x + 4, itemY - 2)
        }
        drawItemBackground(x + 4, itemY - 2, isFocused, isSelectedItem)
        _drawItemFn.call(items[itemIndex], x + 6, itemY)
        itemY = itemY + _spacing
      }
    }
    if (requiresScrollBar) {
      drawScrollBar(x, y)
    }
  }

  drawItemRect(x, y, bgColor, borderColor) {
    Canvas.rectfill(x, y, width, 9, bgColor)
    Canvas.rect(x, y, width, 9, borderColor)
  }

  drawItemBackground(x, y, focused, selected) {
    var borderColor = null
    if (focused && selected) {
      borderColor = AppColor.gamer
    } else if (selected) {
      borderColor = AppColor.gray
    } else {
      borderColor = AppColor.background
    }
    drawItemRect(x, y, Color.black, borderColor)
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

  drawMoveIndicator(x, y) {
    x = x + (50 - width) / 2
    Canvas.trianglefill(x + 22, y, x + 28, y, x + 25, y - 3, AppColor.gamer)
    Canvas.trianglefill(x + 22, y + 8, x + 28, y + 8, x + 25, y + 11, AppColor.gamer)
  }

  drawScrollBar(x, y) {
    // draw the border of the scroll bar
    x = x + width + 7
    y = y - 2
    var sbHeight = _visibleItemCapacity * _spacing - 3
    var sbWidth = 4
    Canvas.rectfill(x, y, sbWidth, sbHeight, AppColor.background)
    Canvas.rect(x, y, sbWidth, sbHeight, AppColor.foreground)
    // draw the filled in section indicating current focus
    var fillHeight = _visibleItemCapacity / _items.count * sbHeight
    var fillY = y + (_scrollPosition / _items.count * sbHeight)
    Canvas.rectfill(x, fillY, sbWidth, fillHeight, AppColor.foreground)
  }
}

class Menu {
  construct new(items) {
    _items = items
    _complete = false
    _proceed = false
    _selectedIndex = 0
  }

  selected { _items[_selectedIndex] }

  complete { _complete }

  proceed { _proceed }

  update() {
    if (Hotkey["navigateForward"].justPressed) {
      _proceed = true
      _complete = true
    } else if (Hotkey["navigateBack"].justPressed) {
      _proceed = false
      _complete = true
    } else if (Hotkey["up"].justPressed) {
      var newIndex = _selectedIndex - 1
      if (newIndex >= 0) {
        _selectedIndex = newIndex
      }
    } else if (Hotkey["down"].justPressed) {
      var newIndex = _selectedIndex  + 1
      if (newIndex < _items.count) {
        _selectedIndex = newIndex
      }
    }
  }

  draw(x, y) {
    var w = 60
    var h = _items.count * 10 + 4
    Canvas.rectfill(x, y, w, h, AppColor.raisedBackground)
    Canvas.rect(x, y, w, h, AppColor.gray)

    for (i in 0..._items.count) {
      var itemY = y + i * 10 + 4
      Canvas.print(_items[i], x + 11, itemY, AppColor.foreground)
      if (i == _selectedIndex) {
        var triX = x + 4
        var triY = itemY - 1
        Canvas.trianglefill(triX, triY, triX, triY + 6, triX + 3, triY + 3, AppColor.gamer)
      }
    }
    
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

class Field {
  model { _model }
  model=(v) { _model = v }

  name { _name }
  withName(v) { 
    _name = v 
    return this
  }

  getter { _getter }
  withGetter(v) { 
    _getter = v
    return this
  }

  setter { _setter }
  withSetter(v) { 
    _setter = v
    return this
  }

  getValue() {
    if (_model == null) {
      return null
    }
    return _getter.call(_model)
  }

  setValue(newValue) {
    if (getValue() != newValue) {
      _setter.call(_model, newValue)
    }
  }

  update() {
  }

  getValueString() {
    var val = getValue()
    if (val == null) {
      return "---"
    } else {
      return val.toString
    }
  }

  draw(x, y) {
    Canvas.print(name, x, y, AppColor.foreground)
    Canvas.print(getValueString(), x + 40, y, AppColor.foreground)
  }

  static selector() { SelectorField.new() }
  static number() { NumberField.new() }
}

class SelectorField is Field {
  construct new() {
    _items = []
    _allowNull = false
  }

  items { _items }
  withItems(v) { 
    _items = v
    return this
  }

  allowNull { _allowNull }
  withAllowNull(v) {
    _allowNull = v
    return this
  }

  update() {
    super.update()

    var currentValue = getValue()
    var currentIndex = _items.indexOf(currentValue)

    var newIndex = currentIndex

    var leftRepeats = Hotkey["left"].repeats
    var rightRepeats = Hotkey["right"].repeats

    if (leftRepeats > 20) {
      if (leftRepeats % 5 == 0) {
        newIndex = currentIndex - 1
      }
    } else if (rightRepeats > 20) {
      if (rightRepeats % 5 == 0) {
        newIndex = currentIndex + 1
      }
    } else if (Hotkey["left"].justPressed) {
      newIndex = currentIndex - 1
    } else if (Hotkey["right"].justPressed) {
      newIndex = currentIndex + 1
    }

    newIndex = coerceIndex(newIndex)
    var newValue = newIndex == -1 ? null : _items[newIndex]
    setValue(newValue)
  }
  
  coerceIndex(index) {
    if (_items.count == 0) {
      return -1
    }
    if (index < 0) {
      return allowNull ? -1 : 0
    } else if (index >= (_items.count - 1)) {
      return _items.count - 1
    } else {
      return index
    }
  }
}

class NumberField is Field {
  construct new() {
    _min = 0
    _max = 1000
  }

  min { _min }
  withMin(v) { 
    _min = v
    return this
  }

  max { _max }
  withMax(v) { 
    _max = v
    return this
  }

  update() {
    super.update()

    if (model == null) {
      return
    }

    var currentValue = getValue()
    if (!(currentValue is Num)) {
      Fiber.abort("Value of number field should be Num, but is '%(currentValue.type)'")
    }
    var newValue = currentValue

    var leftRepeats = Hotkey["left"].repeats
    var rightRepeats = Hotkey["right"].repeats

    if (leftRepeats > 20) {
      if (leftRepeats % 5 == 0) {
        newValue = currentValue - 1
      }
    } else if (rightRepeats > 20) {
      if (rightRepeats % 5 == 0) {
        newValue = currentValue + 1
      }
    } else if (Hotkey["left"].justPressed) {
      newValue = currentValue - 1
    } else if (Hotkey["right"].justPressed) {
      newValue = currentValue + 1
    }

    newValue = coerceValue(newValue)
    setValue(newValue)
  }

  coerceValue(value) {
    if (value < min) {
      return min
    } else if (value > max) {
      return max
    } else {
      return value
    }
  }
}

class Form is ListView {
  construct new(title, fields) {
    super(title, fields, Fn.new {|item, x, y| item.draw(x, y) })
    _fields = fields
  }

  update() {
    super.update()

    var si = selectedItem
    if (si != null) {
      si.update()
    }
  }

  model { _model }
  model=(v) {
    _model = v
    for (f in _fields) {
      f.model = _model
    }
  }
}