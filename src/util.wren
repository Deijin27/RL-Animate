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
    loadFilesRecursive(dir, [".png"])
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
    for (subDir in FileSystem.listDirectories(dir)) {
      loadFilesRecursive(subDir, list, extensions)
    }
  }


}