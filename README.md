## Promise

A basic implementation of a Promise patter in Swift with a list of handy features such as mapping, merging, and recovery.

```Swift
Promise<[Int]>.merge([p1, p2, p3])
    .always { print("") }
    .catch { print("_rejected: \($0)") }
    .cancelled { print("_cancelled") }
    .result { print("_got \($0)") }
    .always { print("_always") }
```
