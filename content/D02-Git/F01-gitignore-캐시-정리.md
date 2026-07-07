# gitignore 캐시 정리

`.gitignore`를 나중에 추가했을 때, 이미 추적 중인 파일을 캐시에서 제거한다.

```bash
git rm -r --cached .
git add .
git commit -m "refactor: update gitignore"
```
