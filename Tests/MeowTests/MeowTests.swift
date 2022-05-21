import XCTest
@testable import Meow

struct UserProfile: Codable {
    @Field var firstName: String?
    @Field var lastName: String?
    
    init() {}
}

struct User: Model {
    @Field var _id: ObjectId
    @Field var email: String
    @Field var password: String
    @Field var profile: UserProfile
    
    init(email: String, password: String, profile: UserProfile = UserProfile()) {
        self._id = ObjectId()
        self.email = email
        self.password = password
        self.profile = profile
    }
}

class MeowTests: XCTestCase {
    let settings = try! ConnectionSettings("mongodb://localhost/meow-tests")
    var meow: MeowDatabase!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let mongo = try await MongoDatabase.connect(to: settings)
        try await mongo.drop()
        self.meow = MeowDatabase(mongo)
    }
    
    func testNestedModelQueries() throws {
        try XCTAssertEqual(User.resolveFieldPath(\.$profile.$firstName), ["profile", "firstName"])
    }
    
    func testPartialUpdate() async throws {
        try await meow[User.self].updateOne { user in
            user.$email == "joannis@orlandos.nl"
        } build: { update in
            try update.setField(at: \.$password, to: "temporary")
        }
    }
    
    func testModelUpdater() async throws {
        let user = User(email: "joannis@orlandos.nl", password: "test")
        try await user.save(in: meow)
        
        let update = try await user.makePartialUpdate { user in
            user.$password = "Hunter2"
        }
        
        XCTAssertEqual(update.changes, ["password": "Hunter2"])
        let updatedUser = try await update.apply(on: meow[User.self])
        XCTAssertEqual(updatedUser.password, "Hunter2")
        
        let myEmail = "joannis@orlandos.nl"
        let count = try await meow[User.self].count { user in
            user.$email == myEmail
        }
        
        XCTAssertEqual(count, 1)
    }
    
    func testModelInstantiation() throws {
        let user = User(email: "joannis@orlandos.nl", password: "test")
        XCTAssertEqual(user.password, "test")
    }
    
    func testTopLevelModelQueries() throws {
        try XCTAssertEqual(User.resolveFieldPath(\User.$_id), ["_id"])
        try XCTAssertEqual(User.resolveFieldPath(\User.$password), ["password"])
        try XCTAssertEqual(User.resolveFieldPath(\User.$profile.$firstName), ["profile", "firstName"])
    }
}