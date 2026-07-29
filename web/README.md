# BeepTimer 지원 사이트 (Netlify 배포용)

App Store의 **지원 URL**과 **개인정보 처리방침 URL**로 쓰는 정적 사이트.
MineApp과 동일한 구조(랜딩 + `/support` + `/privacy-policy`)다.

```
web/
├─ index.html              →  /                (랜딩)
├─ support/index.html      →  /support         (고객 지원 / FAQ)
└─ privacy-policy/index.html → /privacy-policy  (개인정보처리방침)
```

폴더별 `index.html` 구조라 Netlify에서 `/support`, `/privacy-policy` 같은 깔끔한 주소로 열린다.

## 배포 방법

### 방법 A — 드래그 앤 드롭 (가장 간단)
1. [app.netlify.com](https://app.netlify.com) 로그인
2. "Add new site" → "Deploy manually"
3. **이 `web` 폴더**를 통째로 드래그해서 업로드
4. 발급된 주소(예: `https://xxxx.netlify.app`)가 나오면 완료

### 방법 B — 사이트 이름 바꾸기
배포 후 Site settings → Domain management → Options → Edit site name 에서
`beeptimer` 같은 이름으로 바꾸면 `https://beeptimer.netlify.app` 형태가 된다.

## App Store Connect에 넣을 값

- **지원 URL**: 발급된 루트 주소 (예: `https://beeptimer.netlify.app`)
- **개인정보 처리방침 URL**: 루트 + `/privacy-policy` (예: `https://beeptimer.netlify.app/privacy-policy`)
- **마케팅 URL**: 비워두거나 루트 주소

## 수정할 것

- 문의 이메일은 `lim0202jh@gmail.com`로 되어 있다. 바꾸려면 세 파일의 이메일을 함께 수정.
- 개인정보처리방침의 시행일/최종 수정일은 실제 출시일에 맞춰 갱신하면 된다.
