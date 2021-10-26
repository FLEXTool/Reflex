//
//  FLEXSwiftMirror.swift
//  Reflex
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import FLEX
import Echo

public class FLEXSwiftMirror: NSObject, FLEXMirrorProtocol {
    /// Never a metaclass
    private let `class`: AnyClass
    private let metadata: ClassMetadata
    private var flexMirror: FLEXMirror
    
    /// Really it's AnyObject
    public let value: Any
    public let isClass: Bool
    public let className: String
    
    private(set) public var properties: [FLEXProperty] = []
    private(set) public var ivars: [FLEXIvar] = []
    private(set) public var methods: [FLEXMethod] = []
    private(set) public var protocols: [FLEXProtocol] = []
    
    public var superMirror: FLEXMirrorProtocol? {
        guard let supercls = class_getSuperclass(self.class) else {
            return nil
        }
        
        if reflectClass(supercls)!.isSwiftClass {
            return Self.init(reflecting: supercls)
        } else {
            return FLEXMirror(reflecting: supercls)
        }
    }
    
    required public init(reflecting objectOrClass: Any) {
        let cls: AnyClass = object_getClass(objectOrClass)!
        
        self.value = objectOrClass
        self.isClass = class_isMetaClass(cls)
        self.className = NSStringFromClass(cls)
        
        self.metadata = reflectClass(self.value)!
        self.flexMirror = FLEXMirror(reflecting: self.value)
        self.class = self.isClass ? objectOrClass as! AnyClass : cls
        
        super.init()
        self.examine()
    }
    
    private func examine() {
        let swiftIvars: [FLEXSwiftIvar] = self.metadata.fields.map {
            .init(field: $0, class: self.metadata)
        }
        
        let swiftProtos: [FLEXSwiftProtocol] = self.metadata.conformances
            .map(\.protocol)
            .map { .init(protocol: $0) }
        
        let fm = self.flexMirror
        let ivarNames = Set(swiftIvars.map(\.name))
        self.ivars = swiftIvars + fm.ivars.filter { !ivarNames.contains($0.name) }
        self.properties = fm.properties
        self.methods = fm.methods
        self.protocols = swiftProtos + fm.protocols
    }
}
