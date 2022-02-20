#!/usr/bin/env -S deno run --allow-net --allow-env --allow-run --watch

/*
dig +short  internetarchive-nomad-multiple-tasks.service.consul          SRV
dig +short  internetarchive-nomad-multiple-tasks-backend.service.consul  SRV
*/

const back = 'internetarchive-nomad-multiple-tasks-backend'
const task = Deno.env.get('NOMAD_TASK_NAME')
const listen = Number(Deno.env.get(task !== back ? 'NOMAD_PORT_http' : 'NOMAD_PORT_backend'))

console.log(`listening on ${listen}`)

const listener = Deno.listen({ port: listen })
for await (const conn of listener) void handle(conn)

async function handle(conn) {
  for await (const { request: req, respondWith: res } of Deno.serveHttp(conn)) {
    console.log(req.url)

    let msg = ''

    if (task && task !== back) {
      try {
        /*
        // now lookup the backend service:
        const p = Deno.run({cmd: ['dig', '+short', `${back}.service.consul`, 'SRV'], stdout: 'piped' })
        await p.status()
        const port = new TextDecoder().decode(await p.output()).split(' ')[2]
        console.log({ task, back, port })
        const hostport = `${back}.connect.consul:${port}`
        */
        const hostport = Deno.env.get('NOMAD_ADDR_backend')

        // now talk to the backend
        const backsay = await (await fetch(`http://${hostport}`)).text()

        msg += `\n\n talked to ${back}\n here's what they said:\n ${backsay}`
      } catch (error) {
        console.log({ error })
      }
    }

    res(new Response(`hai from ${task} ${msg}`))
  }
}
