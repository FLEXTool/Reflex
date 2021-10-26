//
//  ReflexTests.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/8/21.
//

import XCTest
import Combine
import Echo
@testable import Reflex

class ReflexTests: XCTestCase {
    var bob = Employee(name: "Bob", age: 55, position: "Programmer")
    lazy var employee = reflectClass(bob)!
    lazy var person = employee.superclassMetadata!
    lazy var employeeFields = employee.descriptor.fields
    lazy var personFields = person.descriptor.fields
    
    func assertFieldsEqual(_ expectedNames: [String], _ fields: FieldDescriptor) {
        let fieldNames: Set<String> = Set(fields.records.map(\.name))
        XCTAssertEqual(fieldNames, Set(expectedNames))
    }
    
    func testPointerSemantics() {
        let point = Point(x: 5, y: 7)
        let yval = withUnsafeBytes(of: point) { (ptr) -> Int in
            return ptr.load(fromByteOffset: MemoryLayout<Int>.size, as: Int.self)
        }
        
        XCTAssertEqual(yval, 7)
    }
    
    func testKVCGetters() {
        assertFieldsEqual(["position", "salary", "cubicleSize"], employeeFields)
        assertFieldsEqual(["name", "age"], personFields)
        
        XCTAssertEqual(bob.position, employee.getValue(forKey: "position", from: bob))
        XCTAssertEqual(bob.salary, employee.getValue(forKey: "salary", from: bob))
        XCTAssertEqual(bob.cubicleSize, employee.getValue(forKey: "cubicleSize", from: bob))
        XCTAssertEqual(bob.name, person.getValue(forKey: "name", from: bob))
        XCTAssertEqual(bob.age, person.getValue(forKey: "age", from: bob))
    }
    
    func testKVCSetters() {
        person.set(value: "Robert", forKey: "name", on: &bob)
        XCTAssertEqual("Robert", bob.name)
        XCTAssertEqual(bob.name, person.getValue(forKey: "name", from: bob))
        
        person.set(value: 23, forKey: "age", on: &bob)
        XCTAssertEqual(23, bob.age)
        XCTAssertEqual(bob.age, person.getValue(forKey: "age", from: bob))
        
        employee.set(value: "Janitor", forKey: "position", on: &bob)
        XCTAssertEqual("Janitor", bob.position)
        XCTAssertEqual(bob.position, employee.getValue(forKey: "position", from: bob))
        
        employee.set(value: 3.14159, forKey: "salary", on: &bob)
        XCTAssertEqual(3.14159, bob.salary)
        XCTAssertEqual(bob.salary, employee.getValue(forKey: "salary", from: bob))
    }
    
    func testTypeNames() {
        XCTAssertEqual(person.descriptor.name, "Person")
    }
    
    func testAbilityToDetectSwiftTypes() {
        let nonSwiftObjects: [Any] = [
            NSObject.self,
            NSObject(),
            UIView.self,
            UIView(),
            "a string",
            12345,
            self.superclass!,
        ]
        
        let swiftObjects: [Any] = [
            ReflexTests.self,
            self,
            Person.self,
            bob,
            [1, 2, 3],
            [Point(x: 1, y: 2)]
        ]
        
        for obj in swiftObjects {
            XCTAssertTrue(isSwiftObjectOrClass(obj))
        }
        for obj in nonSwiftObjects {
            XCTAssertFalse(isSwiftObjectOrClass(obj))
        }
    }
    
    @available(iOS 13.0, *)
    func testTypeDescriptions() {
        typealias LongPublisher = Publishers.CombineLatest<AnyPublisher<Any, Error>,AnyPublisher<Any, Error>>
        
        XCTAssertEqual("Any",        reflect(Any.self).description)
        XCTAssertEqual("AnyObject",  reflect(AnyObject.self).description)
        XCTAssertEqual("AnyClass",   reflect(AnyClass.self).description)
        
        XCTAssertEqual("Counter<Int>",         reflect(Counter<Int>.self).description)
        XCTAssertEqual("Array<Int>",           reflect([Int].self).description)
        XCTAssertEqual("(id: Int, 1: Person)", reflect((id: Int, Person).self).description)
        XCTAssertEqual("Counter<Int>",         reflect(Counter<Int>.self).description)
        XCTAssertEqual("Array<Counter<Int>>",  reflect([Counter<Int>].self).description)
        XCTAssertEqual("CombineLatest<AnyPublisher<Any, Error>, AnyPublisher<Any, Error>>",
                       reflect(LongPublisher.self).description
        )
        
        let ikur: (inout Person) -> Bool = isKnownUniquelyReferenced
        XCTAssertEqual("(ReflexTests) -> () -> ()", reflect(Self.testTypeDescriptions).description)
        XCTAssertEqual("(Person) -> Bool", reflect(ikur).description)
    }
    
    func testValueDescriptions() {
        
    }
    
    func testSwiftMirror() {
        let slider = RFSlider(color: .red, frame: .zero)
        let mirror = FLEXSwiftMirror(reflecting: slider)
        
        XCTAssertEqual(mirror.ivars.count, 5)
        XCTAssertEqual(mirror.properties.count, 1)
        XCTAssertEqual(mirror.methods.count, 5)
        XCTAssertEqual(mirror.protocols.count, 1)
    }
}
