import UniformTypeIdentifiers

extension UTType {
    /// Imported Excalidraw drawing type — mirrors `UTImportedTypeDeclarations` in Info.plist.
    /// Excalidays does not own the format; keep this imported (not exported).
    static var excalidraw: UTType {
        UTType(importedAs: "com.excalidraw.excalidraw")
    }
}
