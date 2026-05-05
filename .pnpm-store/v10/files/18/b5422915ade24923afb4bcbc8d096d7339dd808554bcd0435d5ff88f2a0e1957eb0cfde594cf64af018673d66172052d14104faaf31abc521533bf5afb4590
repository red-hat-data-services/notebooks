import { STATUS_CODES } from 'node:http';
import { createInterface } from 'node:readline';
import fetch from 'node-fetch';
export class Watch {
    constructor(config) {
        this.config = config;
    }
    // Watch the resource and call provided callback with parsed json object
    // upon event received over the watcher connection.
    //
    // "done" callback is called either when connection is closed or when there
    // is an error. In either case, watcher takes care of properly closing the
    // underlaying connection so that it doesn't leak any resources.
    async watch(path, queryParams, callback, done) {
        const cluster = this.config.getCurrentCluster();
        if (!cluster) {
            throw new Error('No currently active cluster');
        }
        const watchURL = new URL(cluster.server + path);
        watchURL.searchParams.set('watch', 'true');
        for (const [key, val] of Object.entries(queryParams || {})) {
            if (val !== undefined) {
                watchURL.searchParams.set(key, val.toString());
            }
        }
        const requestInit = await this.config.applyToFetchOptions({});
        const controller = new AbortController();
        const timeoutSignal = AbortSignal.timeout(30000);
        requestInit.signal = AbortSignal.any([controller.signal, timeoutSignal]);
        requestInit.signal = controller.signal;
        requestInit.method = 'GET';
        let doneCalled = false;
        const doneCallOnce = (err) => {
            if (!doneCalled) {
                doneCalled = true;
                controller.abort();
                done(err);
            }
        };
        try {
            const response = await fetch(watchURL, requestInit);
            if (requestInit.agent && typeof requestInit.agent === 'object') {
                for (const socket of Object.values(requestInit.agent.sockets).flat()) {
                    socket === null || socket === void 0 ? void 0 : socket.setKeepAlive(true, 30000);
                }
            }
            if (response.status === 200) {
                const body = response.body;
                body.on('error', doneCallOnce);
                body.on('close', () => doneCallOnce(null));
                body.on('finish', () => doneCallOnce(null));
                const lines = createInterface(body);
                lines.on('error', doneCallOnce);
                lines.on('close', () => doneCallOnce(null));
                lines.on('finish', () => doneCallOnce(null));
                lines.on('line', (line) => {
                    try {
                        const data = JSON.parse(line.toString());
                        callback(data.type, data.object, data);
                    }
                    catch {
                        // ignore parse errors
                    }
                });
            }
            else {
                const statusText = response.statusText || STATUS_CODES[response.status] || 'Internal Server Error';
                const error = new Error(statusText);
                error.statusCode = response.status;
                throw error;
            }
        }
        catch (err) {
            doneCallOnce(err);
        }
        return controller;
    }
}
Watch.SERVER_SIDE_CLOSE = { error: 'Connection closed on server' };
//# sourceMappingURL=watch.js.map