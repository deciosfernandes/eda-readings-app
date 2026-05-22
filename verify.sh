echo "Test 2: Path Traversal"
curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:8080/api/leitura/../../not_allowed"

echo "Test 3: Body Size (Content-Length)"
curl -s -o /dev/null -w "%{http_code}\n" -X PUT -H "Content-Length: 2000000" http://localhost:8080/api/leitura

echo "Test 4: Body Size (Chunked)"
# Create a 1.1MB file
dd if=/dev/zero of=large_file bs=1M count=1.1 2>/dev/null
curl -s -o /dev/null -w "%{http_code}\n" -X PUT -T large_file http://localhost:8080/api/leitura
rm large_file
