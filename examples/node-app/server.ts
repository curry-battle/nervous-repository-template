// サンプル: 依存ゼロの最小 HTTP サーバ（実アプリに差し替える前提）
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'

const port = Number(process.env.PORT ?? 3000)

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ status: 'ok' }))
    return
  }
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' })
  res.end('Hello from the sample app\n')
})

server.listen(port, () => {
  console.log(`listening on :${port}`)
})
