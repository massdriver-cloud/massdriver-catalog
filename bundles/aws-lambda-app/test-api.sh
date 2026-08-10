#!/usr/bin/env bash
# Smoke test for the example REST API in src/app.
#
#   ./test-api.sh https://<your-api>.execute-api.<region>.amazonaws.com
#
# Creates items, exercises the error paths, then deletes everything it made.
BASE=${1:?usage: ./test-api.sh <api-base-url>}
PASS=0; FAIL=0

check() { # name expected actual
  if [ "$2" = "$3" ]; then
    printf '  PASS  %-46s %s\n' "$1" "$3"; PASS=$((PASS+1))
  else
    printf '  FAIL  %-46s expected=%s got=%s\n' "$1" "$2" "$3"; FAIL=$((FAIL+1))
  fi
}

code() { curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$@"; }
body() { curl -sS --max-time 30 "$@"; }

echo "== happy path =="
check "GET / root"            200 "$(code $BASE/)"
check "GET /items empty list" 200 "$(code $BASE/items)"

count() { body $BASE/items | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["items"]))'; }
BEFORE=$(count)

ID=$(body -X POST $BASE/items -H 'content-type: application/json' \
      -d '{"name":"widget","qty":3}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
echo "  created id=$ID"
check "POST /items created"   201 "$(code -X POST $BASE/items -H 'content-type: application/json' -d '{"name":"second"}')"
check "GET /items/{id}"       200 "$(code $BASE/items/$ID)"
check "round-trips name"      widget "$(body $BASE/items/$ID | python3 -c 'import sys,json;print(json.load(sys.stdin)["name"])')"
check "list grew by 2"        $((BEFORE+2)) "$(count)"
check "DELETE /items/{id}"    204 "$(code -X DELETE $BASE/items/$ID)"
check "GET after delete 404"  404 "$(code $BASE/items/$ID)"

echo "== routing / errors =="
check "unknown path 404"      404 "$(code $BASE/nope)"
check "nested unknown 404"    404 "$(code $BASE/a/b/c)"
check "PUT /items 405"        405 "$(code -X PUT $BASE/items)"
check "PATCH /items/{id} 405" 405 "$(code -X PATCH $BASE/items/xyz)"
check "DELETE missing id 204" 204 "$(code -X DELETE $BASE/items/does-not-exist)"
check "trailing slash /items/" 200 "$(code $BASE/items/)"

echo "== malformed input =="
check "POST invalid JSON"     400 "$(code -X POST $BASE/items -H 'content-type: application/json' -d 'not json')"
check "POST empty body"       201 "$(code -X POST $BASE/items -H 'content-type: application/json' -d '')"
check "POST JSON array rejected" 400 "$(code -X POST $BASE/items -H 'content-type: application/json' -d '[1,2]')"

echo "== transport =="
check "content-type json"     "application/json" "$(curl -sS -o /dev/null -w '%{content_type}' --max-time 30 $BASE/)"
check "http/2"                "2" "$(curl -sS -o /dev/null -w '%{http_version}' --max-time 30 $BASE/)"
check "https enforced"        200 "$(code $BASE/)"

echo "== latency (warm) =="
for i in 1 2 3; do
  printf '  request %d: %ss\n' "$i" "$(curl -sS -o /dev/null -w '%{time_total}' --max-time 30 $BASE/)"
done

echo "== cleanup =="
for k in $(body $BASE/items | python3 -c 'import sys,json;[print(i) for i in json.load(sys.stdin)["items"]]'); do
  curl -sS -o /dev/null --max-time 30 -X DELETE $BASE/items/$k
done
check "bucket empty after cleanup" 0 "$(count)"

echo ""
echo "passed=$PASS failed=$FAIL"
