# CLI 사용 가이드

Claude Code CLI의 설치·로그인·기본 사용법·주요 명령·활용법. 실습은 Linux(Fedora) 기준.

---

## 설치

네이티브 설치 스크립트가 가장 간단하다(백그라운드 자동 업데이트).

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

다른 방법:

- **패키지 매니저**: Fedora는 dnf로도 설치 가능(공식 설치 문서 참고, 자동 업데이트 안 됨).
- **npm**: `npm install -g @anthropic-ai/claude-code`

수동 업데이트·버전 고정:

```bash
claude update            # 최신으로
claude install stable    # 안정 채널
```

---

## 로그인

`claude`를 처음 실행하면 브라우저로 인증하라는 안내가 뜬다. 한 번 로그인하면 자격 증명이 저장돼 다시 묻지 않는다. 세션 중 계정 전환·재인증은 `/login`.

- 로그인 계정: **Claude Pro / Max / Team / Enterprise 구독**, 또는 Claude Console(선불 API 크레딧).

---

## 시작하기

프로젝트 디렉터리에서 대화형 세션(REPL)을 연다.

```bash
cd /path/to/project
claude
```

이후 자연어로 질문·지시한다. Claude가 필요한 파일을 자동으로 읽으므로 컨텍스트를 수동으로 넣지 않아도 된다. **파일을 고치기 전에는 항상 승인을 묻는다.**

```text
이 프로젝트는 뭘 하는 거야?
main 파일에 hello world 함수 추가해줘
변경한 내용 커밋해줘
```

---

## 실행 방식 (셸 명령)

| 명령 | 동작 |
|:-----|:-----|
| `claude` | 대화형 세션 시작 |
| `claude "작업"` | 초기 프롬프트를 주고 대화형 시작 |
| `claude -p "질문"` | 비대화형(1회 실행 후 종료). `--print` |
| `cat file \| claude -p "설명"` | 파이프로 입력 전달 |
| `claude -c` | 현재 디렉터리의 최근 대화 이어가기. `--continue` |
| `claude -r "이름"` | 특정 세션 재개. `--resume` |

자주 쓰는 플래그:

| 플래그 | 의미 |
|:-------|:-----|
| `--model` | 모델 지정(`opus`, `sonnet`, `haiku`, `fable` 또는 전체 이름) |
| `--effort` | 추론 강도(`low`/`medium`/`high`/`xhigh`/`max`) |
| `--permission-mode` | 권한 모드(`default`/`acceptEdits`/`plan`/`auto`/`dontAsk`/`bypassPermissions`) |
| `-n, --name` | 세션 표시 이름 지정 |
| `--output-format` | 출력 형식(`text`/`json`/`stream-json`) |
| `--bg, --background` | 백그라운드 에이전트로 시작하고 즉시 반환 |

---

## 세션 안 명령 (슬래시)

세션 중 `/`를 입력하면 전체 목록이 뜬다. 명령은 메시지 맨 앞에서만 인식된다.

**대화 관리**

| 명령 | 동작 |
|:-----|:-----|
| `/clear` | 대화 기록 비우고 새 작업 시작(프로젝트 메모리는 유지) |
| `/compact` | 대화를 요약해 컨텍스트 공간 확보 |
| `/context` | 무엇이 컨텍스트를 채우는지 표시 |
| `/resume`, `/branch` | 이전 대화로 돌아가거나 분기 |
| `/rewind` | 코드·대화를 체크포인트로 되돌림 |

**모델·실행**

| 명령 | 동작 |
|:-----|:-----|
| `/model` | 모델 전환 |
| `/effort` | 추론 강도 조정 |
| `/plan` | 계획 모드로 전환(큰 변경 전) |

**설정·프로젝트**

| 명령 | 동작 |
|:-----|:-----|
| `/init` | 시작용 `CLAUDE.md` 생성 |
| `/memory` | 메모리(CLAUDE.md) 편집 |
| `/config`, `/settings` | 설정 편집 |
| `/permissions` | 승인 규칙 설정 |
| `/mcp` | MCP 서버 설정 |
| `/agents` | 서브에이전트 생성·관리 |
| `/statusline` | 상태줄 구성 |

**상태·리뷰·기타**

| 명령 | 동작 |
|:-----|:-----|
| `/cost` | 세션 비용·사용량 (`/stats` 별칭) |
| `/doctor`, `/debug` | 설치·런타임 문제 진단 |
| `/code-review` | 변경분에서 버그·정리 지점 찾기(`--fix`로 적용) |
| `/review` | GitHub PR 읽기 전용 리뷰 |
| `/security-review` | 변경분 보안 취약점 점검 |
| `/help` | 명령 목록 |
| `/login`, `/logout` | 로그인·로그아웃 |
| `/exit` | 종료(Ctrl+D) |

> 메시지를 `#`로 시작하면 그 내용이 **메모리(CLAUDE.md)** 에 저장된다.

---

## 활용법

- **구체적으로 요청한다.** "버그 고쳐" 대신 "로그인 시 잘못된 자격 증명이면 빈 화면이 뜨는 버그를 고쳐".
- **큰 작업은 단계로 쪼갠다.** 번호 매긴 절차로 지시하거나 `/plan`으로 계획을 먼저 잡는다.
- **먼저 탐색시킨다.** 수정 전에 "이 코드 구조 분석해줘"처럼 이해부터 시킨다.
- **단축키**: `/`로 명령 목록, `Tab` 자동완성, `↑` 히스토리, `Shift+Tab`으로 권한 모드 순환.
- **컨텍스트 관리**: 대화가 길어지면 `/context`로 확인하고 `/compact`(요약) 또는 `/clear`(초기화).
- **프로젝트 규칙은 `CLAUDE.md`에.** 여기 적은 내용은 세션마다 자동 로드된다.
- **잔량 상시 표시**: 상태줄로 컨텍스트·요금제 한도 잔량을 띄운다 → [실시간 토큰 잔량 표시](/claude/실시간-토큰-잔량-표시/).

---

## 참고 링크

- 퀵스타트: <https://code.claude.com/docs/en/quickstart>
- CLI 레퍼런스: <https://code.claude.com/docs/en/cli-reference>
- 명령 레퍼런스: <https://code.claude.com/docs/en/commands>
