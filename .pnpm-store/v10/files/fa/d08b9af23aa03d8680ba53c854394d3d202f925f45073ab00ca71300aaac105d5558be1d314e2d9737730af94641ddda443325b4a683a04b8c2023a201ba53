import fetch from 'node-fetch';
import { ApiException } from './api.js';
import { normalizeResponseHeaders } from './util.js';
export function AddOptionsToSearchParams(options, searchParams) {
    var _a, _b, _c, _d, _e, _f;
    if (!options) {
        return;
    }
    searchParams.append('follow', ((_a = options === null || options === void 0 ? void 0 : options.follow) === null || _a === void 0 ? void 0 : _a.toString()) || 'false');
    if (options === null || options === void 0 ? void 0 : options.limitBytes) {
        searchParams.set('limitBytes', options.limitBytes.toString());
    }
    searchParams.set('pretty', ((_b = options === null || options === void 0 ? void 0 : options.follow) === null || _b === void 0 ? void 0 : _b.toString()) || 'false');
    searchParams.set('previous', ((_c = options === null || options === void 0 ? void 0 : options.previous) === null || _c === void 0 ? void 0 : _c.toString()) || 'false');
    if (options === null || options === void 0 ? void 0 : options.sinceSeconds) {
        searchParams.set('sinceSeconds', ((_d = options === null || options === void 0 ? void 0 : options.sinceSeconds) === null || _d === void 0 ? void 0 : _d.toString()) || 'false');
    }
    if (options === null || options === void 0 ? void 0 : options.sinceTime) {
        if (options === null || options === void 0 ? void 0 : options.sinceSeconds) {
            throw new Error('at most one of sinceTime or sinceSeconds may be specified');
        }
        searchParams.set('sinceTime', options === null || options === void 0 ? void 0 : options.sinceTime);
    }
    if (options === null || options === void 0 ? void 0 : options.tailLines) {
        searchParams.set('tailLines', ((_e = options === null || options === void 0 ? void 0 : options.tailLines) === null || _e === void 0 ? void 0 : _e.toString()) || 'false');
    }
    searchParams.set('timestamps', ((_f = options === null || options === void 0 ? void 0 : options.timestamps) === null || _f === void 0 ? void 0 : _f.toString()) || 'false');
    return searchParams;
}
export class Log {
    constructor(config) {
        this.config = config;
    }
    async log(namespace, podName, containerName, stream, doneOrOptions, options) {
        if (typeof doneOrOptions !== 'function') {
            options = doneOrOptions;
        }
        const path = `/api/v1/namespaces/${namespace}/pods/${podName}/log`;
        const cluster = this.config.getCurrentCluster();
        if (!cluster) {
            throw new Error('No currently active cluster');
        }
        const requestURL = new URL(cluster.server + path);
        const searchParams = requestURL.searchParams;
        searchParams.set('container', containerName);
        AddOptionsToSearchParams(options, searchParams);
        const requestInit = await this.config.applyToFetchOptions({});
        const controller = new AbortController();
        requestInit.signal = controller.signal;
        requestInit.method = 'GET';
        try {
            const response = await fetch(requestURL.toString(), requestInit);
            const status = response.status;
            if (status === 200) {
                // TODO: the follow search param still has the stream close prematurely based on my testing
                response.body.pipe(stream);
            }
            else if (status === 500) {
                const v1status = (await response.json());
                const v1code = v1status.code;
                const v1message = v1status.message;
                if (v1code !== undefined && v1message !== undefined) {
                    throw new ApiException(v1code, v1message, v1status, normalizeResponseHeaders(response));
                }
                else {
                    throw new ApiException(status, 'Error occurred in log request', undefined, normalizeResponseHeaders(response));
                }
            }
            else {
                throw new ApiException(status, 'Error occurred in log request', undefined, normalizeResponseHeaders(response));
            }
        }
        catch (err) {
            if (err instanceof ApiException) {
                throw err;
            }
            throw new ApiException(500, 'Error occurred in log request', undefined, {});
        }
        return controller;
    }
}
//# sourceMappingURL=log.js.map