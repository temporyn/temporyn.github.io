# 프로젝트 컨텍스트

## 목적
- 개인 기술 문서화
- 블로그 아님. 카테고리는 `content/` 폴더 구조로 관리하고, 나열/트리/검색은 코드가 자동 생성

## 확정 사항
- **SSG**: Jekyll (Ruby). GitHub Actions로 빌드/배포 (github-pages gem 미사용 → 커스텀 `_plugins/` 사용 가능)
  - 배포 워크플로: `.github/workflows/pages.yml` (자체 `bundle exec jekyll build` + `deploy-pages`)
- **콘텐츠 구조**: `content/` 단일 루트 아래 **다단계 무제한 중첩 폴더**
  - front matter **없이** 순수 마크다운만 작성 → `_plugins/docs.rb`가 빌드 시 자동 처리
  - 네이밍: 폴더 `D00-`, 파일 `F00-` 접두사
  - 정렬: 같은 폴더 안에서 **폴더(D) → 파일(F)**, 각각 접두사 숫자 오름차순
  - 표시 제목: 접두사 제거 + 하이픈/언더스코어 → 공백 (예: `F00-이미지-일괄정리.md` → "이미지 일괄정리")
  - URL: 접두사만 제거 (하이픈/한글 유지). 예: `/docker/이미지-일괄정리/`
  - 본문 맨 앞의 최상위 `# 제목` 한 줄은 자동 제거(제목 중복 방지)
- **`_plugins/docs.rb`가 생성하는 것**:
  1. 각 문서 페이지(layout `doc`, `render_with_liquid: false` → Helm/k8s `{{ }}` 안전)
  2. 최상위 폴더별 카테고리 랜딩 페이지(본문 비움 → 사이드바 트리만)
  3. 폴더 트리 HTML(폴더별 재귀 문서 개수 배지 포함) → `site.nav_html`
  4. 전문 검색 인덱스 → `/assets/search-index.json`
- **네비게이션 / 사이드바** (`_includes/sidebar.html`, 홈·문서·카테고리 페이지 공통):
  - 홈(`/`)은 없앰 → 좌측 트리 + 가운데 "Temporary Page" 문구만 (`_layouts/home.html`)
  - 사이드바 배경 없음. 폴더 우측에 **하위 문서 개수 배지**(재귀 카운트)로 구조 구분
  - `© temporyn`은 사이드바 맨 아래 flex 고정(`.sidebar-footer`, 좌측 하단, 스크롤 없이 항상 보임)
  - 기본 전체 접힘. 특정 문서 URL 직접 진입 시 그 경로만 자동 펼침
  - 펼침/접힘 상태는 문서 이동 후에도 유지 (localStorage `temporyn-open`, `assets/js/site.js`)
  - 폴더 클릭 = 펼치기/접기만 (폴더는 페이지 없음)
  - 아티클 **제목 아래**에 전체 경로 breadcrumb 표시 (예: `kubernetes / networking`)
  - 긴 폴더/파일명은 트리에서 줄바꿈(word-break)으로 전체 표시
- **검색**: 전문 검색(제목+본문). 사이드바 상단 입력창(placeholder `search`), 클라이언트 JS가 인덱스 fetch 후 필터
- **코드 하이라이팅**: kramdown+rouge. 토큰 색은 `temporyn.css`에서 CSS 변수(`--syn-*`)로 라이트/다크 자동 대응 (yaml/xml/java/bash/shell 등)
- **테마**: 커스텀 CSS `assets/css/temporyn.css` (new.css/terminal 베이스 폐기, 전면 재작성)
  - **기본은 항상 라이트**(시스템 설정 무시). 다크는 수동 토글(`data-theme="dark"`)로만 적용
  - 토글 선택은 localStorage `temporyn-theme`에 저장(유지). FOUC 방지: `<head>`에 테마 인라인 스크립트 + 크리티컬 인라인 CSS(배경/폰트/색)로 외부 CSS 적용 전 첫 페인트 보정
  - 코드 블록은 본문과 구분되도록 테두리(`--code-border`)+배경 톤+간격 강조
  - 팔레트: 배경 **ghostwhite(#f8f8ff)** + **인디고 강조**(라이트 #4f46e5 / 다크 #a5b4fc). 라이트·다크 모두 WCAG AA
  - 경계선/박스 지양 → 중앙 정렬(max 1240px) + 좌우 gutter + 여백으로만 구분
  - 폰트(전부 self-host, 외부 의존 없음): 라틴 **Fira Code**, 한글 **Pretendard(가변 woff2)** 폴백 (`assets/fonts/*.woff2`)
- **Gemfile**: jekyll, webrick만 (테마 gem·플러그인 gem 없음)

## 로컬 빌드/실행
- `bundle exec jekyll serve` (이 환경에선 binstub 이슈로 `ruby ~/bin/jekyll serve` 사용)
- `content/`는 `_config.yml`의 `exclude`에 있어 Jekyll 기본 처리에서 제외됨(플러그인이 직접 스캔)
