import fetch from 'node-fetch';
import { ApiException } from './gen/index.js';
import { normalizeResponseHeaders } from './util.js';
export class Metrics {
    constructor(config) {
        this.config = config;
    }
    async getNodeMetrics() {
        return this.metricsApiRequest('/apis/metrics.k8s.io/v1beta1/nodes');
    }
    async getPodMetrics(namespace) {
        let path;
        if (namespace !== undefined && namespace.length > 0) {
            path = `/apis/metrics.k8s.io/v1beta1/namespaces/${namespace}/pods`;
        }
        else {
            path = '/apis/metrics.k8s.io/v1beta1/pods';
        }
        return this.metricsApiRequest(path);
    }
    async metricsApiRequest(path) {
        const cluster = this.config.getCurrentCluster();
        if (!cluster) {
            throw new Error('No currently active cluster');
        }
        const requestURL = cluster.server + path;
        const requestInit = await this.config.applyToFetchOptions({});
        requestInit.method = 'GET';
        try {
            const response = await fetch(requestURL, requestInit);
            const json = await response.json();
            const { status } = response;
            if (status === 200) {
                return json;
            }
            if (status === 500) {
                const v1status = json;
                const v1code = v1status.code;
                const v1message = v1status.message;
                if (v1code !== undefined && v1message !== undefined) {
                    throw new ApiException(v1code, v1message, v1status, normalizeResponseHeaders(response));
                }
            }
            throw new ApiException(status, 'Error occurred in metrics request', undefined, normalizeResponseHeaders(response));
        }
        catch (e) {
            if (e instanceof ApiException) {
                throw e;
            }
            throw new ApiException(500, `Error occurred in metrics request: ${e.message}`, {}, {});
        }
    }
}
//# sourceMappingURL=metrics.js.map