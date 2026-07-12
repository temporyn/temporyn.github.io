
---

***index***

[1. 문단과 줄바꿈](#1-문단과-줄바꿈)  
[2. 헤딩](#2-헤딩)  
[3. 텍스트 강조](#3-텍스트-강조)  
[4. 목록](#4-목록)  
    [순서 없는 / 중첩](#순서-없는--중첩)  
    [순서 있는](#순서-있는)  
    [작업 목록 (GFM)](#작업-목록-gfm)  
[5. 링크](#5-링크)  
[6. 이미지](#6-이미지)  
[7. 인용문 (중첩)](#7-인용문-중첩)  
[8. 코드](#8-코드)  
[9. 표 (정렬)](#9-표-정렬)  
[10. 수평선](#10-수평선)  
[11. 정의 목록 (kramdown)](#11-정의-목록-kramdown)  
[12. 각주 (kramdown)](#12-각주-kramdown)  
[13. 인라인 HTML](#13-인라인-html)  
[14. 이스케이프](#14-이스케이프)  
[15. kramdown 속성 (IAL)](#15-kramdown-속성-ial)

---

> 엔진: kramdown (`input: GFM`), 하이라이터: Rouge.

# 1. 문단과 줄바꿈

빈 줄로 문단을 구분한다. 한 문단 안에서 강제 줄바꿈은 줄 끝에 **공백 두 칸** 또는 `\`를 쓴다.

~~~markdown
첫 번째 문단이다.

두 번째 문단이다.
줄 끝 공백 두 칸으로  
줄바꿈했다.
~~~

**결과:**

첫 번째 문단이다.

두 번째 문단이다.
줄 끝 공백 두 칸으로  
줄바꿈했다.

---

# 2. 헤딩

~~~markdown
# H1
## H2
### H3
#### H4
##### H5
###### H6
~~~

**결과:**

# H1
## H2
### H3
#### H4
##### H5
###### H6

---

# 3. 텍스트 강조

~~~markdown
**굵게**, *기울임*, ***굵은 기울임***, ~~취소선~~, `인라인 코드`
~~~

**결과:** **굵게**, *기울임*, ***굵은 기울임***, ~~취소선~~, `인라인 코드`

---

# 4. 목록

## 순서 없는 / 중첩

~~~markdown
- 항목 A
- 항목 B
  - 중첩 B-1
  - 중첩 B-2
    - 중첩 B-2-1
- 항목 C
~~~

**결과:**

- 항목 A
- 항목 B
  - 중첩 B-1
  - 중첩 B-2
    - 중첩 B-2-1
- 항목 C

## 순서 있는

~~~markdown
1. 하나
2. 둘
   1. 둘-하나
   2. 둘-둘
3. 셋
~~~

**결과:**

1. 하나
2. 둘
   1. 둘-하나
   2. 둘-둘
3. 셋

## 작업 목록 (GFM)

~~~markdown
- [x] 완료된 작업
- [ ] 남은 작업
~~~

**결과:**

- [x] 완료된 작업
- [ ] 남은 작업

---

# 5. 링크

~~~markdown
- 인라인: [Jekyll](https://jekyllrb.com/)
- 제목 포함: [Jekyll](https://jekyllrb.com/ "공식 사이트")
- 참조: [쿠버네티스][k8s]
- 자동 링크: <https://example.com>

[k8s]: https://kubernetes.io/
~~~

**결과:**

- 인라인: [Jekyll](https://jekyllrb.com/)
- 제목 포함: [Jekyll](https://jekyllrb.com/ "공식 사이트")
- 참조: [쿠버네티스][k8s]
- 자동 링크: <https://example.com>

[k8s]: https://kubernetes.io/

---

# 6. 이미지

~~~markdown
![Temporyn-Git 로고](/assets/img/sample.svg)
~~~

**결과:**

![Temporyn-Git 로고](/assets/img/sample.svg)

---

# 7. 인용문 (중첩)

~~~markdown
> 1단계 인용이다.
>
> > 2단계 중첩 인용이다.
> > — 출처
~~~

**결과:**

> 1단계 인용이다.
>
> > 2단계 중첩 인용이다.
> > — 출처

---

# 8. 코드

인라인 코드는 백틱으로 감싼다: `` `code` ``.
블록은 세 개의 백틱과 언어 이름을 쓴다.

~~~markdown
```python
def add(a, b):
    return a + b
```
~~~

**결과:**

```python
def add(a, b):
    return a + b
```

---

# 9. 표 (정렬)

`:` 위치로 왼쪽/가운데/오른쪽 정렬을 지정한다.

~~~markdown
| 이름     | 타입   |   기본값 |
|:---------|:------:|--------:|
| replicas | int    |       1 |
| image    | string |   nginx |
~~~

**결과:**

| 이름     | 타입   |   기본값 |
|:---------|:------:|--------:|
| replicas | int    |       1 |
| image    | string |   nginx |

---

# 10. 수평선

~~~markdown
---
~~~

**결과:**

---

# 11. 정의 목록 (kramdown)

~~~markdown
HTTP
: HyperText Transfer Protocol.

DNS
: Domain Name System.
~~~

**결과:**

HTTP
: HyperText Transfer Protocol.

DNS
: Domain Name System.

---

# 12. 각주 (kramdown)

~~~markdown
본문 어딘가에 각주를 단다.[^ex]

[^ex]: 각주 내용은 페이지 맨 아래에 모여 렌더링된다.
~~~

**결과:**

본문 어딘가에 각주를 단다.[^ex]

[^ex]: 각주 내용은 페이지 맨 아래에 모여 렌더링된다.

---

# 13. 인라인 HTML

마크다운 안에 HTML을 직접 쓸 수 있다.

~~~markdown
<kbd>Ctrl</kbd> + <kbd>C</kbd> 로 복사, 각주<sup>1</sup> 와 아래첨자<sub>2</sub>.
~~~

**결과:** <kbd>Ctrl</kbd> + <kbd>C</kbd> 로 복사, 각주<sup>1</sup> 와 아래첨자<sub>2</sub>.

---

# 14. 이스케이프

특수문자를 그대로 출력하려면 `\` 를 앞에 붙인다.

~~~markdown
\*별표\*, \`백틱\`, \# 샵 을 문자 그대로.
~~~

**결과:** \*별표\*, \`백틱\`, \# 샵 을 문자 그대로.

---

# 15. kramdown 속성 (IAL)

kramdown은 요소에 클래스/속성을 붙일 수 있다(고급).

~~~markdown
이 문단은 경고 스타일이다.
{: .note }

[버튼처럼](#){: .button }
~~~

`{: .클래스 }` 문법으로 CSS 훅을 걸 수 있다. (해당 클래스 스타일은 별도 정의 필요)
