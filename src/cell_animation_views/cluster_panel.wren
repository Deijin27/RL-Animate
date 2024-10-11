import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame, Cell, Cluster, CellSize
import "dome" for Process, Window, Log
import "controls" for Form, Field, AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog, MergedListView
import "math" for Math, Vector
import "util" for FileUtil

class ClusterPanel {

  update() {
    if (_clustersList.isFocused) {
      _clustersStateActions[_state].call()
    } else if (_middleColumn.isFocused) {
      _cellsStateActions[_state].call()
    } else {
     _cellStateActions[_state].call()
    }
  }

  draw(x, y) {
    _clustersList.draw(x, y)

    var cellsListY = y
    var clusterInfoX = x + 95
    if (_clusterForm != null) {
      cellsListY = cellsListY + 12 + 12 * _clusterForm.fields.count
      _clusterForm.draw(clusterInfoX, y)
    }
    _cellsList.draw(clusterInfoX, cellsListY)

    _cellForm.draw(clusterInfoX + 95, y)

    if (_menu != null || _textDialog != null) {
      Canvas.rectfill(x - 20, y - 4, 400, 200, Color.hex("#00000060"))
    }
    if (_menu != null) {
      _menu.draw(250, 175)
    }
    if (_textDialog != null) {
      _textDialog.draw(240, 175)
    }
  }

  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    
    _clustersList = ListView.new("CLUSTERS", _res.clusters) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _clustersList.width = 80
    _cellsList = ListView.new("CELLS", []) {|item, x, y| 
      Canvas.print("(%(item.x), %(item.y)) %(item.width)x%(item.height)", x, y, AppColor.foreground)
    }
    _cellsList.isFocused = false
    _cellsList.width = 80

    initCellForm()

    _middleColumn = _cellsList
    if (_res.format == CellFormat.oneImagePerCluster) {
      initClusterForm()
      _cellsList.visibleItemCapacity = 4
      _mergedList = MergedListView.new([_clusterForm, _cellsList])
      _middleColumn = _mergedList
    }
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
        var deleted = _clustersList.deleteSelected()
        for (anim in _res.animations) {
          for (frame in anim.frames) {
            if (frame.cluster == deleted) {
              frame.cluster = null
            }
          }
        }
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

  initClusterForm() {
    var clusterFields = []

    _fileField = Field.selector()
      .withName("File")
      .withGetter {|m| m.file }
      .withSetter {|m, v| m.file = v }
      .withAllowNull(true)
    updateFilesList()
    clusterFields.add(_fileField)
    
    clusterFields.add(Field.number()
      .withName("Palette")
      .withGetter {|m| m.palette }
      .withSetter {|m, v| m.palette = v }
      .withMax(255)
      )

    _clusterForm = Form.new("CLUSTER", clusterFields)
    _clusterForm.width = 80
    _clusterForm.isFocused = false
  }

  initCellForm() {
    var cellFields = []

    cellFields.add(Field.vector()
      .withName("XY")
      .withGetter {|m| Vector.new(m.x, m.y) }
      .withSetter {|m, v| 
        m.x = v.x
        m.y = v.y
      }
      .withMinX(-100)
      .withMinY(-100)
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

      cellFields.add(Field.number()
        .withName("Palette")
        .withGetter {|m| m.palette }
        .withSetter {|m, v| m.palette = v }
        .withMax(255)
        )
    }

    cellFields.add(Field.bool()
      .withName("FlipX")
      .withGetter {|m| m.flipX }
      .withSetter {|m, v| m.flipX = v }
      )

    cellFields.add(Field.bool()
      .withName("FlipY")
      .withGetter {|m| m.flipY }
      .withSetter {|m, v| m.flipY = v }
      )

    cellFields.add(Field.bool()
      .withName("DoubleSize")
      .withGetter {|m| m.doubleSize }
      .withSetter {|m, v| m.doubleSize = v }
      )

    _cellForm = Form.new("CELL", cellFields)
    _cellForm.width = 80
    _cellForm.isFocused = false
  }

  allowSwapPanel { !_cellForm.captureFocus && (_clusterForm == null || !_clusterForm.captureFocus) }

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
      _middleColumn.isFocused = true
      _clustersList.isFocused = false
    } else if (Hotkey["delete"].justPressed) {
      _clusterMenuActions["Delete"].call()
    } else {
      _clustersList.update()
      var sc = _clustersList.selectedItem
      if (sc != null) {
        if (_clusterForm != null) {
          _clusterForm.model = sc
        }
        _cellsList.items = sc.cells
      } else {
        if (_clusterForm != null) {
          _clusterForm.model = null
        }
        _cellsList.items = []
      }
      _cellForm.model = selectedCell
    }
  }

  updateCellsFocused() {
     if (_cellsList.isFocused && Hotkey["menu"].justPressed) {
      _menu = _cellsList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if ((_clusterForm == null || !_clusterForm.captureFocus) && Hotkey["navigateBack"].justPressed) {
      _middleColumn.isFocused = false
      _clustersList.isFocused = true
    } else if (_cellsList.isFocused && _cellsList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
      _middleColumn.isFocused = false
      _cellForm.isFocused = true
    } else if (Hotkey["delete"].justPressed) {
      _cellMenuActions["Delete"].call()
    } else {
      if (_res.format == CellFormat.oneImagePerCluster) {
        updateFilesList()
      }  
      _middleColumn.update()
      _cellForm.model = selectedCell
    }
  }

  updateCellFocused() {
    if (!_cellForm.captureFocus && Hotkey["navigateBack"].justPressed) {
      _cellForm.isFocused = false
      _middleColumn.isFocused = true
    } else {
      if (_res.format == CellFormat.oneImagePerCell) {
        updateFilesList() 
      }
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