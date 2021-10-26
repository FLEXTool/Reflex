//
//  EchoExtensions.swift
//  Reflex
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Echo
import CEcho

typealias RawType = UnsafeRawPointer
typealias Field = (name: String, type: Metadata)

/// For some reason, breaking it all out into separate vars like this
/// eliminated a bug where the pointers in the final set were not the
/// same pointers that would appear if you manually reflected a type
extension KnownMetadata.Builtin {
    static var supported: Set<RawType> = Set(_typePtrs)
    
    private static var _types: [Any.Type] {
        return [
            Int8.self, Int16.self, Int32.self, Int64.self, Int.self,
            UInt8.self, UInt16.self, UInt32.self, UInt64.self, UInt.self,
            Float32.self, Float64.self, Float.self, Double.self
        ]
    }
    
    private static var _typePtrs: [RawType] {
        return self._types.map({ type in
            let metadata = reflect(type)
            return metadata.ptr
        })
    }
}

extension KnownMetadata {
    static var array: StructDescriptor = reflectStruct([Any].self)!.descriptor
    static var dictionary: StructDescriptor = reflectStruct([String:Any].self)!.descriptor
    static var date: StructDescriptor = reflectStruct(Date.self)!.descriptor
    static var data: StructDescriptor = reflectStruct(Data.self)!.descriptor
    static var url: StructDescriptor = reflectStruct(URL.self)!.descriptor
}

extension Metadata {
    /// This doesn't actually work very well since Double etc aren't opaque,
    /// but instead contain a single member that is itself opaque
    private var isBuiltin_alt: Bool {
        return self is OpaqueMetadata
    }
    
    var isBuiltin: Bool {
        guard self.vwt.flags.isPOD else {
            return false
        }
        
        return KnownMetadata.Builtin.supported.contains(self.ptr)
    }
    
    func dynamicCast(from variable: Any) throws -> Any {
        func cast<T>(_: T.Type) throws -> T {
            guard let casted = variable as? T else {
                fatalError("Failed dynamic cast")
            }
            
            return casted
        }
        
        return try _openExistential(self.type, do: cast(_:))
    }
    
    var typeEncoding: FLEXTypeEncoding {
        switch self.kind {
            case .class:
                return .objcClass
            case .struct:
                return .structBegin
            case .enum:
                if (self as! EnumMetadata).descriptor.numPayloadCases > 0 {
                    return .unknown
                }
                return .unknown // TODO: return proper sized int for enums?
            case .optional:
                return (self as! EnumMetadata).genericMetadata.first!.typeEncoding
            case .tuple:
                return .structBegin
            case .foreignClass,
                 .opaque,
                 .function,
                 .existential,
                 .metatype,
                 .objcClassWrapper,
                 .existentialMetatype,
                 .heapLocalVariable,
                 .heapGenericLocalVariable,
                 .errorObject:
                return .unknown
        }
    }
}

extension StructMetadata {
    var isDateOrData: Bool {
        return self.descriptor == KnownMetadata.date ||
            self.descriptor == KnownMetadata.data
    }
}

protocol NominalType: TypeMetadata {
    var genericMetadata: [Metadata] { get }
    var fieldOffsets: [Int] { get }
    var fields: [Field] { get }
    var description: String { get }
}

protocol ContextualNominalType: NominalType {
    associatedtype NominalTypeDescriptor: TypeContextDescriptor
    var descriptor: NominalTypeDescriptor { get }
}

extension ClassMetadata: NominalType, ContextualNominalType {
    typealias NominalTypeDescriptor = ClassDescriptor
}
extension StructMetadata: NominalType, ContextualNominalType {    
    typealias NominalTypeDescriptor = StructDescriptor
}
extension EnumMetadata: NominalType, ContextualNominalType {
    typealias NominalTypeDescriptor = EnumDescriptor
}

// MARK: KVC
extension ContextualNominalType {
    func recordIndex(forKey key: String) -> Int? {
        return self.descriptor.fields.records.firstIndex { $0.name == key }
    }
    
    func fieldOffset(for key: String) -> Int? {
        if let idx = self.recordIndex(forKey: key) {
            return self.fieldOffsets[idx]
        }
        
        return nil
    }
    
    func fieldType(for key: String) -> Metadata? {
        return self.fields.first(where: { $0.name == key })?.type
    }
    
    var shallowFields: [Field] {
        let r: [FieldRecord] = self.descriptor.fields.records
        return r.filter(\.hasMangledTypeName).map {
            return (
                $0.name,
                reflect(self.type(of: $0.mangledTypeName)!)
            )
        }
    }
}

extension StructMetadata {
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        let offset = self.fieldOffset(for: key)!
        let ptr = object~
        return ptr[offset]
    }
    
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }
    
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        let offset = self.fieldOffset(for: key)!
        let type = self.fieldType(for: key)!
        ptr.storeBytes(of: value, type: type, offset: offset)
    }
    
    var fields: [Field] { self.shallowFields }
}

extension ClassMetadata {
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        guard let offset = self.fieldOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.getValue(forKey: key, from: object)
            } else {
                fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
            }
        }

        let ptr = object~
        return ptr[offset]
    }
    
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }
    
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        guard let offset = self.fieldOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.set(value: value, forKey: key, pointer: ptr)
            } else {
                fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
            }
        }
        
        let type = self.fieldType(for: key)!
        ptr.storeBytes(of: value, type: type, offset: offset)
    }
    
    /// Consolidate all fields in the class hierarchy
    var fields: [Field] {
        if let sup = self.superclassMetadata, sup.isSwiftClass {
            return self.shallowFields + sup.fields
        }
        
        return self.shallowFields
    }
}

