// Generated using the ObjectBox Swift Generator — https://objectbox.io
// DO NOT EDIT

// swiftlint:disable all
import ObjectBox
import Foundation

// MARK: - Entity metadata

extension OBChunk: ObjectBox.Entity {}

extension OBChunk: ObjectBox.__EntityRelatable {
    internal typealias EntityType = OBChunk

    internal var _id: EntityId<OBChunk> {
        return EntityId<OBChunk>(self.id.value)
    }
}

extension OBChunk: ObjectBox.EntityInspectable {
    internal typealias EntityBindingType = OBChunkBinding

    /// Generated metadata used by ObjectBox to persist the entity.
    internal static let entityInfo = ObjectBox.EntityInfo(name: "OBChunk", id: 1)

    internal static let entityBinding = EntityBindingType()

    fileprivate static func buildEntity(modelBuilder: ObjectBox.ModelBuilder) throws {
        let entityBuilder = try modelBuilder.entityBuilder(for: OBChunk.self, id: 1, uid: 8777672549323939584)
        try entityBuilder.addProperty(name: "id", type: PropertyType.long, flags: [.id], id: 1, uid: 8772012977392055552)
        try entityBuilder.addProperty(name: "noteID", type: PropertyType.string, id: 2, uid: 1538130122119906560)
        try entityBuilder.addProperty(name: "chunk", type: PropertyType.string, id: 3, uid: 1568624585990606336)
        try entityBuilder.addProperty(name: "embedding", type: PropertyType.floatVector, flags: [.indexed], id: 4, uid: 7385883355930001408, indexId: 1, indexUid: 8749910346665274624)
            .hnswParams(dimensions: 512, neighborsPerNode: nil, indexingSearchCount: nil, flags: nil, distanceType: HnswDistanceType.cosine, reparationBacklinkProbability: nil, vectorCacheHintSizeKB: nil)

        try entityBuilder.lastProperty(id: 4, uid: 7385883355930001408)
    }
}

