#!/usr/bin/env bash
# Тесты соответствия контракту API (curl). Запуск: bash tests/contract.sh [base_url]
B=${1:-http://localhost:5080}; pass=0; fail=0
check(){ if [ "$2" = "$3" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 (want $2 got $3)"; fail=$((fail+1)); fi; }
code(){ curl -s -o /dev/null -w '%{http_code}' "$@"; }
E="t$RANDOM@pam.md"
check "health 200" 200 $(code $B/health)
check "register 201" 201 $(code -X POST $B/auth/register -H 'Content-Type: application/json' -d "{\"email\":\"$E\",\"password\":\"secret1\"}")
check "register dup 409" 409 $(code -X POST $B/auth/register -H 'Content-Type: application/json' -d "{\"email\":\"$E\",\"password\":\"secret1\"}")
check "login wrong 401" 401 $(code -X POST $B/auth/login -H 'Content-Type: application/json' -d "{\"email\":\"$E\",\"password\":\"nope123\"}")
T=$(curl -s -X POST $B/auth/login -H 'Content-Type: application/json' -d "{\"email\":\"$E\",\"password\":\"secret1\"}" | python -c "import json,sys;print(json.load(sys.stdin)['token'])")
H="Authorization: Bearer $T"
check "sessions no token 401" 401 $(code $B/sessions)
check "create session 201" 201 $(code -X POST $B/sessions -H "$H" -H 'Content-Type: application/json' -d '{"title":"Утреннее дыхание","practiceType":"breathe","durationMin":5,"notes":"тест","soundEnabled":true}')
check "create invalid 400" 400 $(code -X POST $B/sessions -H "$H" -H 'Content-Type: application/json' -d '{"title":"x","practiceType":"breathe","durationMin":500}')
ID=$(curl -s "$B/sessions?page=1&pageSize=5" -H "$H" | python -c "import json,sys;d=json.load(sys.stdin);print(d['items'][0]['id'] if d['total']==1 and d['page']==1 else 'bad')")
check "list paginated envelope" ok $([ "$ID" != bad ] && echo ok)
check "search q" 1 $(curl -s "$B/sessions?q=дыхание" -H "$H" | python -c "import json,sys;print(json.load(sys.stdin)['total'])")
check "get by id 200" 200 $(code $B/sessions/$ID -H "$H")
check "update 200" 200 $(code -X PUT $B/sessions/$ID -H "$H" -H 'Content-Type: application/json' -d '{"title":"Вечернее дыхание","practiceType":"breathe","durationMin":10,"notes":"","soundEnabled":false}')
check "notes create 201" 201 $(code -X POST $B/notes -H "$H" -H 'Content-Type: application/json' -d '{"title":"note","body":"b"}')
echo hello > upload_test.txt
check "file upload 201" 201 $(code -X POST $B/files -H "$H" -F "file=@upload_test.txt;type=text/plain")
check "delete 204" 204 $(code -X DELETE $B/sessions/$ID -H "$H")
check "get deleted 404" 404 $(code $B/sessions/$ID -H "$H")
rm -f upload_test.txt; echo "---- $pass passed, $fail failed"; [ $fail = 0 ]
