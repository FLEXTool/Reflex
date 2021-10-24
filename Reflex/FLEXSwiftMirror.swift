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

class FLEXSwiftMirror: NSObject, FLEXMirrorProtocol {
    /// Really, AnyObject
    let value: Any
    
    let isClass: Bool
    let className: String
    
    private(set) var properties: [FLEXProperty] = []
    private(set) var ivars: [FLEXIvar] = []
    private(set) var methods: [FLEXMethod] = []
    private(set) var protocols: [FLEXProtocol] = []
    
    var superMirror: FLEXMirrorProtocol? {
        return nil
    }
    
    required init(reflecting objectOrClass: Any) {
        let cls: AnyClass = object_getClass(objectOrClass)!
        
        self.value = objectOrClass
        self.isClass = class_isMetaClass(cls)
        self.className = NSStringFromClass(cls)
        
        super.init()
        self.examine()
    }
    
    private func examine() {
        
    }
}
