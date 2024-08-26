```shell

docker build -t mkol5222/luaser:latest .

docker compose up --build
curl --data 'foo=bar&bar=baz&bar=blah' localhost:8080/test
```