## YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels: { app: web, tier: frontend }
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    spec:
      containers:
        - name: web
          image: nginx:1.27
          env:
            - name: LOG_LEVEL
              value: "info"
          ports:
            - containerPort: 80
```

## JSON

```json
{
  "name": "temporyn",
  "version": "1.0.0",
  "private": true,
  "scripts": { "build": "jekyll build", "serve": "jekyll serve" },
  "keywords": ["docs", "jekyll", "obsidian"],
  "meta": { "count": 42, "enabled": true, "ratio": 0.75, "note": null }
}
```

## TOML

```toml
[package]
name = "temporyn"
version = "1.0.0"
authors = ["temporyn <me@example.com>"]

[dependencies]
jekyll = "4.4"

[features]
default = ["search", "dark-mode"]
```

## INI

```ini
[server]
host = 127.0.0.1
port = 4000        ; 로컬 포트

[logging]
level = debug
```

## XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans">
  <!-- 데이터소스 정의 -->
  <bean id="dataSource" class="com.zaxxer.hikari.HikariDataSource">
    <property name="jdbcUrl" value="jdbc:mysql://localhost/db"/>
    <property name="maximumPoolSize" value="10"/>
  </bean>
</beans>
```

## HTML

```html
<!DOCTYPE html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <title>예시</title>
  </head>
  <body>
    <h1 class="title" data-id="1">안녕하세요 &amp; 반갑습니다</h1>
    <!-- 주석 -->
    <a href="https://example.com">링크</a>
  </body>
</html>
```

## CSS

```css
:root {
  --accent: #4f46e5;
}
.button {
  color: var(--accent);
  padding: 0.5rem 1rem;              /* 여백 */
  border-radius: 8px;
  transition: background 0.2s ease;
}
.button:hover { background: #eef; }

@media (max-width: 640px) {
  .button { width: 100%; }
}
```

## SCSS

```scss
$accent: #4f46e5;

@mixin card($radius: 8px) {
  border-radius: $radius;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.card {
  @include card(12px);
  color: darken($accent, 10%);
  .title { font-weight: 700; }
}
```

## Bash / Shell

```bash
#!/usr/bin/env bash
set -euo pipefail

# 미사용 도커 이미지 정리
for id in $(docker images -qf dangling=true); do
  echo "removing ${id}"
  docker rmi "$id" || true
done

readonly NOW="$(date +%F)"
echo "done at ${NOW}"
```

## PowerShell

```powershell
# 최근 수정된 로그 파일 조회
Get-ChildItem -Path C:\logs -Filter *.log |
  Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 5 Name, Length
```

## Dockerfile

```dockerfile
FROM ruby:3.4-slim AS build
WORKDIR /app
COPY Gemfile* ./
RUN bundle install --jobs 4
COPY . .
EXPOSE 4000
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
```

## Makefile

```makefile
.PHONY: build serve clean

build:
	bundle exec jekyll build

serve: build
	bundle exec jekyll serve --livereload

clean:
	rm -rf _site
```

## Nginx

```nginx
server {
    listen 80;
    server_name temporyn.github.io;

    location / {
        root /var/www/site;
        try_files $uri $uri/ =404;
    }
}
```

## SQL

```sql
-- 사용자별 주문 수 집계
SELECT u.id, u.name, COUNT(o.id) AS orders
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.active = TRUE
GROUP BY u.id, u.name
HAVING COUNT(o.id) > 0
ORDER BY orders DESC
LIMIT 10;
```

## GraphQL

```graphql
query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    orders(first: 5) {
      edges { node { id total } }
    }
  }
}
```

## Python

```python
from dataclasses import dataclass
from typing import Iterable

@dataclass
class Point:
    x: int
    y: int

def centroid(points: Iterable[Point]) -> Point:
    pts = list(points)
    n = len(pts) or 1
    return Point(sum(p.x for p in pts) // n, sum(p.y for p in pts) // n)

if __name__ == "__main__":
    print(centroid([Point(0, 0), Point(2, 4)]))
```

## Go

```go
package main

import "fmt"

type Stack[T any] struct{ items []T }

func (s *Stack[T]) Push(v T) { s.items = append(s.items, v) }

func main() {
    s := &Stack[int]{}
    s.Push(1)
    s.Push(2)
    fmt.Printf("stack: %v\n", s.items)
}
```

## Rust

```rust
use std::collections::HashMap;

fn word_count(text: &str) -> HashMap<&str, usize> {
    let mut counts = HashMap::new();
    for word in text.split_whitespace() {
        *counts.entry(word).or_insert(0) += 1;
    }
    counts
}

fn main() {
    let counts = word_count("a b a c b a");
    println!("{:?}", counts);
}
```

## C

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *arr = malloc(3 * sizeof(int));
    for (int i = 0; i < 3; i++) {
        arr[i] = i * i;                 /* 제곱 */
        printf("arr[%d] = %d\n", i, arr[i]);
    }
    free(arr);
    return 0;
}
```

## C++

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> v{5, 3, 8, 1};
    std::sort(v.begin(), v.end());
    for (const auto& n : v) std::cout << n << ' ';
    std::cout << '\n';
}
```

## C#

```csharp
using System;
using System.Linq;

record User(int Id, string Name);

class Program {
    static void Main() {
        var users = new[] { new User(1, "Kim"), new User(2, "Lee") };
        var names = users.Where(u => u.Id > 1).Select(u => u.Name);
        Console.WriteLine(string.Join(", ", names));
    }
}
```

## Java

```java
package com.temporyn.demo;

import java.util.List;
import java.util.stream.Collectors;

public record User(long id, String name) {
    public static List<String> names(List<User> users) {
        return users.stream()
                    .map(User::name)
                    .collect(Collectors.toList());
    }
}
```

## Kotlin

```kotlin
data class User(val id: Long, val name: String)

fun main() {
    val users = listOf(User(1, "Kim"), User(2, "Lee"))
    users.filter { it.id > 1 }
         .forEach { println(it.name) }
}
```

## Swift

```swift
struct User {
    let id: Int
    let name: String
}

let users = [User(id: 1, name: "Kim"), User(id: 2, name: "Lee")]
let names = users.filter { $0.id > 1 }.map { $0.name }
print(names)
```

## JavaScript

```javascript
const sum = (arr) => arr.reduce((acc, n) => acc + n, 0);

async function load(url) {
  const res = await fetch(url);       // 비동기 요청
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
```

## TypeScript

```typescript
interface User {
  id: number;
  name: string;
}

function greet<T extends User>(user: T): string {
  return `Hello, ${user.name} (#${user.id})`;
}
```

## Ruby

```ruby
class Greeter
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def greet = "Hello, #{name}!"   # 엔드리스 메서드 (Ruby 3+)
end

puts Greeter.new("temporyn").greet
```

## PHP

```php
<?php
declare(strict_types=1);

function greet(string $name): string {
    return "Hello, {$name}!";
}

$users = ['Kim', 'Lee'];
foreach ($users as $u) {
    echo greet($u), PHP_EOL;
}
```

## Lua

```lua
local function map(t, fn)
  local out = {}
  for i, v in ipairs(t) do
    out[i] = fn(v)
  end
  return out
end

print(table.concat(map({1, 2, 3}, function(n) return n * n end), ", "))
```

## Diff

```diff
 function greet(name) {
-  return "Hi " + name;
+  return `Hello, ${name}!`;
 }
```