extension OBChunk {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OBChunk.id == myId }
    internal static var id: Property<OBChunk, Id, Id> { return Property<OBChunk, Id, Id>(propertyId: 1, isPrimaryKey: true) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OBChunk.noteID.startsWith("X") }
    internal static var noteID: Property<OBChunk, String, Void> { return Property<OBChunk, String, Void>(propertyId: 2, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OBChunk.chunk.startsWith("X") }
    internal static var chunk: Property<OBChunk, String, Void> { return Property<OBChunk, String, Void>(propertyId: 3, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OBChunk.embedding.isNotNil() }
    internal static var embedding: Property<OBChunk, HnswIndexPropertyType, Void> { return Property<OBChunk, HnswIndexPropertyType, Void>(propertyId: 4, isPrimaryKey: false) }

    fileprivate func __setId(identifier: ObjectBox.Id) {
        self.id = Id(identifier)
    }
}

extension ObjectBox.Property where E == OBChunk {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .id == myId }

    internal static var id: Property<OBChunk, Id, Id> { return Property<OBChunk, Id, Id>(propertyId: 1, isPrimaryKey: true) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .noteID.startsWith("X") }

    internal static var noteID: Property<OBChunk, String, Void> { return Property<OBChunk, String, Void>(propertyId: 2, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .chunk.startsWith("X") }

    internal static var chunk: Property<OBChunk, String, Void> { return Property<OBChunk, String, Void>(propertyId: 3, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .embedding.isNotNil() }

    internal static var embedding: Property<OBChunk, HnswIndexPropertyType, Void> { return Property<OBChunk, HnswIndexPropertyType, Void>(propertyId: 4, isPrimaryKey: false) }

}


/// Generated service type to handle persisting and reading entity data. Exposed through `OBChunk.EntityBindingType`.
internal final class OBChunkBinding: ObjectBox.EntityBinding, Sendable {
    internal typealias EntityType = OBChunk
    internal typealias IdType = Id

    internal required init() {}

    internal func generatorBindingVersion() -> Int { 1 }

    internal func setEntityIdUnlessStruct(of entity: EntityType, to entityId: ObjectBox.Id) {
        entity.__setId(identifier: entityId)
    }

    internal func entityId(of entity: EntityType) -> ObjectBox.Id {
        return entity.id.value
    }

    internal func collect(fromEntity entity: EntityType, id: ObjectBox.Id,
                                  propertyCollector: ObjectBox.FlatBufferBuilder, store: ObjectBox.Store) throws {
        let propertyOffset_noteID = propertyCollector.prepare(string: entity.noteID)
        let propertyOffset_chunk = propertyCollector.prepare(string: entity.chunk)
        let propertyOffset_embedding = propertyCollector.prepare(values: entity.embedding)

        propertyCollector.collect(id, at: 2 + 2 * 1)
        propertyCollector.collect(dataOffset: propertyOffset_noteID, at: 2 + 2 * 2)
        propertyCollector.collect(dataOffset: propertyOffset_chunk, at: 2 + 2 * 3)
        propertyCollector.collect(dataOffset: propertyOffset_embedding, at: 2 + 2 * 4)
    }

    internal func createEntity(entityReader: ObjectBox.FlatBufferReader, store: ObjectBox.Store) -> EntityType {
        let entity = OBChunk()

        entity.id = entityReader.read(at: 2 + 2 * 1)
        entity.noteID = entityReader.read(at: 2 + 2 * 2)
        entity.chunk = entityReader.read(at: 2 + 2 * 3)
        entity.embedding = entityReader.read(at: 2 + 2 * 4)

        return entity
    }
}


/// Helper function that allows calling Enum(rawValue: value) with a nil value, which will return nil.
fileprivate func optConstruct<T: RawRepresentable>(_ type: T.Type, rawValue: T.RawValue?) -> T? {
    guard let rawValue = rawValue else { return nil }
    return T(rawValue: rawValue)
}

// MARK: - Store setup

fileprivate func cModel() throws -> OpaquePointer {
    let modelBuilder = try ObjectBox.ModelBuilder()
    try OBChunk.buildEntity(modelBuilder: modelBuilder)
    modelBuilder.lastEntity(id: 1, uid: 8777672549323939584)
    modelBuilder.lastIndex(id: 1, uid: 8749910346665274624)
    return modelBuilder.finish()
}

extension ObjectBox.Store {
    /// A store with a fully configured model. Created by the code generator with your model's metadata in place.
    ///
    /// # In-memory database
    /// To use a file-less in-memory database, instead of a directory path pass `memory:` 
    /// together with an identifier string:
    /// ```swift
    /// let inMemoryStore = try Store(directoryPath: "memory:test-db")
    /// ```
    ///
    /// - Parameters:
    ///   - directoryPath: The directory path in which ObjectBox places its database files for this store,
    ///     or to use an in-memory database `memory:<identifier>`.
    ///   - maxDbSizeInKByte: Limit of on-disk space for the database files. Default is `1024 * 1024` (1 GiB).
    ///   - fileMode: UNIX-style bit mask used for the database files; default is `0o644`.
    ///     Note: directories become searchable if the "read" or "write" permission is set (e.g. 0640 becomes 0750).
    ///   - maxReaders: The maximum number of readers.
    ///     "Readers" are a finite resource for which we need to define a maximum number upfront.
    ///     The default value is enough for most apps and usually you can ignore it completely.
    ///     However, if you get the maxReadersExceeded error, you should verify your
    ///     threading. For each thread, ObjectBox uses multiple readers. Their number (per thread) depends
    ///     on number of types, relations, and usage patterns. Thus, if you are working with many threads
    ///     (e.g. in a server-like scenario), it can make sense to increase the maximum number of readers.
    ///     Note: The internal default is currently around 120. So when hitting this limit, try values around 200-500.
    ///   - readOnly: Opens the database in read-only mode, i.e. not allowing write transactions.
    ///
    /// - important: This initializer is created by the code generator. If you only see the internal `init(model:...)`
    ///              initializer, trigger code generation by building your project.
    internal convenience init(directoryPath: String, maxDbSizeInKByte: UInt64 = 1024 * 1024,
                            fileMode: UInt32 = 0o644, maxReaders: UInt32 = 0, readOnly: Bool = false) throws {
        try self.init(
            model: try cModel(),
            directory: directoryPath,
            maxDbSizeInKByte: maxDbSizeInKByte,
            fileMode: fileMode,
            maxReaders: maxReaders,
            readOnly: readOnly)
    }
}

// swiftlint:enable all