extension EnumMetadata {
    var fields: [Field] { self.shallowFields }
}

// MARK: Protocol conformance checking
extension TypeMetadata {
    func conforms(to _protocol: Any) -> Bool {
        let existential = reflect(_protocol) as! MetatypeMetadata
        let instance = existential.instanceMetadata as! ExistentialMetadata
        let desc = instance.protocols.first!
        
        return !self.conformances.filter({ $0.protocol == desc }).isEmpty
    }
}

// MARK: MetadataKind
extension MetadataKind {
    var isObject: Bool {
        return self == .class || self == .objcClassWrapper
    }
}

// MARK: Populating AnyExistentialContainer
extension AnyExistentialContainer {
    var toAny: Any {
        return unsafeBitCast(self, to: Any.self)
    }
    
    var isEmpty: Bool {
        return self.data == (0, 0, 0)
    }
    
    init(boxing valuePtr: RawPointer, type: Metadata) {
        self = .init(metadata: type)
        self.store(value: valuePtr)
    }
    
    init(nil optionalType: EnumMetadata) {
        self = .init(metadata: optionalType)
        
        // Zero memory
        let size = optionalType.vwt.size
        self.getValueBuffer().initializeMemory(
            as: Int8.self, repeating: 0, count: size
        )
    }
    
    mutating func store(value newValuePtr: RawPointer) {
        self.metadata.vwt.initializeWithCopy(self.getValueBuffer(), newValuePtr)
//        self.getValueBuffer().copyMemory(from: newValuePtr, type: self.metadata)
    }
    
    /// Calls into `projectValue()` but will allocate a box
    /// first if needed for types that are not inline
    mutating func getValueBuffer() -> RawPointer {
        // Allocate a box if needed and return it
        if !self.metadata.vwt.flags.isValueInline && self.data.0 == 0 {
            return self.metadata.allocateBoxForExistential(in: &self)~
        }
        
        // We don't need a box or already have one
        return self.projectValue()~
    }
}

extension FieldRecord: CustomDebugStringConvertible {
    public var debugDescription: String {
        let ptr = self.mangledTypeName.assumingMemoryBound(to: UInt8.self)
        return self.name + ": \(String(cString: ptr)) ( \(self.referenceStorage) : \(self.flags))"
    }
}

extension EnumMetadata {
    func getTag(for instance: Any) -> UInt32 {
        var box = container(for: instance)
        return self.enumVwt.getEnumTag(for: box.projectValue())
    }
    
    func copyPayload(from instance: Any) -> (value: Any, type: Any.Type)? {
        let tag = self.getTag(for: instance)
        let isPayloadCase = self.descriptor.numPayloadCases > tag
        if isPayloadCase {
            let caseRecord = self.descriptor.fields.records[Int(tag)]
            let type = self.type(of: caseRecord.mangledTypeName)!
            var caseBox = container(for: instance)
            // Copies in the value and allocates a box as needed
            let payload = AnyExistentialContainer(
                boxing: caseBox.projectValue()~,
                type: reflect(type)
            )
            return (unsafeBitCast(payload, to: Any.self), type)
        }
        
        return nil
    }
}

extension ProtocolDescriptor {
    var description: String {
        return self.name
    }
}

extension FunctionMetadata {
    var typeSignature: String {
        let params = self.paramMetadata.map(\.description).joined(separator: ", ")
        return "(" + params + ") -> " + self.resultMetadata.description
    }
}

extension TupleMetadata {
    var signature: String {
        let pairs = zip(self.labels, self.elements)
        return "(" + pairs.map { "\($0): \($1.metadata.description)" }.joined(separator: ", ") + ")"
    }
}

extension NominalType {
    var genericDescription: String {
        return "\(self.type)"
//        let generics = self.genericMetadata.map(\.description).joined(separator: ", ")
//        guard !generics.isEmpty else {
//            return "\(self.type)"            
//        }
//        
//        return "\(self.type)<\(generics)>"
    }
}

extension Metadata {
    var description: String {
        switch self.kind {
            case .class, .struct, .enum:
                return "\((self as! NominalType).genericDescription)"
            case .optional:
                return "\((self as! EnumMetadata).genericMetadata.first!.description)?"
            case .foreignClass:
                return "~ForeignClass"
            case .opaque:
                return "~Opaque"
            case .tuple:
                return (self as! TupleMetadata).signature
            case .function:
                return (self as! FunctionMetadata).typeSignature
            case .existential:
                if self.ptr~ == Any.self~ || self.ptr~ == AnyObject.self~ {
                    return "\(self.type)"
                }
                
                let ext = (self as! ExistentialMetadata)
                let protocols = ext.protocols.map(\.description).joined(separator: " & ")
                if let supercls = ext.superclassMetadata {
                    return supercls.description + " & " + protocols
                } else {
                    return protocols
                }
            case .metatype:
                return (self as! MetatypeMetadata).instanceMetadata.description + ".self"
            case .objcClassWrapper:
                return "~ObjcClassWrapper"
            case .existentialMetatype:
                if self.ptr~ == AnyClass.self~ {
                    return "AnyClass"
                }
                return "~Existential"
            case .heapLocalVariable:
                return "~HLV"
            case .heapGenericLocalVariable:
                return "~HGLV"
            case .errorObject:
                return "~ErrorObject"
        }
    }
}
