---
name: korean
description: Restate the previous assistant answer in natural Korean when the user invokes /korean or asks to have that answer explained in Korean. Not for translating repository files or setting a persistent language preference.
---

# 자연스러운 한국어로 정리

직전 턴의 최종 답변을 자연스럽고 이해하기 쉬운 한국어로 다시 작성한다. 사용자가 다른 답변이나 특정 부분을 지정하면 그 범위를 따른다. 대상 답변을 대화에서 찾을 수 없으면 원문을 요청한다.

- 핵심 결론을 먼저 쓰고, 필요한 근거와 설명을 이어 쓴다. 반복은 줄이되 중요한 조건, 주의사항, 미해결 문제와 다음 행동을 보존한다. 사용자가 요약을 요청하지 않았다면 핵심 내용을 임의로 생략하지 않는다.
- 원문의 의미와 확신 수준을 유지한다. 추측을 사실로 바꾸거나 원문에 없는 설명과 검증 결과를 덧붙이지 않는다.
- 직역투와 압축된 명사 나열을 풀어 쓰고, 주어와 행동이 분명한 문장으로 연결한다. 익숙한 기술 용어와 공식 이름은 유지하고, 생소한 용어는 필요할 때 한국어 설명과 원어를 함께 쓴다.
- 코드, 명령어, 경로, 식별자, 수치와 링크 주소는 그대로 유지한다. 링크의 설명 문구는 한국어로 다듬어도 된다.
- 원래 작업을 다시 실행하거나 파일을 수정하지 않는다. 한국어로 정리한 답변만 대화에 출력한다.
