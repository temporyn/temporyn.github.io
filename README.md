# temporyn.github.io

개인 기술 학습 문서 사이트. Obsidian 폴더 트리처럼 `content/`에 순수 마크다운을 넣으면
빌드 시 폴더 트리·검색·페이지가 자동 생성됩니다. (Jekyll + 커스텀 `_plugins/`)

## 문서 추가하기

`content/` 아래에 폴더/파일을 만들기만 하면 됩니다. front matter 불필요.

```
content/
  D00-kubernetes/          # 폴더: D + 번호 + -  (카테고리/하위폴더)
    F00-overview.md        # 파일: F + 번호 + -
    D00-networking/        # 무제한 중첩 가능
      F00-ingress.md
  D01-docker/
    F00-이미지-일괄정리.md   # → 화면 제목 "이미지 일괄정리"
```

- 정렬: 같은 폴더 안에서 폴더 → 파일, 각각 번호 오름차순
- 표시 제목: 접두사(`D00-`/`F00-`) 제거 + 하이픈 → 공백
- 본문 첫 줄의 `# 제목`은 자동 제거(제목 중복 방지)

## 로컬 실행

```bash
bundle install
bundle exec jekyll serve   # http://127.0.0.1:4000
```

## 배포

`main` 브랜치 push 시 `.github/workflows/pages.yml`이 자체 빌드 후 GitHub Pages로 배포합니다.
(github-pages gem을 쓰지 않으므로 커스텀 플러그인이 정상 동작)
