import fetch from 'node-fetch';
export class Health {
    constructor(config) {
        this.config = config;
    }
    async readyz(opts) {
        return this.check('/readyz', opts);
    }
    async livez(opts) {
        return this.check('/livez', opts);
    }
    async healthz(opts) {
        return this.check('/healthz', opts);
    }
    async check(path, opts) {
        const cluster = this.config.getCurrentCluster();
        if (!cluster) {
            throw new Error('No currently active cluster');
        }
        const requestURL = new URL(cluster.server + path);
        const requestInit = await this.config.applyToFetchOptions(opts);
        if (opts.signal) {
            requestInit.signal = opts.signal;
        }
        requestInit.method = 'GET';
        try {
            const response = await fetch(requestURL.toString(), requestInit);
            const status = response.status;
            if (status === 200) {
                return true;
            }
            if (status === 404) {
                if (path === '/healthz') {
                    // /livez/readyz return 404 and healthz also returns 404, let's consider it is live
                    return true;
                }
                return this.healthz(opts);
            }
            return false;
        }
        catch (err) {
            if (err.name === 'AbortError') {
                throw err;
            }
            throw new Error('Error occurred in health request');
        }
    }
}
//# sourceMappingURL=health.js.map