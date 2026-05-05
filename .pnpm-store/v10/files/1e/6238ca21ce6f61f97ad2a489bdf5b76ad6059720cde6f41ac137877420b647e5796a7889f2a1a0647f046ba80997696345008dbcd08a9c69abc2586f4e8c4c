import { ResponseContext } from './http.js';
import { from } from '../rxjsStub.js';
import fetch from "node-fetch";
export class IsomorphicFetchHttpLibrary {
    send(request) {
        let method = request.getHttpMethod().toString();
        let body = request.getBody();
        const resultPromise = fetch(request.getUrl(), {
            method: method,
            body: body,
            headers: request.getHeaders(),
            signal: request.getSignal(),
            agent: request.getAgent(),
        }).then((resp) => {
            const headers = {};
            resp.headers.forEach((value, name) => {
                headers[name] = value;
            });
            const body = {
                text: () => resp.text(),
                binary: () => resp.buffer()
            };
            return new ResponseContext(resp.status, headers, body);
        });
        return from(resultPromise);
    }
}
//# sourceMappingURL=isomorphic-fetch.js.map