import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame, Cell, Cluster, CellSize
import "dome" for Process, Window, Log
import "controls" for Form, Field, AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math
import "util" for FileUtil

class ClusterPanel {

  update() {
    if (_clustersList.isFocused) {
      _clustersStateActions[_state].call()
    } else if (_cellsList.isFocused) {
      _cellsStateActions[_state].call()
    } else {
     _cellStateActions[_state].call()
    }
  }

  draw(x, y) {
    _clustersList.draw(x, y)

    var cellsListY = y
    var clusterInfoX = x + 65
    if (_res.format == CellFormat.oneImagePerCluster) {
      // cellsListY = cellsListY + 20
      // _clusterInfo.draw(clusterInfoX, y)
    }
    _cellsList.draw(clusterInfoX, cellsListY)

    _cellForm.draw(clusterInfoX + 65, y)

    if (_menu != null || _textDialog != null) {
      Canvas.rectfill(x - 20, y - 4, 400, 200, Color.hex("#00000060"))
    }
    if (_menu != null) {
      _menu.draw(220, 160)
    }
    if (_textDialog != null) {
      _textDialog.draw(200, 180)
    }
  }

  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    
    _clustersList = ListView.new("CLUSTERS", _res.clusters) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _cellsList = ListView.new("CELLS", []) {|item, x, y| 
      Canvas.print("[%(item.x),%(item.y),%(item.width),%(item.height)]", x, y, AppColor.foreground)
    }
    _cellsList.isFocused = false
    initCellForm()
    _state = "list"

    _clustersStateActions = {
      "list": Fn.new {
        updateClustersFocused()
      },
      "rename" : Fn.new {
        _textDialog.update()
        if (_textDialog.complete) {
          if (_textDialog.proceed) {
            selectedCluster.name = _textDialog.text
          }
          _state = "list"
          _textDialog = null
        }
      },
      "menu" : Fn.new {
        _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _clusterMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        // TODO: have some text per-state, maybe which replaces the left top bar text
        // and this says "MOVING ITEM..." etc.
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _clustersList.moving = false
        } else {
          _clustersList.update()
        }
      },
    }

    _cellsStateActions = {
      "list": Fn.new {
        updateCellsFocused()
      },
      "menu": Fn.new {
       _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _cellsMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _cellsList.moving = false
        } else {
          _cellsList.update()
        }
      }
    }

    _cellStateActions = {
      "list": Fn.new {
        updateCellFocused()
      }
    }
    
    _clusterMenuActions = {
      "Add": Fn.new {
        _clustersList.addItem(_res.newCluster())
        beginRename()
      },
      "Rename" : Fn.new {
        beginRename()
      },
      "Move" : Fn.new {
        _state = "move"
        _clustersList.moving = true
      },
      "Delete": Fn.new {
        _clustersList.deleteSelected()
        _state = "list"
      },
      "Duplicate": Fn.new {
        _clustersList.addItem(selectedCluster.clone())
        beginRename()
      }
    }

    _cellsMenuActions = {
      "Add": Fn.new {
        _cellsList.addItem(selectedCluster.newCell())
        _state = "list"
      },
      "Move" : Fn.new {
        _state = "move"
        _cellsList.moving = true
      },
      "Delete": Fn.new {
        _cellsList.deleteSelected()
        _res.reset()
        _state = "list"
      },
      "Duplicate": Fn.new {
        _cellsList.addItem(selectedCell.clone())
        _state = "list"
      }
    }
  }

  beginRename() {
    _state = "rename"
    _textDialog = TextInputDialog.new(selectedCluster.name) {|text|
      // validate
      if (text.count == 0) {
        return false
      }
      for (i in 0..._clustersList.items.count) {
        if (i != _clustersList.selectedIndex && _clustersList.items[i].name == text) {
          return false
        }
      }
      return true
    }
  }

  initCellForm() {
    var cellFields = []

    cellFields.add(Field.number()
      .withName("X")
      .withGetter {|m| m.x }
      .withSetter {|m, v| m.x = v }
      .withMin(-100)
      )

    cellFields.add(Field.number()
      .withName("Y")
      .withGetter {|m| m.y }
      .withSetter {|m, v| m.y = v }
      .withMin(-100)
      )

    if (_res.format == CellFormat.oneImagePerCluster) {
      cellFields.add(Field.selector()
        .withName("Size")
        .withItems(CellSize.validSizes)
        .withGetter {|m| m.size}
        .withSetter {|m, v| m.size = v }
        )
    } else if (_res.format == CellFormat.oneImagePerCell) {
      _fileField = Field.selector()
        .withName("File")
        .withGetter {|m| m.file }
        .withSetter {|m, v| m.file = v }
        .withAllowNull(true)
      updateFilesList()
      cellFields.add(_fileField)
    }

    _cellForm = Form.new("CELL", cellFields)
    _cellForm.width = 80
    _cellForm.isFocused = false
  }

  allowSwapPanel { !_cellForm.isFocused }

  name { "CLUSTERS" }

  selection { _clustersList.selectedIndex }
  selectedCluster { _clustersList.selectedItem }
  cellFileFocused { _cellFileFocused }
  cellsListFocused { _cellsList.isFocused }
  selectedCell { _cellsList.selectedItem }

  highlightSelectedCell { _cellsList.isFocused || _cellForm.isFocused }

  updateClustersFocused() {
    if (Hotkey["menu"].justPressed) {
      _menu = _clustersList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Rename", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (_clustersList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
      _cellsList.isFocused = true
      _clustersList.isFocused = false
    } else {
      _clustersList.update()
      var sc = _clustersList.selectedItem
      if (sc != null) {
        _cellsList.items = sc.cells
      } else {
        _cellsList.items = []
      }
      _cellForm.model = selectedCell
    }
  }

  updateCellsFocused() {
     if (Hotkey["menu"].justPressed) {
      _menu = _cellsList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (Hotkey["navigateBack"].justPressed) {
      _cellsList.isFocused = false
      _clustersList.isFocused = true
    } else if (_cellsList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
      _cellsList.isFocused = false
      _cellForm.isFocused = true
    } else {
      _cellsList.update()
      _cellForm.model = selectedCell
    }
  }

  updateCellFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      _cellForm.isFocused = false
      _cellsList.isFocused = true
    } else {
      updateFilesList()
      _cellForm.update()
    }
  }

  updateFilesList() {
    if (_fileField == null) {
      return
    }
    var newItems = FileUtil.loadImagesRecursive(_res.dir)
    _fileField.withItems(newItems)
  }
}