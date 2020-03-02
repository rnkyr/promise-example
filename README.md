## Promise

A lightweight implementation of a Promise patter in Swift with a list of handy features such as mapping, merging, and recovery.

```Swift
Promise<[Int]>.merge([p1, p2, p3])
    .always { print("") }
    .catch { print("_rejected: \($0)") }
    .cancelled { print("_cancelled") }
    .result { print("_got \($0)") }
    .always { print("_always") }
```

Refer to [feature/tests](https://github.com/rnkyr/promise-example/tree/feature/tests) branch for a complete, tested framework.
