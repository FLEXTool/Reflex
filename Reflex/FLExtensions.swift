//
//  FLExtensions.swift
//  Reflex
//
//  Created by Tanner Bennett on 10/29/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import FLEX

extension FLEXTypeEncoding {
    static func encode(`class` cls: Any.Type) -> String {
        return "@\"\(cls)\""
    }
}
