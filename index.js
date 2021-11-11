#!/usr/bin/env -S deno run --allow-net --allow-env --allow-run --watch

const back = 'internetarchive-nomad-multiple-tasks-backend'
const task = Deno.env.get('NOMAD_TASK_NAME')
const listen = Number(Deno.env.get('NOMAD_PORT_http') || 5000)

console.log(`listening on ${listen}`)

const listener = Deno.listen({ port: listen })
for await (const conn of listener) void handle(conn)

async function handle(conn) {
  for await (const { request: req, respondWith: res } of Deno.serveHttp(conn)) {
    console.log(req.url)

    let msg = ''

    if (task && task !== back) {
      try {
        // now lookup the backend service:
        const p = Deno.run({
          cmd: ['dig', '+short', `${back}.service.consul`, 'SRV'],
          stdout: 'piped',
          stdin: 'null',
          stderr: 'null',
        })
        const port = new TextDecoder().decode(await p.output()).split(' ')[2]
        await p.status()
        p.close()

        console.log({ task, back, port })

        // now talk to the backend
        const backsay = await (await fetch(`http://${back}.connect.consul:${port}`)).text()

        msg += `\n\n talked to ${back} ${port}\n here's what they said:\n ${backsay}`
      } catch (error) {
        console.log({ error })
      }
    }

    res(new Response(`hai from ${task} ${msg}`))
  }
}
