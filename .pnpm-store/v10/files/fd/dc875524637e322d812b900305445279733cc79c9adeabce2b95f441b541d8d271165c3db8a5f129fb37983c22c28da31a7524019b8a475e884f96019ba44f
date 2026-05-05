import http from 'node:http';
export class ProtoClient {
    async get(msgType, requestPath) {
        const server = this.config.getCurrentCluster().server;
        const u = new URL(server);
        const options = {
            path: requestPath,
            hostname: u.hostname,
            protocol: u.protocol,
        };
        await this.config.applyToHTTPSOptions(options);
        const req = http.request(options);
        const result = await new Promise((resolve, reject) => {
            let data = '';
            req.on('data', (chunk) => {
                data = data + chunk;
            });
            req.on('end', () => {
                const obj = msgType.deserializeBinary(data);
                resolve(obj);
            });
            req.on('error', (err) => {
                reject(err);
            });
        });
        req.end();
        return result;
    }
}
//# sourceMappingURL=proto-client.js.map