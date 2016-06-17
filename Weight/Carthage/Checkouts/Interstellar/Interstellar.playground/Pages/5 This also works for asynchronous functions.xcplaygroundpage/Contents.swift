//: [Previous](@previous)

//: This also works for asynchronous functions

import Foundation
import Interstellar

let text = Signal<String>()

func greetMaybe(subject: String, completion: Result<String>->Void) {
    if subject.characters.count % 2 == 0 {
        completion(.success("Hello \(subject)"))
    } else {
        let error = NSError(domain: "Don't feel like greeting you.", code: 401, userInfo: nil)
        completion(.error(error))
    }
}

text
    .flatMap(greetMaybe)
    .next { text in
        print(text)
    }
    .error { error in
        print("There was a greeting error")
    }

text.update("World")

//: [Next](@next)
