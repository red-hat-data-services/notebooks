import { of } from './gen/rxjsStub.js';
export function setHeaderMiddleware(key, value) {
    return {
        pre: (request) => {
            request.setHeaderParam(key, value);
            return of(request);
        },
        post: (response) => {
            return of(response);
        },
    };
}
// Returns ConfigurationOptions that set a header
export function setHeaderOptions(key, value, opt) {
    const newMiddlware = setHeaderMiddleware(key, value);
    const existingMiddlware = (opt === null || opt === void 0 ? void 0 : opt.middleware) || [];
    return {
        ...opt,
        middleware: existingMiddlware.concat(newMiddlware),
        middlewareMergeStrategy: 'append', // preserve chained middleware from opt
    };
}
//# sourceMappingURL=middleware.js.map