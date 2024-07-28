import "io" for FileSystem

class StringUtil {
  static padLeft(str, totalWidth, paddingChar) {
    while (str.count < totalWidth) {
      str = paddingChar + str
    }
  }
}

class FileUtil {
  static loadFilesRecursive(dir) {
    return loadFilesRecursive(dir, [])
  }

  static loadFilesRecursive(dir, extensions) {
    var list = []
    loadFilesRecursive_(dir, list, extensions)
    return list
  }

  static loadImagesRecursive(dir) {
    return loadFilesRecursive(dir, [".png"])
  }

  static loadFilesRecursive_(dir, list, extensions) {
    for (file in FileSystem.listFiles(dir)) {
      for (ext in extensions) {
        if (file.endsWith(ext)) {
          list.add(file)
          break
        }
      }
    }
    var dirs = FileSystem.listDirectories(dir)
    for (subDir in dirs) {
      if (subDir == "." || subDir == "..") {
        continue
      }
      loadFilesRecursive_(subDir, list, extensions)
    }
  }
}