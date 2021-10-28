//
//  FLEXSwiftMetadatas.swift
//  Reflex
//
//  Created by Tanner Bennett on 10/24/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import FLEX
import Echo

extension SwiftMirror {
    static func imagePath(for pointer: UnsafeRawPointer) -> String? {
        var exeInfo = Dl_info()
        if (dladdr(pointer, &exeInfo) != 0) {
            if let fname = exeInfo.dli_fname {
                return String(cString: fname)
            }
        }
        
        return nil
    }
}

@objc(FLEXSwiftIvar)
public class SwiftIvar: FLEXIvar {
    private let property: Field
    private let _offset: Int
    private let _imagePath: String?
    
    convenience init(field: Field, class: ClassMetadata) {
        self.init(
            field: field,
            offset: `class`.fieldOffset(for: field.name)!,
            parent: `class`
        )
    }
    
    init(field: Field, offset: Int, parent: Metadata) {
        self.property = field
        self._offset = offset
        self._imagePath = SwiftMirror.imagePath(for: parent.ptr)
    }
    
    
    public override var name: String { self.property.name }
    public override var type: FLEXTypeEncoding { .unknown }
    public override var typeEncoding: String { "?" }
    public override var offset: Int { _offset }
    public override var size: UInt { UInt(self.property.type.vwt.size) }
    public override var imagePath: String? { self._imagePath }
    
    public override var details: String {
        "\(size) bytes, \(offset), \(typeEncoding)"
    }
    
    public override func getValue(_ target: Any) -> Any? {
        // Target must be AnyObject for KVC to work
        let target = target as AnyObject
        let type = reflect(target)
        
        switch type.kind {
            case .struct:
                return (type as! StructMetadata).getValue(forKey: self.name, from: target)
            case .class:
                return (type as! ClassMetadata).getValue(forKey: self.name, from: target)
            default:
                return nil
        }
    }
    
    public override func setValue(_ value: Any?, on target: Any) {
        // Target must be AnyObject for KVC to work
        var target = target as AnyObject
        let type = reflect(target)
        guard type.kind == .class else { return }
        
        switch type.kind {
            case .struct: // Will never execute, but whatever
                (type as! StructMetadata).set(value: value, forKey: self.name, on: &target)
            case .class:
                (type as! ClassMetadata).set(value: value, forKey: self.name, on: &target)
            default:
                return
        }
    }
    
    public override func getPotentiallyUnboxedValue(_ target: Any) -> Any? {
        return self.getValue(target)
    }
}

@objc(FLEXSwiftProtocol)
public class SwiftProtocol: FLEXProtocol {
    private let `protocol`: ProtocolDescriptor
    
    init(protocol ptcl: ProtocolDescriptor) {
        self.protocol = ptcl
        
        super.init()
    }
    
    public override var name: String {
        return self.protocol.name
    }
    
    public override var objc_protocol: Protocol {
        return ~self.protocol
    }
    
    private lazy var _imagePath: String? = {
        var exeInfo: Dl_info! = nil
        if (dladdr(self.protocol.ptr, &exeInfo) != 0) {
            if let fname = exeInfo.dli_fname {
                return String(cString: fname)
            }
        }
        
        return nil
    }()
    
    private lazy var swiftProtocols: [ProtocolDescriptor] = []
    
    public override var imagePath: String? { self._imagePath }
    
    public override var protocols: [FLEXProtocol] { self.swiftProtocols.map(SwiftProtocol.init(protocol:)) }
    public override var requiredMethods: [FLEXMethodDescription] { [] }
    public override var optionalMethods: [FLEXMethodDescription] { [] }
    
    public override var requiredProperties: [FLEXProperty] { [] }
    public override var optionalProperties: [FLEXProperty] { [] }
}
